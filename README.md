# ResearchData Manager

> A lightweight, local-first Windows application for structured, traceable, and safer research data management.

ResearchData Manager helps individual researchers organize projects, create standardized experiment packages, import raw data with integrity verification, maintain independent backups, and track the status of each experiment. It is built with Windows PowerShell and WinForms and does not require R, Python, or a database.

**Current release:** v0.1.0 (early preview)  
**Platform:** Windows 10/11  
**Interface language:** Simplified Chinese

## Why this project exists

Experimental files are often scattered across instrument computers, USB drives, download folders, and manually created project directories. This makes it difficult to answer basic questions later:

- Which files are the original instrument outputs?
- Which analysis was generated from which experiment?
- Was a copied file transferred without corruption?
- Is there an independent backup?
- Is an experiment planned, in progress, analyzed, or archived?

ResearchData Manager turns each experiment into a standardized and traceable data package while leaving scientific decisions to the researcher.

## Design principles

1. **One experiment, one unique experiment ID.**
2. **One standardized folder structure for every experiment.**
3. **Raw data are copied, verified, and never overwritten by the application.**
4. **Important operations are recorded in human-readable CSV, JSON, and Markdown files.**
5. **A real backup must be stored on another drive or a NAS, not elsewhere on the working drive.**

## Features

### Project management

- Create a new project from a graphical interface.
- Generate a standard project directory automatically.
- Record project code, name, description, confidentiality level, status, and location.
- Maintain a global project register.

### Experiment creation

- Generate a unique experiment ID such as `IDH2-20260820-qPCR-01`.
- Create a complete experiment package with design, raw-data, processed-data, analysis, results, and notes folders.
- Generate experiment metadata, a README, a sample sheet, a processing log, and an exception log.
- Record assay type, objective, notebook location, groups, and replicate numbers.

### Raw-data import

- Import either a single file or an entire folder.
- Classify data as `L0_Native` or `L1_Export`.
- Calculate SHA-256 checksums before and after copying.
- Preserve the source directory structure.
- Store each import in a new timestamped directory.
- Generate a checksum manifest and an import summary.
- Optionally mark imported files as read-only.
- Optionally create and verify an independent backup.

### Validation and experiment status

- Check whether required experiment files and folders are present.
- Report recommended items such as processed data, analysis files, results, and backups.
- Track the experiment lifecycle using standardized statuses.
- Display project and experiment summaries on a dashboard.

## What the application does not do

ResearchData Manager manages files and provenance. It does not interpret scientific results or replace assay-specific analysis software. qPCR, CCK8, flow cytometry, microscopy, and sequencing data still require appropriate analysis tools.

It also does not delete, move, or modify the source files selected for import.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 with WinForms support
- Write access to the selected `ResearchData` directory
- Optional: another physical drive or a NAS for independent backups

No installation of R, Python, or third-party packages is required.

## Installation

1. Download the repository or the latest release.
2. Keep these files in the same directory:

   ```text
   ResearchDataManager.ps1
   Start-ResearchDataManager.cmd
   README.md
   ```

3. Double-click `Start-ResearchDataManager.cmd`.
4. At first launch, confirm or create the default working directory:

   ```text
   D:\ResearchData
   ```

5. Open **Settings** in the application to change the root directory, backup location, or operator name.

If Windows blocks the downloaded PowerShell script, open PowerShell in the application directory and run:

```powershell
Unblock-File .\ResearchDataManager.ps1
```

Then launch the application again. The included launcher starts the script with a process-scoped execution-policy bypass; it does not change the permanent execution policy of the computer.

## Quick start

### 1. Configure storage

Open the **Settings** tab and confirm:

- the main `ResearchData` directory;
- the operator name;
- an optional backup directory on another drive or a NAS.

The application can create or repair missing base directories without modifying existing content.

### 2. Create a project

Enter a stable project code, folder name, project name, description, and confidentiality level. For example:

```text
Project code: GeneX
Folder name: GeneX_Cancer
Project name: IDH2 in Cancer
```

The application creates the project structure and updates `Project_Register.csv`.

### 3. Create an experiment

Select a project and enter the assay date, assay type, objective, notebook location, experimental groups, and replicate numbers.

The application assigns the next available experiment ID and creates the full experiment package automatically.

### 4. Import raw data

Select an experiment, choose a source file or folder, and classify it as:

| Level | Meaning |
|---|---|
| `L0_Native` | Native files generated by the instrument or acquisition software |
| `L1_Export` | Direct exports such as CSV, Excel, text, TIFF, or other non-analyzed files |

The application calculates source hashes, copies the files, recalculates destination hashes, and records the result. It can also make the imported files read-only and create a separately verified backup.

### 5. Validate and update status

Run the experiment-package check, review missing or recommended items, and update the experiment status when appropriate.

