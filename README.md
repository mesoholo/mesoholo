## mesoholo

Code used for mesoscale holography experiments (Abdeladim et al., 2026).

This repository was assembled from multiple acquisition/control computers; the original code contained many machine-specific paths. The repo is now organized into:

- **`matlab/rig/`**: online acquisition & control code (ScanImage PC, DAQ PC, hologram/SLM PC, visual stimulus PC).
- **`matlab/analysis/`**: offline analysis utilities (retinotopy, ROI/mask utilities, etc.).
- **`python/suite2p_pipeline/`**: Suite2p-related conversion/pipeline helpers (notebooks and scripts).
- **`matlab/config/`**: shared path configuration used by multiple scripts.
- **`dump/`**: local-only staging folder (ignored by git).

### Quick start (MATLAB)

1. Add this repo to your MATLAB path (or run from repo root after `cd`).
2. Configure shared/local paths via environment variables:
   - **`MESOHOLO_SHARED_ROOT`**: shared holography folder (default: `S:\Mesoshare\holography`)
   - **`MESOHOLO_LOCAL_SAVE_ROOT`**: local save root (default: `D:\Data` on SI side, `C:\Data` on DAQ side)
   - **`MESOHOLO_CALIB_PATH`**: folder containing `ActiveCalib.mat` (variable `CoC`)
   - **`MESOHOLO_MSOCKET_PATH`** (optional): path to a MATLAB `msocket` implementation

The main location helpers are:
- `matlab/config/MesoLocFile_SI.m`
- `matlab/config/MesoLocFile_DAQ.m`

### Notes on hardware dependencies

Large parts of `matlab/rig/` expect specific hardware/software stacks (e.g. ScanImage, NI-DAQ, Meadowlark SLM SDK, Psychtoolbox, and an `msocket` MATLAB implementation). This repo aims to preserve the original logic while making paths/config explicit; you may still need to install vendor SDKs and add third-party code to your MATLAB path.

### Contributing / cleaning

If you add new scripts, please put them into `dump/` first; they will be reorganized into the appropriate module directory and cleaned/documented before being published.

