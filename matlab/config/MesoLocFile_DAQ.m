function locations = MesoLocFile_DAQ()
%MesoLocFile_DAQ  Centralized file/folder locations for DAQ-side code.
%
% See `MesoLocFile_SI` for shared configuration details. This function uses
% the same environment variables:
% - `MESOHOLO_SHARED_ROOT` (default: `S:\Mesoshare\holography`)
% - `MESOHOLO_LOCAL_SAVE_ROOT` (default: `C:\Data`)

sharedRoot = getenv("MESOHOLO_SHARED_ROOT");
if strlength(sharedRoot) == 0
    sharedRoot = "S:\Mesoshare\holography";
end
sharedRoot = char(sharedRoot);

localSaveRoot = getenv("MESOHOLO_LOCAL_SAVE_ROOT");
if strlength(localSaveRoot) == 0
    localSaveRoot = "C:\Data";
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
