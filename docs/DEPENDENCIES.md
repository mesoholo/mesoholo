## Dependencies / environment

This repository contains a mix of:

- **online rig control** scripts (`matlab/rig/*`) that depend on hardware and vendor SDKs
- **offline analysis** scripts (`matlab/analysis/*`) that can often run on a workstation

### MATLAB

- MATLAB (many scripts were developed around R2021b–R2024a era)
- **ScanImage** (for `hSI`, ROI manager objects, and ScanImage TIFF conventions)
- **Data Acquisition Toolbox** + NI-DAQ drivers (DAQ-side scripts)
- **Psychtoolbox** (visual stimulus scripts in `matlab/rig/visual_stim/`)

### Hologram / SLM computer

The hologram computer scripts (`matlab/rig/holo_computer/`) assume:

- A compatible GPU + Parallel Computing Toolbox (optional but used in places)
- Meadowlark / SLM vendor SDK and MATLAB bindings (not included here)
- A calibration file `ActiveCalib.mat` containing variable `CoC`
  - point `MESOHOLO_CALIB_PATH` to the folder containing that file

### mSocket (network communication)

Several online scripts exchange data via a MATLAB `msocket` implementation:

- Functions referenced include `mslisten`, `msaccept`, `msconnect`, `msrecv`, `mssend`, and `flushMSocket`.
- This repo does **not** vendor an `msocket` library. If you have one locally, set:
  - `MESOHOLO_MSOCKET_PATH` to the folder containing the `msocket` MATLAB code.

