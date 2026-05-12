%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/mesoholo_setup.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function repoRoot = mesoholo_setup(varargin)
%mesoholo_setup  Add this repository to the MATLAB path.
%
% repoRoot = mesoholo_setup() adds `matlab/` subfolders (including config,
% rig, analysis) to the MATLAB path and returns the repository root folder.
%
% This is intended to replace machine-specific `addpath(genpath('C:\...'))`
% lines in the original acquisition/control scripts.
%
% Optional name-value pairs:
% - 'AddThirdParty' (default: true): add `matlab/third_party` recursively.

p = inputParser;
p.addParameter('AddThirdParty', true, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
opts = p.Results;

thisFile = mfilename('fullpath');
matlabRoot = fileparts(thisFile);       % .../<repo>/matlab
repoRoot = fileparts(matlabRoot);       % .../<repo>

addpath(matlabRoot);
addpath(genpath(fullfile(matlabRoot, 'config')));
addpath(genpath(fullfile(matlabRoot, 'rig')));
addpath(genpath(fullfile(matlabRoot, 'analysis')));

s2pMat = fullfile(repoRoot, 'python', 'suite2p_pipeline');
if exist(s2pMat, 'dir')
    addpath(s2pMat);
end

if opts.AddThirdParty
    thirdParty = fullfile(matlabRoot, 'third_party');
    if exist(thirdParty, 'dir')
        addpath(genpath(thirdParty));
    end
end

end

