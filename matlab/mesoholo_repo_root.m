%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/mesoholo_repo_root.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function repoRoot = mesoholo_repo_root()
%mesoholo_repo_root  Absolute path to the mesoholo repository root directory.
%
% This file lives in `<repo>/matlab/`. The repository root is the parent of
% the `matlab` folder. Use this for paths to bundled assets under `data/`,
% `docs/`, etc., so scripts do not depend on machine-specific drive letters.
%
% Output
% - repoRoot: char, ends with filesep on all platforms.

persistent cached
if isempty(cached)
    here = fileparts(mfilename('fullpath')); % .../matlab
    cached = fileparts(here);               % .../repo root
end
repoRoot = cached;
if ~endsWith(repoRoot, filesep)
    repoRoot = [repoRoot filesep];
end
end
