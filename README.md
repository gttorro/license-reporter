# license-reporter

SPLA-Reporting-Dashboard für Hyper-V/VMM-Hosts (Windows Server, Core-Lizenzierung).

## Aufbau

```
index.html                             <- die Website (eine Datei, keine externen Abhängigkeiten)
scripts/
  Export-VMMHostInventory.ps1          <- täglicher VMM-Export (ScriptRunner)
report/
  VMMHostExport_PROD_JJJJMMTT.csv      <- pro Tag ein Export je Umgebung
  VMMHostExport_TEST_JJJJMMTT.csv         (hier: Dummy-Daten Sep–Nov 2026)
```

Die Umgebung wird aus dem Dateinamen gelesen (der Teil vor dem Datum). Weitere Umgebungen
werden automatisch erkannt.

Die täglichen CSV-Exporte landen automatisch im Unterordner `report/`
(anpassbar über `CSV_DIR` in `index.html`).

## Export aus VMM (ScriptRunner)

`scripts/Export-VMMHostInventory.ps1` schreibt die Tagesdatei `VMMHostExport_<PROD|TEST>_JJJJMMTT.csv`.
Parameter: `VMM_Server` (PROD/TEST), `VMM_Credential`, `OutputFolder` (= Ordner `report`).
Die FQDNs der VMM-Server stehen oben im Skript in `$VmmServers`. Im ScriptRunner zwei geplante
Aktionen anlegen (PROD und TEST), z.B. täglich 06:00. Läuft das Skript mehrmals am Tag, gilt der
letzte Lauf. Voraussetzung: VMM-Konsole (Modul `VirtualMachineManager`) auf dem Ausführungs-Host.

## Wie die Daten eingelesen werden

Beim Öffnen liest das Dashboard die CSVs automatisch ein, sofern möglich:

1. **Über einen Webserver**, der den Unterordner `report/` auflisten darf (IIS "Verzeichnis
   durchsuchen" nur für `report/`, Apache `Options +Indexes`, nginx `autoindex on`):
   vollautomatisch bei jedem Aufruf. In `report/` darf keine `index.html`/`default.htm` liegen.
2. **Per Doppelklick / von einer Netzwerkfreigabe** in Edge oder Chrome: beim ersten Mal
   "Ordner wählen" klicken und den Ordner `report` auswählen. Der Browser merkt sich den Ordner und liest ihn bei den
   nächsten Starts automatisch ein – oder fragt mit einem Klick erneut um Erlaubnis.
3. **Andere Browser** (z.B. Firefox): "Ordner wählen" bei jedem Besuch, oder CSVs per
   Drag & Drop auf die Seite ziehen.

"Neu einlesen" liest den Ordner jederzeit erneut ein, z.B. nachdem ein neuer Export dazugekommen ist.

## Berechnung

* Physische Cores = `PhysicalCPUCount × CoresPerCPU` (Hyperthreading zählt nicht)
* Mindestens 8 Cores pro CPU und 16 Cores pro Server, in 2-Core-Packs
* Monatswert pro Host = Peak aller Tages-Exporte im Monat; Summe über alle Hosts = SPLA Cores
* **Total = PROD + TEST**; Aufteilung nach Umgebung und Edition wird überall mit angezeigt
* Fehlende Tages-Exporte werden pro Umgebung angezeigt
* Getrennt nach Edition (Datacenter / Standard), Export des Monatsreports als CSV
