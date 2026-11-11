#Requires -Version 5.1
<#
.SYNOPSIS
    Exportiert die Hyper-V-Hosts aus SCVMM als CSV fuer das SPLA-Dashboard (license-reporter).

.DESCRIPTION
    Verbindet sich mit dem VMM-Server der gewaehlten Umgebung (PROD oder TEST), liest alle
    Hosts mit Get-SCVMHost aus und schreibt sie als
        VMMHostExport_<UMGEBUNG>_<JJJJMMTT>.csv
    in den Output-Ordner (normalerweise den Ordner "report" des Dashboards).

    Gedacht fuer den taeglichen, geplanten Lauf im ScriptRunner - pro Umgebung ein Job
    (bzw. eine Aktion mit VMM_Server = PROD und eine mit VMM_Server = TEST).

    Laeuft das Skript am selben Tag mehrfach, wird die Tagesdatei ueberschrieben
    (der letzte Lauf des Tages gilt). Die Datei wird zuerst unter einem temporaeren Namen
    geschrieben und erst danach umbenannt, damit das Dashboard nie eine halbe Datei einliest.

    Voraussetzung auf dem ScriptRunner-Host bzw. Target: VMM-Konsole mit dem PowerShell-Modul
    "VirtualMachineManager". Das Konto in VMM_Credential braucht in VMM mindestens Leserechte
    auf alle Hosts (z.B. Rolle "Read-Only Administrator") und Schreibrechte im Output-Ordner
    hat das Konto, unter dem ScriptRunner das Skript ausfuehrt.

.PARAMETER VMM_Server
    Umgebung: PROD oder TEST. Bestimmt den VMM-Server (siehe $VmmServers unten) und den
    Umgebungsnamen im Dateinamen.

.PARAMETER VMM_Credential
    Anmeldeinformationen fuer den VMM-Server (im ScriptRunner als Credential hinterlegen).

.PARAMETER OutputFolder
    Zielordner fuer die CSV-Dateien, z.B. \\fileserver\share\license-reporter\report

.NOTES
    Rueckgabe fuer ScriptRunner ueber $SRXEnv.ResultMessage; bei Fehlern endet das Skript mit
    einem terminierenden Fehler, damit der Job im ScriptRunner als fehlgeschlagen erscheint.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PROD', 'TEST')]
    [string]$VMM_Server,

    [Parameter(Mandatory = $true)]
    [pscredential]$VMM_Credential,

    [Parameter(Mandatory = $true)]
    [string]$OutputFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------------------
# Konfiguration: VMM-Server je Umgebung (FQDN anpassen!)
# ---------------------------------------------------------------------------------------
$VmmServers = @{
    PROD = 'vmm-prod.corp.example'
    TEST = 'vmm-test.corp.example'
}

function Write-SRResult {
    param([string]$Message)
    $sr = Get-Variable -Name SRXEnv -ValueOnly -ErrorAction SilentlyContinue
    if ($sr) { $sr.ResultMessage = $Message }
    Write-Output $Message
}

$serverName = $VmmServers[$VMM_Server]
$date       = Get-Date -Format 'yyyyMMdd'
$fileName   = "VMMHostExport_{0}_{1}.csv" -f $VMM_Server, $date
$targetPath = Join-Path -Path $OutputFolder -ChildPath $fileName
$tempPath   = "$targetPath.tmp"
$vmm        = $null

try {
    # --- Output-Ordner pruefen -----------------------------------------------------------
    if (-not (Test-Path -LiteralPath $OutputFolder -PathType Container)) {
        throw "Output-Ordner '$OutputFolder' existiert nicht oder ist nicht erreichbar."
    }

    # --- VMM verbinden -------------------------------------------------------------------
    Import-Module -Name VirtualMachineManager -ErrorAction Stop | Out-Null
    Write-Verbose "Verbinde mit VMM-Server '$serverName' ($VMM_Server) als $($VMM_Credential.UserName) ..."
    $vmm = Get-SCVMMServer -ComputerName $serverName -Credential $VMM_Credential

    # --- Hosts auslesen ------------------------------------------------------------------
    $hosts = @(Get-SCVMHost -VMMServer $vmm)
    if ($hosts.Count -eq 0) {
        throw "VMM-Server '$serverName' hat keine Hosts geliefert - Export abgebrochen (bestehende Dateien bleiben unveraendert)."
    }

    # Spalten exakt wie vom Dashboard erwartet (Namen/Reihenfolge nicht aendern).
    # Objekt-Eigenschaften (HostCluster, OperatingSystem, ComputerState) explizit als Text,
    # damit das CSV unabhaengig von der VMM-/PowerShell-Version gleich aussieht.
    $rows = @($hosts | Sort-Object -Property ComputerName | ForEach-Object {
        [pscustomobject][ordered]@{
            ComputerName          = [string]$_.ComputerName
            HostCluster           = if ($_.HostCluster) { [string]$_.HostCluster } else { '' }
            PhysicalCPUCount      = $_.PhysicalCPUCount
            CoresPerCPU           = $_.CoresPerCPU
            LogicalCPUCount       = $_.LogicalCPUCount
            ProcessorManufacturer = [string]$_.ProcessorManufacturer
            CPUSpeed              = $_.CPUSpeed
            OperatingSystem       = ([string]$_.OperatingSystem).Trim()
            Description           = [string]$_.Description
            ComputerState         = [string]$_.ComputerState
        }
    })

    # --- Schreiben (erst temp, dann umbenennen) -----------------------------------------
    $rows | Export-Csv -LiteralPath $tempPath -NoTypeInformation -Delimiter ',' -Encoding UTF8 -Force
    Move-Item -LiteralPath $tempPath -Destination $targetPath -Force

    # --- Zusammenfassung -----------------------------------------------------------------
    $notResponding = @($rows | Where-Object { $_.ComputerState -ne 'Responding' })
    $msg = "{0}: {1} Hosts von '{2}' exportiert nach '{3}'." -f $VMM_Server, $rows.Count, $serverName, $targetPath
    if ($notResponding.Count -gt 0) {
        $msg += " Achtung: {0} Host(s) nicht 'Responding': {1}" -f $notResponding.Count, (($notResponding | ForEach-Object { "$($_.ComputerName) ($($_.ComputerState))" }) -join ', ')
    }
    Write-SRResult $msg
}
catch {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
    $err = "{0}: VMM-Export fehlgeschlagen - {1}" -f $VMM_Server, $_.Exception.Message
    $sr = Get-Variable -Name SRXEnv -ValueOnly -ErrorAction SilentlyContinue
    if ($sr) { $sr.ResultMessage = $err }
    throw $err
}
finally {
    if ($vmm) { try { $vmm.Disconnect() } catch { } }
}
