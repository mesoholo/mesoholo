%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/analysis/test_targetmesoSICoordinates.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

if clearprev
    hSI.hIntegrationRoiManager.roiGroup.clear()
end

%% Create Array of Targets
% xy = xy_mori.holoRequest.targets(:,1:2);% fliplr();

% %xy=fliplr(xy)
% zs = xy_mori.holoRequest.targets(:,3);
% %if isempty(realZsTargets)
% 
% %realZsTargets = [-9,14,35,67]%sort(unique(zs));
% %end
% 
% disp(realZsTargets)
% %TODO make this into a function of the current planes using hSI object
% OptoTuneDepthsToProbe = hSI.hStackManager.zs;
% for i = 1:size(realZsTargets,2)
%     zs(zs==realZsTargets(i)) =OptoTuneDepthsToProbe(i);
% end

addpath(fileparts(fileparts(mfilename('fullpath')))); % .../matlab
ttPath = getenv('MESOHOLO_TESTTARGETS_MAT');
if isempty(ttPath)
    ttPath = fullfile(mesoholo_repo_root(), 'data', 'sessions', 'HS_CamKIIGC6s_59', '210617', 'Online', 'testtargets.mat');
end
load(ttPath)

%% send targets to ScanImage
tic
% xy: first column determines vertical position from top, second column
% determines horizontal position from left
% xy = [1000 500]; 

radius = 10;
iplane = 3;
Nplanes = numel(hSI.hRoiManager.currentRoiGroup.rois);
for iplane = 1:Nplanes
xy = targetcoords(:,1:2);
xy = xy(targetcoords(:,3)==iplane, :);

imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(iplane).scanfields(1);
Nmaskrows = imagingScanfield.pixelResolutionXY(2);
Nmaskcols = imagingScanfield.pixelResolutionXY(1);
sources = zeros(Nmaskrows,Nmaskcols,size(xy,1));
SE=strel('disk',radius,4);

for n = 1:size(sources,3);
    sources(round(xy(n,1)),round(xy(n,2)),n)=1;
    sources(:,:,n)=imdilate(sources(:,:,n),SE);
end

figure(51);imshow(max(sources,[],3))

% hSI.hRoiManager.currentRoiGroup
%   RoiGroup with properties:
%            rois: [1�5 scanimage.mroi.Roi]
%      activeRois: [1�5 scanimage.mroi.Roi]
%     displayRois: [1�5 scanimage.mroi.Roi]
%              zs: 40
%            name: 'MROI Imaging ROI Group'
number = 0;
%    for o = 1:size(OptoTuneDepthsToProbe)
%
for i = 1:size(sources,3)
    mask = sources(:,:,i);
    intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
    intsf.threshold = 100;
    introi = scanimage.mroi.Roi();
    introi.discretePlaneMode=1;
%     introi.add(double(zs(i)), intsf);
    introi.add(0, intsf); % add ROI at depth 0
    introi.name = ['ROI ' num2str(number+1) ' Plane ' num2str(iplane)];
    hSI.hIntegrationRoiManager.roiGroup.add(introi);
    number=number+1;
end

% rois = evalin('base','hSI.hIntegrationRoiManager.roiGroup.rois');
% pixelToRefTransform = evalin('base','hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1).pixelToRefTransform');
% %selectAllROIs;
% hSI.hIntegrationRoiManager.hIntegrationRoiOutputChannels(1).hIntegrationRois = hSI.hIntegrationRoiManager.roiGroup.rois;
end
toc
disp('rois updated')
