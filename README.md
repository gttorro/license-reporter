# license-reporter

SPLA-Reporting-Dashboard für Hyper-V/VMM-Hosts (Windows Server, Core-Lizenzierung).

## Aufbau

```
report/
  dashboard.html                       <- die Website (eine Datei, keine externen Abhängigkeiten)
  Export-SplaData.ps1                  <- täglicher Export: schreibt CSV + data.js
  data.js                              <- alle CSVs gebündelt (wird vom Skript erzeugt)
  VMMHostExport_<NAME>_JJJJMMTT.csv    <- ein Export pro Tag (hier: Dummy-Daten Sep–Nov 2026)
```

## Betrieb

1. Ordner `report/` auf den VMM-Server oder eine Freigabe kopieren.
2. `Export-SplaData.ps1` als geplante Aufgabe täglich ausführen:
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\report\Export-SplaData.ps1" -VMMServer vmm01
   ```
   Das Skript exportiert die Hosts nach `VMMHostExport_PROD_JJJJMMTT.csv` und baut danach `data.js` neu.
3. `dashboard.html` öffnen – per Doppelklick, von der Netzwerkfreigabe oder über einen beliebigen Webserver.
   Es ist **keine Webserver-Konfiguration** nötig.

Weitere Optionen: `-SkipExport` (nur `data.js` aus vorhandenen CSVs neu bauen), `-Prefix`, `-KeepDays`.

Zusätzliche Wege, Daten zu laden (optional):
* Liegt die Seite auf einem Webserver mit aktivem Directory-Listing (IIS "Verzeichnis durchsuchen",
  Apache `Options +Indexes`, nginx `autoindex on`), werden CSVs auch ohne `data.js` gefunden.
* CSV-Dateien per Drag & Drop oder "CSV laden" ins Dashboard ziehen.

## Berechnung

* Physische Cores = `PhysicalCPUCount × CoresPerCPU` (Hyperthreading zählt nicht)
* Mindestens 8 Cores pro CPU und 16 Cores pro Server, in 2-Core-Packs
* Monatswert pro Host = Peak aller Tages-Exporte im Monat; Summe über alle Hosts = SPLA Cores
* Getrennt nach Edition (Datacenter / Standard), Export des Monatsreports als CSV
