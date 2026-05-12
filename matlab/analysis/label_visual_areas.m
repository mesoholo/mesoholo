%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/analysis/label_visual_areas.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

% sinvf is calculated in analyze_visfieldsign
% isequal(size(ROIcorrImage), size(sinvf))

f=figure;
imagesc(sinvf)
colormap jet
set(f,'WindowStyle','docked')
title(mousedate, 'interpreter', 'none')
% v1 = drawfreehand

% this is an interactive part. draw borders for each visual area, one at a time
V1border = drawassisted
V1 = createMask(V1border);

LMborder = drawassisted
LM = createMask(LMborder);

ALborder = drawassisted
AL = createMask(ALborder);

RLborder = drawassisted
RL = createMask(RLborder);

AMborder = drawassisted
AM = createMask(AMborder);

PMborder = drawassisted
PM = createMask(PMborder);

save(strcat(datapath, 'maskVisualAreas.mat'), 'sinvf', ...
    'V1border', 'LMborder', 'RLborder', 'ALborder', 'PMborder', 'AMborder', ...
    'V1', 'LM', 'RL', 'AL', 'PM', 'AM')
