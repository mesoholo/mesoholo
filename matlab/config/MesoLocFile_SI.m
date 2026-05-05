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
%   directory (e.g. `S:\Mesoshare\holography` on the rig network).
% - Set environment variable `MESOHOLO_LOCAL_SAVE_ROOT` to a local data root
%   (e.g. `D:\Data`).
%
% Notes:
% - This is the ScanImage-side locations file. See `MesoLocFile_DAQ` for the
%   DAQ computer defaults.

sharedRoot = getenv("MESOHOLO_SHARED_ROOT");
if strlength(sharedRoot) == 0
    % Default matches the original rig mapping; override via env var.
    sharedRoot = "S:\Mesoshare\holography";
end
sharedRoot = char(sharedRoot);

localSaveRoot = getenv("MESOHOLO_LOCAL_SAVE_ROOT");
if strlength(localSaveRoot) == 0
    localSaveRoot = "D:\Data";
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