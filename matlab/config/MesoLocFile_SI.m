%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/config/MesoLocFile_SI.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function locations = MesoLocFile_SI()
%MesoLocFile_SI  Centralized file/folder locations for ScanImage-side code.
%
% This repository was assembled from multiple acquisition/control computers.
% Many original scripts referenced machine-specific paths (e.g. `C:\Users\...`
% or mapped network drives). This function provides a single place to define
% those paths in a portable way for your installation.
%
% Configuration:
% - Set environment variable `MESOHOLO_SHARED_ROOT` to your shared holography
%   directory on the rig network (optional; defaults to `data/shared/holography` under this repo).
% - Set environment variable `MESOHOLO_LOCAL_SAVE_ROOT` for SI-side local saves
%   (optional; defaults to `data/sessions/_si_local` under this repo).
%
% Notes:
% - This is the ScanImage-side locations file. See `MesoLocFile_DAQ` for the
%   DAQ computer defaults.

cfgDir = fileparts(mfilename("fullpath"));   % .../matlab/config
matlabDir = fileparts(cfgDir);               % .../matlab
repoRoot = fileparts(matlabDir);             % repository root

sharedRoot = getenv("MESOHOLO_SHARED_ROOT");
if strlength(sharedRoot) == 0
    % Repository-local default (create `data/shared/holography/...` or set env var).
    sharedRoot = string(fullfile(repoRoot, "data", "shared", "holography"));
end
sharedRoot = char(sharedRoot);

localSaveRoot = getenv("MESOHOLO_LOCAL_SAVE_ROOT");
if strlength(localSaveRoot) == 0
    localSaveRoot = string(fullfile(repoRoot, "data", "sessions", "_si_local"));
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