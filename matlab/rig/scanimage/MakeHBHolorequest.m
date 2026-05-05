function [ holoRequest ] = MakeHBHolorequest(row,col,xoffset,yoffset,a,tilteagle,power,ao0,ao1,hSI)
%UNTITLED4 Summary of this function goes here
%   Initial 00 calibrated FOV coordinates hardcoded


%%
sipix = 512;
radius = 5;

xy = [  50 200;...
    80, 200;...
    110, 200;...
    140, 200;...
    170, 200;...
    200, 200;...
    230, 200;...
    260, 200;...
    290, 200;...
    320, 200;...
    350, 200;...
    200, 230;...
    200, 260;...
    200, 290;...
    170, 320;...
    230, 320];
xy = xy+repmat([56,56],[16,1]);
xy = xy*sipix/512;
%     z = [-5 -4 -3 -2 -1 0 1 2 3 4 5 0 0 0 0 0];

for i=1:5
    %    6+i:11
    xy = cat(1,xy, bsxfun(@minus,xy(1:(5-i),:), [0 25*i*sipix/512 ]));
    xy = cat(1,xy, bsxfun(@plus,xy(7+i:11,:), [0 25*i*sipix/512 ]));
end
[xyorig,xynew,xyum,nstrips,z,sources] = makeHBeagle(xy,tilteagle,hSI);
   %% send targets to ScanImage
   
   % WHAT PLANE ARE YOU LOOKING AT (1, 2 ,3, 4, 5, 6, or 7)????
   OPTOTUNE_PLANE = 3; %moving eagle center at that plane
   
   
   o = OPTOTUNE_PLANE;
   hSI.hIntegrationRoiManager.roiGroup.clear()
   imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);
   
   OptoTuneDepthsToProbe = [-250 -100 0 100 250];

   correctZ = 1; %Hacky correct Z cerrors added 9/30/19 by Ian
   
   if correctZ
       zMap=[ [-250 -100 0 100 250];... %aka Zs % only planes 5,6,7 have sense, the rest is there so the vector would fit
           [-250 -100 0 100 250] + a]; % [-96 -64 -32 0 32 64 96] optotune units
       % --correction if right wing is brighter and ++ if left is brighter
%        temp1 = [-fliplr(zMap(1,2:end)),zMap(1,:)];
%        temp2 = [-fliplr(zMap(2,2:end)-zMap(2,1)),(zMap(2,:)-zMap(2,1))];
%        temp2 = temp2+zMap(2,1);
%        zMap = [temp1;temp2];
       disp(['Do you know that you are remapping Zs to ',num2str(zMap(2,:)),' ???'])
   else
       zMap = 0;
   end
    %[58,-42]1PR1 [51,-42]1PR0.5
  % actually y offset in terms of SI
                 % (++ to move holes down, -- for up)
                  % If using xoffset, use real number, if not set to NaN to
                  % use xrotate
 %175; % (-- to move holes left, ++ for right)
% xoffset = 0; yoffset = 0;
   xrotate = 0*[0 0 0 0 0 0 0]; % fix for rotation along 1 axis (offsets with respect to z along x)
                                    % If using xrotate, set xoffset to NaN
   yrotate = 0*[-1.5 -0.5 -1 0 1 0.5 1.5]; % same wrt y
                                    % If using yrotate, set yoffset to NaN

   number = 0;
   for n=1:nstrips
   currsf = hSI.hRoiManager.currentRoiGroup.rois(n).scanfields(1);
   imagingScanfield = currsf;
   for i = 1:size(sources{n},3)
       mask = sources{n}(:,:,i);
       intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
       intsf.threshold = 100;
       introi = scanimage.mroi.Roi();
       introi.discretePlaneMode=1;
       %        introi.add(z(i)+OptoTuneDepthsToProbe(o), intsf);
       introi.add(OptoTuneDepthsToProbe(o), intsf); %send Scan Image without Z info
       introi.name = ['ROI ' num2str(number+1) ];%' Depth ' num2str(zDepth(n))];
       hSI.hIntegrationRoiManager.roiGroup.add(introi);
       number=number+1;
   end
   end
   
%%Prepare HoloRequest
loc=MesoLocFile_SI();
clear holoRequest
holoRequest.objective = 20;
holoRequest.zoom = hSI.hRoiManager.scanZoomFactor;
zoomscalef = 1.0/holoRequest.zoom;

holoRequest.xoffset=xoffset;
holoRequest.yoffset= yoffset;
holoRequest.hologram_config= 'DLS';
holoRequest.ignoreROIdata = 1;
%     lx=sifov;
%     ly=sifov;
    if(~isnan(xoffset))
        MODxoffset = holoRequest.xoffset*zoomscalef;%*sipix/lx;
    end
    if(~isnan(yoffset))
        MODyoffset = holoRequest.yoffset*zoomscalef;%*sipix/ly;
    end
    
rois = evalin('base','hSI.hIntegrationRoiManager.roiGroup.rois');
centerXY = zeros(length(rois),2);
centerZ = zeros(length(rois),1);
for idx = 1:length(rois)
    centerXY(idx,1:2) = (rois(idx).scanfields.centerXY)*zoomscalef;
    centerZ(idx,1) = z(idx)+OptoTuneDepthsToProbe(o);
end

%Hacky Z Correction added by Ian 9/30/19
if isempty(zMap) || numel(zMap)==1 || all(zMap(:)~=0)%UPDATE with current "zero plane"
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
% centerXY = scanimage.mroi.util.xformPoints(centerXY,inv(pixelToRefTransform));
centerXY = fliplr(xyorig);
holoRequest.targets=[centerXY centerZc];
holoRequest.actualtargets = [centerXY centerZ];
holoRequest.ao0 = ao0;
holoRequest.ao1 = ao1;
holoRequest.powernorm = power;
%holoRequest.xoffset=MODxoffset;commented LA24/06/20
%holoRequest.yoffset=MODyoffset;

save([loc.HoloRequest_SI 'holoRequest.mat'],'holoRequest'); 
save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');
save([loc.HoloRequest_DAQ_Galvos sprintf('holoRequest%d%d.mat',row,col)],'holoRequest');
disp('Sent ROIs to the cloud')
%% Server Workaround
% 
% %run SImsocketPrep on DAQ computer first
% DAQmSocketPrep
% 
% mssend(DAQSocket, holoRequest)


end

