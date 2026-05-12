## mesoholo

Code used for mesoscale holography experiments (Abdeladim et al., 2026).

This repository was assembled from multiple acquisition/control computers; the original code contained many machine-specific paths. The repo is now organized into:

- **`matlab/rig/`**: online acquisition & control code (ScanImage PC, DAQ PC, hologram/SLM PC, visual stimulus PC).
- **`matlab/analysis/`**: offline analysis utilities (retinotopy, ROI/mask utilities, etc.). The former `matlab/analysis/HS/` subtree was flattened into this folder.
- **`python/suite2p_pipeline/`**: Suite2p-related conversion/pipeline helpers (notebooks and scripts).
- **`matlab/config/`**: shared path configuration used by multiple scripts.
- **`dump/`**: local-only staging folder (ignored by git).

### Quick start (MATLAB)

1. Add this repo to your MATLAB path (or run from repo root after `cd`).
2. Run `mesoholo_setup()` once per session (from `matlab/mesoholo_setup.m`) to add `matlab/` subtrees and `python/suite2p_pipeline/` to your path.
3. Configure paths via environment variables (optional; **defaults are repository-local** under `data/` — see `data/README.md`):
   - **`MESOHOLO_SHARED_ROOT`**: shared holography folder (default: `<repo>/data/shared/holography`)
   - **`MESOHOLO_LOCAL_SAVE_ROOT`**: SI-side local save root (default: `<repo>/data/sessions/_si_local`)
   - **`MESOHOLO_CALIB_PATH`**: folder containing `ActiveCalib.mat` (variable `CoC`)
   - **`MESOHOLO_MSOCKET_PATH`** (optional): path to a MATLAB `msocket` implementation

The main location helpers are:
- `matlab/config/MesoLocFile_SI.m`
- `matlab/config/MesoLocFile_DAQ.m`

### Notes on hardware dependencies

Large parts of `matlab/rig/` expect specific hardware/software stacks (e.g. ScanImage, NI-DAQ, Meadowlark SLM SDK, Psychtoolbox, and an `msocket` MATLAB implementation). This repo aims to preserve the original logic while making paths/config explicit; you may still need to install vendor SDKs and add third-party code to your MATLAB path.

### Contributors (historical + recent)

This codebase evolved over many years across multiple computers and users. Recent substantial edits for the 2020s-era mesoscope holography pipeline include contributions from:

- Uday Jagadisan (`kj.udayakiran@gmail.com`)
- Lamiae Abdeladim (`lamiae.abdeladim@gmail.com`)
- Hyeyoung Shin (`shinehyeyoung@gmail.com`)

For more detail, see `docs/CONTRIBUTORS.md`.

### Contributing / cleaning

If you add new scripts, please put them into `dump/` first; they will be reorganized into the appropriate module directory and cleaned/documented before being published.

