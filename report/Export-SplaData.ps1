<#
.SYNOPSIS
  Taeglicher SPLA-Export: schreibt die VMM-Host-Daten als CSV und baut data.js neu.

.DESCRIPTION
  1. Exportiert alle VMM-Hosts nach <Ordner>\<Prefix>_JJJJMMTT.csv (ueberspringen mit -SkipExport).
  2. Packt alle CSV-Dateien im Ordner in data.js. Damit funktioniert dashboard.html ohne
     Webserver-Konfiguration – auch per Doppelklick oder von einer Netzwerkfreigabe.

  Als geplante Aufgabe, z.B. taeglich 06:00 auf dem VMM-Server:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\report\Export-SplaData.ps1"

.EXAMPLE
  .\Export-SplaData.ps1 -VMMServer vmm01 -Prefix VMMHostExport_PROD
.EXAMPLE
  .\Export-SplaData.ps1 -SkipExport      # nur data.js aus vorhandenen CSVs neu erzeugen
#>
param(
  [string]$Folder    = $PSScriptRoot,
  [string]$Prefix    = "VMMHostExport_PROD",
  [string]$VMMServer = "localhost",
  [int]$KeepDays     = 0,          # >0: aeltere CSVs loeschen (z.B. 800 fuer gut 2 Jahre)
  [switch]$SkipExport
)
$ErrorActionPreference = "Stop"

if (-not $SkipExport) {
  Import-Module VirtualMachineManager
  $null = Get-SCVMMServer -ComputerName $VMMServer
  $file = Join-Path $Folder ("{0}_{1:yyyyMMdd}.csv" -f $Prefix, (Get-Date))
  Get-SCVMHost |
    Select-Object ComputerName, HostCluster, PhysicalCPUCount, CoresPerCPU, LogicalCPUCount,
                  ProcessorManufacturer, CPUSpeed, OperatingSystem, Description, ComputerState |
    Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
  Write-Host "CSV geschrieben: $file"
}

if ($KeepDays -gt 0) {
  Get-ChildItem $Folder -Filter *.csv |
    Where-Object LastWriteTime -lt (Get-Date).AddDays(-$KeepDays) |
    Remove-Item -Verbose
}

# data.js = { "datei.csv": "<inhalt>", ... }
$entries = Get-ChildItem $Folder -Filter *.csv | Sort-Object Name | ForEach-Object {
  $text = [IO.File]::ReadAllText($_.FullName)
  "  {0}: {1}" -f (ConvertTo-Json $_.Name -Compress), (ConvertTo-Json $text -Compress)
}
$js  = "// Automatisch erzeugt von Export-SplaData.ps1 – nicht von Hand bearbeiten`r`n"
$js += "window.SPLA_DATA = {`r`n" + ($entries -join ",`r`n") + "`r`n};`r`n"

$target = Join-Path $Folder "data.js"
$tmp    = "$target.tmp"
[IO.File]::WriteAllText($tmp, $js, (New-Object Text.UTF8Encoding $false))
Move-Item $tmp $target -Force      # atomar ersetzen, damit nie eine halbe Datei ausgeliefert wird
Write-Host ("data.js aktualisiert: {0} CSV-Dateien" -f @($entries).Count)
