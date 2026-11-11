<div align="center">

# 📊 license-reporter

**SPLA reporting dashboard for Hyper-V / VMM hosts**

*Windows Server · per-core licensing · single HTML file · zero dependencies*

</div>

---

## ✨ Features

- 🧮 **Automatic core calculation** following SPLA per-core licensing rules
- 📅 **Monthly peak values** per host, aggregated from daily exports
- 🌍 **Multiple environments** (PROD, TEST, …) detected automatically from file names
- 🏷️ **Split by edition**: Datacenter / Standard
- ⚠️ **Gap detection**: missing daily exports are flagged per environment
- 💾 **CSV export** of the monthly report
- 📦 **No installation**: one `index.html`, no external libraries, no backend

---

## 📁 Project structure

```text
license-reporter/
├── index.html                           # the dashboard (single file, no external dependencies)
└── report/
    ├── VMMHostExport_PROD_YYYYMMDD.csv  # one export per day and environment
    └── VMMHostExport_TEST_YYYYMMDD.csv  # (included: dummy data Sep–Nov 2026)
```

> [!NOTE]
> The environment name is taken from the file name (the part before the date).
> Additional environments, e.g. `VMMHostExport_DEV_20261101.csv`, are picked up automatically.

The daily CSV exports are dropped into the `report/` subfolder. The folder can be changed via
the `CSV_DIR` constant in `index.html`.

### CSV format

```csv
"ComputerName","HostCluster","PhysicalCPUCount","CoresPerCPU","LogicalCPUCount","ProcessorManufacturer","CPUSpeed","OperatingSystem","Description","ComputerState"
"HV-A01","CL-PROD01.corp.example","2","32","128","Intel","2800","Microsoft Windows Server 2022 Datacenter ","DemoBlade G11","Responding"
```

---

## 🚀 Loading the data

On startup the dashboard tries to read the CSV files automatically:

| # | Scenario | How it works |
|---|----------|--------------|
| 1 | **Via a web server** | Fully automatic on every visit. The server must allow directory listing for `report/` only (IIS *Directory Browsing*, Apache `Options +Indexes`, nginx `autoindex on`). There must be no `index.html` / `default.htm` inside `report/`. |
| 2 | **Opened locally / from a network share** in Edge or Chrome | The first time, click **Choose folder** and select the `report` folder. The browser remembers it and loads it automatically on later visits, or asks for permission again with a single click. |
| 3 | **Other browsers** (e.g. Firefox) | Click **Choose folder** on every visit, or drag & drop the CSV files onto the page. |

🔄 **Reload** re-reads the folder at any time, e.g. after a new export has arrived.

---

## 🧮 Calculation rules

| Rule | Details |
|------|---------|
| **Physical cores** | `PhysicalCPUCount × CoresPerCPU` (hyper-threading is **not** counted) |
| **Minimums** | at least **8 cores per CPU** and **16 cores per server**, licensed in **2-core packs** |
| **Monthly value per host** | **peak** across all daily exports in that month |
| **SPLA cores** | sum of the monthly values over all hosts |
| **Total** | **PROD + TEST**, with the breakdown by environment and edition shown throughout |

**Example:** a host with 2 CPUs × 6 cores = 12 physical cores
→ raised to 8 cores per CPU = 16 → **16 SPLA cores**.

---

<div align="center">
<sub>Made for SPLA monthly reporting of Hyper-V / SCVMM environments.</sub>
</div>
