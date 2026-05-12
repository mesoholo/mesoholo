%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/config/MesoLocFile_DAQ.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function locations = MesoLocFile_DAQ()
%MesoLocFile_DAQ  Centralized file/folder locations for DAQ-side code.
%
% See `MesoLocFile_SI` for shared configuration details. This function uses
% the same environment variables (optional; defaults are under `data/` in this repo):
% - `MESOHOLO_SHARED_ROOT`
% - `MESOHOLO_LOCAL_SAVE_ROOT` (DAQ default folder: `data/sessions/_daq_local`)

sharedRoot = getenv("MESOHOLO_SHARED_ROOT");
if strlength(sharedRoot) == 0
    cfgDir = fileparts(mfilename("fullpath"));
    matlabDir = fileparts(cfgDir);
    repoRoot = fileparts(matlabDir);
    sharedRoot = string(fullfile(repoRoot, "data", "shared", "holography"));
end
sharedRoot = char(sharedRoot);

localSaveRoot = getenv("MESOHOLO_LOCAL_SAVE_ROOT");
if strlength(localSaveRoot) == 0
    cfgDir = fileparts(mfilename("fullpath"));
    matlabDir = fileparts(cfgDir);
    repoRoot = fileparts(matlabDir);
    localSaveRoot = string(fullfile(repoRoot, "data", "sessions", "_daq_local"));
end
localSaveRoot = char(localSaveRoot);

% Holorequests
locations.HoloRequest_SI = fullfile(sharedRoot, "Holorequests", "HoloRequest_SI", filesep);
locations.HoloRequest_DAQ = fullfile(sharedRoot, "Holorequests", "HoloRequest_DAQ", filesep);
locations.HoloRequest_DAQ_Galvos = fullfile(sharedRoot, "Holorequests", "HoloRequest_DAQ", "HoleburnCalibOffsets_Galvos", filesep);

% Laser power calibration (prefer shared, allow local override)
locations.PowerCalib = fullfile(sharedRoot, "LaserPowerCalib", "LaserPower.mat");
locations.localPowerCalib = fullfile(localSaveRoot, "LaserPowerCalib", "LaserPower.mat");

% Data save
locations.localSavePath = [localSaveRoot filesep];

% Spatial calibration
locations.SpatialCalib = fullfile(sharedRoot, "SpatialCalib", filesep);
