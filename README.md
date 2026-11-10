# license-reporter

SPLA-Reporting-Dashboard für Hyper-V/VMM-Hosts (Windows Server, Core-Lizenzierung).

## Aufbau

```
report/
  dashboard.html                       <- die ganze Website (eine Datei, keine externen Abhängigkeiten)
  VMMHostExport_<NAME>_JJJJMMTT.csv    <- ein Export pro Tag (hier: Dummy-Daten Sep–Nov 2026)
```

Die Seite listet alle `*.csv` im eigenen Ordner über das Directory-Listing des
Webservers auf, liest sie ein und berechnet pro Monat die lizenzpflichtigen Cores.

## Betrieb

* Ordner `report/` per Webserver ausliefern und **Directory-Listing aktivieren**
  * IIS: Feature "Verzeichnis durchsuchen" aktivieren (`<directoryBrowse enabled="true" />`)
  * Apache: `Options +Indexes`, nginx: `autoindex on;`
  * Test lokal: `cd report && python3 -m http.server` → http://localhost:8000/dashboard.html
* Die Seite **nicht** in `index.html`/`default.htm` umbenennen – sonst liefert der
  Server die Seite statt der Dateiliste aus.
* Ohne Webserver (file://) können CSVs per Drag & Drop oder "CSV wählen…" geladen werden.

Täglicher Export, z.B. per geplanter Task auf dem VMM-Server:

```powershell
Get-SCVMHost | Select-Object ComputerName,HostCluster,PhysicalCPUCount,CoresPerCPU,LogicalCPUCount,
  ProcessorManufacturer,CPUSpeed,OperatingSystem,Description,ComputerState |
  Export-Csv "\\webserver\report\VMMHostExport_PROD_$(Get-Date -f yyyyMMdd).csv" -NoTypeInformation
```

## Berechnung

* Physische Cores = `PhysicalCPUCount × CoresPerCPU` (Hyperthreading zählt nicht)
* Mindestens 8 Cores pro CPU und 16 Cores pro Server, in 2-Core-Packs
* Monatswert pro Host = Peak aller Tages-Exporte im Monat; Summe über alle Hosts = SPLA Cores
* Getrennt nach Edition (Datacenter / Standard), Export des Monatsreports als CSV
