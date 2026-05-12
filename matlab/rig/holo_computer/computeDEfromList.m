%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/holo_computer/computeDEfromList.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [AttenuationCoeffs, DElist] = computeDEfromList(SICoordinates,ROIs,weights)

% Load calibration `CoC`: `MESOHOLO_CALIB_ACTIVE` or `data/calib/ActiveCalib.mat` under the repo.
calPath = getenv('MESOHOLO_CALIB_ACTIVE');
if isempty(calPath)
    calPath = fullfile(mesoholo_repo_root(), 'data', 'calib', 'ActiveCalib.mat');
end
load(calPath, 'CoC');

%catch targets that are below minimal diffraction efficiency 
DEfloor = 0.05;

[SLMCoordinates] = function_SItoSLM(SICoordinates',CoC)';
AttenuationCoeffs =SLMCoordinates(4,:);
lowDE = AttenuationCoeffs<DEfloor;
AttenuationCoeffs(lowDE)=DEfloor;
disp([num2str(sum(lowDE)) ' Target(s) below Diffraction Efficiency floor (' num2str(DEfloor) ').']);

%

if size(weights,1)~=1
    weights=weights';
end
numel(ROIs)
for i=1:numel(ROIs)
    ROIselection =ROIs{i};
    myattenuation = AttenuationCoeffs(ROIselection);
    energy = 1./myattenuation;
    energy = energy.*weights(ROIselection);
    energy = energy/sum(energy);
    DElist(i) = sum(energy.*myattenuation);
end