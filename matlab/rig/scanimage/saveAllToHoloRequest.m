function [holoRequest] = saveAllToHoloRequest(xynew, yoffset, xoffset , xrotate, yrotate, zMap, hSI,zplane);
%% Write Custom HoloRequest

%AUTO UPDATE THIS F

loc = MesoLocFile_SI();
holoRequest.objective = 20;
holoRequest.zoom = hSI.hRoiManager.scanZoomFactor;
zoomscalef = 1/holoRequest.zoom;

holoRequest.xoffset = xoffset;
holoRequest.yoffset = yoffset;
holoRequest.hologram_config= 'DLS';
holoRequest.ignoreROIdata = 1;
sipix = 512;
    lx=680;
    ly=680;
    if(~isnan(xoffset))
        MODxoffset = holoRequest.xoffset*zoomscalef;%*sipix/lx;
    end
    if(~isnan(yoffset))
        MODyoffset = holoRequest.yoffset*zoomscalef;%*sipix/ly;
    end
    
rois = evalin('base','hSI.hIntegrationRoiManager.roiGroup.rois');
centerXY = zeros(length(rois),2);
centerXY = fliplr(xynew);
for idx = 1:length(rois)
%     centerXY(idx,1:2) = fliplr(rois(idx).scanfields.centerXY)*zoomscalef;
    centerZ(idx,1) = rois(idx).zs;
end
[length(rois),size(xynew),size(centerZ),size(centerXY)]
centerZ(sum(centerXY,2)==2,:) = [];
centerXY(sum(centerXY,2)==2,:) = [];

%Hacky Z Correction added by Ian 9/30/19
if isempty(zMap) || numel(zMap)==1 || all(zMap(:)~=0)
    %don't change z Mapping
    holoRequest.zRemapping=0;
    centerZc = centerZ;
    MODxoffset = 0;
    MODyoffset = 0;
else
    if(isnan(xoffset))
        f = fit(zMap(1,:)',xrotate'*zoomscalef,'cubicinterp');
        MODxoffset = f(centerZ);%*sipix/lx;
        holoRequest.xoffRemapping = f;
    end
    if(isnan(yoffset))
        f = fit(zMap(1,:)',yrotate'*zoomscalef,'cubicinterp');
        MODyoffset = f(centerZ);%*sipix/ly;
        holoRequest.yoffRemapping = f;
    end
    %remap Z
    f = fit(zMap(1,:)',zMap(2,:)','cubicinterp');
    centerZc=f(centerZ);
    holoRequest.zRemapping = f;
end
    

% pixelToRefTransform = evalin('base','hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1).pixelToRefTransform');
% centerXY =
% scanimage.mroi.util.xformPoints(centerXY,inv(pixelToRefTransform));
holoRequest.targets=[centerXY centerZc];
holoRequest.actualtargets = [centerXY centerZ];

holoRequest.xoffset=MODxoffset;
holoRequest.yoffset=MODyoffset;
try
    save([loc.HoloRequest_SI 'holoRequest.mat'],'holoRequest');
    save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');
catch
    disp('****WARNING: HOLOREQUEST SAVE ERROR!!! Find another way...****')
end