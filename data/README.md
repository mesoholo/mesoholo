# Local data directory (repository-relative)

Place **example or small test datasets** here so scripts can use paths relative to the repository root instead of lab-specific drives.

Suggested layout:

- `data/fixtures/` — tiny files checked in for demos (e.g. optional gamma LUT `.mat`).
- `data/sessions/<mouse>/<date>/` — your own session data (typically **gitignored**; see `.gitignore`).

MATLAB helpers:

- `matlab/mesoholo_repo_root.m` — returns the absolute path to the repo root; combine with `fullfile` to build paths under `data/`.

Environment variables (when data must live outside the repo):

- `MESOHOLO_DATA_ROOT` — used by Python helpers (`_mesoholo_paths.py`); defaults to `<repo>/data`.
- `MESOHOLO_SHARED_ROOT` / `MESOHOLO_LOCAL_SAVE_ROOT` — see `MesoLocFile_SI.m` and `MesoLocFile_DAQ.m`.
- `MESOHOLO_SUITE2P_FAST_DISK` — optional fast disk for suite2p temp output when generating `ops.json` from MATLAB.
- `MESOHOLO_DAQ_MATLAB`, `MESOHOLO_EXAMPLE_TIF`, `MESOHOLO_GAMMA_LUT`, `MESOHOLO_CALIB_ACTIVE`, `MESOHOLO_SLM_LUT`, `MESOHOLO_PSTH_CACHE`, `MESOHOLO_CALIB_TEMP_SOURCE`, `MESOHOLO_SI_MATLAB`, `MESOHOLO_FIJI_TARGETS_CSV`, `MESOHOLO_TESTTARGETS_MAT`, `MESOHOLO_LIVEPOWER_CSV`, `MESOHOLO_CALIB_EXPORT`, `MESOHOLO_RMPATH_STALE`, `MESOHOLO_HOLOLISTS_PATH` — optional overrides for individual scripts (see `docs/DEPENDENCIES.md`).
