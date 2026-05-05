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