| Status | Meaning |
|---|---|
| `PLANNED` | Experiment package created; work not yet started |
| `IN_PROGRESS` | Experimental work is ongoing |
| `RAW_COMPLETE` | Required raw data have been imported and confirmed |
| `PROCESSING` | Data cleaning or analysis is ongoing |
| `ANALYZED` | Analysis and core results are complete |
| `ARCHIVED` | Experiment package has been closed and archived |

`RAW_COMPLETE` is a researcher-confirmed status. A successful import proves that selected files were copied correctly; it cannot determine whether every scientifically required file was selected.

## Generated directory structure

The default root structure is:

```text
D:\ResearchData\
├── 00_Inbox\
├── 01_Projects\
├── 02_SharedResources\
├── 03_Templates\
├── 04_Automation\
├── 05_SystemRecords\
├── 90_Transfer\
└── 99_ArchiveIndex\
```

Each project contains:

```text
Project_Name\
├── 00_Project_Admin\
├── 01_Protocols\
├── 02_Experiments\
├── 03_Integrated_Analysis\
├── 04_Figures\
├── 05_Manuscript\
├── 06_Presentations\
└── 99_Archive\
```

Each experiment contains:

```text
PROJECT-YYYYMMDD-Assay-01\
├── 00_README.md
├── Experiment.json
├── 01_Design\
│   └── Sample_Sheet.csv
├── 02_RawData\
│   ├── L0_Native\
│   ├── L1_Export\
│   └── RawData_Import_Log.csv
├── 03_ProcessedData\
├── 04_Analysis\
│   └── Processing_Log.csv
├── 05_Results\
└── 99_Notes\
    └── Exception_Log.csv
```

## Data-integrity and safety behavior

- Source data are copied, never moved or deleted.
- Existing imports are not overwritten; each import receives a timestamped directory.
- SHA-256 hashes are calculated for both source and destination files.
- A failed verification stops the import and creates an `IMPORT_FAILED.json` record.
- Optional read-only attributes help protect imported raw data from accidental editing.
- Backup paths inside the working directory are rejected.
- Backup paths on the same local drive as the working directory are also rejected.
- Backup copies are verified against the original SHA-256 values.
- No network service, cloud account, or telemetry is used by v0.1.0.

> Read-only attributes and checksums reduce accidental damage but are not substitutes for access control, versioned backups, or an institutional data-management policy.

## Records and configuration

| File | Purpose |
|---|---|
| `05_SystemRecords\Project_Register.csv` | Global project register |
| `05_SystemRecords\Experiment_Master_Register.csv` | Global experiment register and lifecycle status |
| `04_Automation\Logs\ResearchDataManager_Log.csv` | Application operation log |
| `Experiment.json` | Machine-readable metadata for one experiment |
| `manifest_sha256.csv` | Per-file checksum manifest for one import |
| `Import_Summary.json` | Source, destination, operator, size, and verification summary |
| `RawData_Import_Log.csv` | Import history within an experiment package |

User-specific settings are stored locally at:

```text
%APPDATA%\ResearchDataManager\config.json
```

## Privacy

The current version operates entirely on the local computer and configured storage locations. It makes no network requests. File paths, operator names, experiment metadata, and operation records remain in local configuration or research directories.

Do not upload the generated `D:\ResearchData` directory, experimental data, local configuration, or operation logs to GitHub. The GitHub repository should contain only source code, documentation, examples without sensitive data, and release files.

## Current limitations

- v0.1.0 is an early personal-use preview and should be tested with non-critical sample files before routine use.
- The graphical interface is currently available only in Simplified Chinese.
- The application is Windows-only.
- File copying and hashing run synchronously; very large datasets may take a long time and keep the interface busy.
- The CSV registers are intended for one user and do not provide multi-user locking.
- The application manages generic data packages but does not perform assay-specific analysis.
- Large sequencing datasets and long-term restore procedures have not yet been extensively validated.

## Roadmap

- English/Chinese interface selection
- Background transfers with pause, resume, and cancellation
- Scheduled backup and checksum verification
- Search, filtering, and richer project dashboards
- Project archival and restore testing
- Source-data and figure-traceability workflows
- Automated tests, signed releases, and simplified installation

## Contributing

Bug reports and suggestions are welcome. When reporting a problem, please include:

- the ResearchData Manager version;
- the Windows and PowerShell versions;
- the operation being performed;
- the complete error message;
- a minimal reproducible example using non-sensitive test files.

Never include unpublished research data, participant information, credentials, or confidential file paths in a public issue.

## Author

Developed by **Xiao Liu**.

## Disclaimer

ResearchData Manager is provided as a research workflow aid. Users remain responsible for validating their data, maintaining appropriate backups, complying with institutional policies, and protecting confidential or regulated information.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
