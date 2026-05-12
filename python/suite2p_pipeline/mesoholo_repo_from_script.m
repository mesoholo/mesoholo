%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: python/suite2p_pipeline/mesoholo_repo_from_script.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function repoRoot = mesoholo_repo_from_script()
%mesoholo_repo_from_script  Repository root when called from python/suite2p_pipeline/*.m
%
% This file lives in ``<repo>/python/suite2p_pipeline/``. Three ``fileparts``
% calls ascend to the repository root so paths can be built with ``fullfile``
% under ``data/`` without hardcoded drive letters.

here = fileparts(mfilename('fullpath'));           % .../suite2p_pipeline
pyDir = fileparts(here);                           % .../python
repoRoot = fileparts(pyDir);                       % .../mesoholo (repo root)
if ~endsWith(repoRoot, filesep)
    repoRoot = [repoRoot filesep];
end
end
