% the previous version (makeMasks3D_holeburn_HS) returns different
% holoRequest.targets for every MROI setting
% we want holoRequest.targets to stay the same (converted to the
% calibration setting) regardless of the MROI setting

%%%%%%% only changed 3 lines
% xyorig(:,1) = round(xynorm(:,1)*fullnpix_orig(1)-1);
% xyorig(:,2) = round(xynorm(:,2)*fullnpix_orig(2));
% holoRequest.targets=[fliplr(xyorig) centerZc];

%% Create Array of Targets
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

z=zeros([size(xy,1) 1]);

for i=1:11
    z(find(xy(:,1)==30*i+20+56))=0*15*(6-i);%*0 for flat eagle pattern
end
xy(:,1) = xy(:,1)-00; %[-100:100] Offset the eagle by these many pixels (- moves it up, + moves it down)
xy(:,2) = xy(:,2)-00; %[-100:100] Offset the eagle by these many pixels (- moves it up, + moves it down)
% (-80x, 0y) avoids zero order in the center fork and also roughly
% balances DEs in both wings

xynorm = xy/sipix;
xyum = xynorm;
xynew = xynorm;
%%%%%%%%%%%%%% Holemasks generated in normalized coordinates

nstrips_orig = 3;
nxpiSx_orig = 400*ones(nstrips_orig,1);
nypix_orig = 600*ones(nstrips_orig,1);
fullnpix_orig = [sum(nxpix_orig),mean(nypix_orig)];

xyorig(:,1) = round(xynorm(:,1)*fullnpix_orig(1)-1);
xyorig(:,2) = round(xynorm(:,2)*fullnpix_orig(2));

%%%%%%%%%%%%%% Holemasks converted to pixel coordinates with respect to
%%%%%%%%%%%%%% calibrated holo fov

%%%%%%%%%%%% Convert holemasks to absolute um coords
[fullxpix_orig,fullypix_orig] = meshgrid(linspace(1,fullnpix_orig(1),fullnpix_orig(1)),...
    linspace(1,fullnpix_orig(2),fullnpix_orig(2)));
fullxsize_orig = 400*nstrips_orig; %um
fullysize_orig = 1200; %um
fullxcenter_orig = 450; %um
fullycenter_orig = -450; %um
[fullxum_orig,fullyum_orig] = meshgrid(...
    linspace(fullxcenter_orig-fullxsize_orig/2,fullxcenter_orig+fullxsize_orig/2,fullnpix_orig(1)),...
    linspace(fullycenter_orig-fullysize_orig/2,fullycenter_orig+fullysize_orig/2,fullnpix_orig(2))...
    );
fullxum_orig = round(fullxum_orig);
fullyum_orig = round(fullyum_orig);
for i=1:size(xyorig,1)
    currind = fullxpix_orig==xyorig(i,1) & fullypix_orig==xyorig(i,2);
    xyum(i,:) = [fullxum_orig(currind),fullyum_orig(currind)];
end
%%%%%%%%%%%%% Holemasks converted to absolute um coordinates

%%%%%%%%%%%%% Convert holemasks to pixels in current/imaged sf/ROI
nstrips = length(hSI.hRoiManager.currentRoiGroup.rois);
nxpix = zeros(nstrips,1);
nypix = zeros(nstrips,1);
xsize = zeros(nstrips,1);
ysize = zeros(nstrips,1);
xcenter = zeros(nstrips,1);
ycenter = zeros(nstrips,1);
for n=1:nstrips
    currsf = hSI.hRoiManager.currentRoiGroup.rois(n).scanfields(1);
    nxpix(n) = currsf.pixelResolutionXY(1);
    nypix(n) = currsf.pixelResolutionXY(2);
    xsize(n) = currsf.sizeXY(1)*150; %um
    ysize(n) = currsf.sizeXY(2)*150; %um
    xcenter(n) = currsf.centerXY(1)*150; %um
    ycenter(n) = currsf.centerXY(2)*150; %um
end
fullnpix = [sum(nxpix),mean(nypix)];

[fullxpix,fullypix] = meshgrid(linspace(1,fullnpix(1),fullnpix(1)),...
    linspace(1,fullnpix(2),fullnpix(2)));
fullxsize = sum(xsize); %um
fullysize = mean(ysize); %um
fullxcenter = (xcenter(1)-xsize(1)/2) + ...
    abs((xcenter(1)-xsize(1)/2) - (xcenter(end)+xsize(end)/2))/2; %um
fullycenter = mean(ycenter); %um
[fullxum,fullyum] = meshgrid(...
    linspace(fullxcenter-fullxsize/2,fullxcenter+fullxsize/2,fullnpix(1)),...
    linspace(fullycenter-fullysize/2,fullycenter+fullysize/2,fullnpix(2))...
    );
fullxum = round(fullxum);
fullyum = round(fullyum);

for i=1:size(xyum,1)
    currind = find(abs(fullxum-xyum(i,1))<=1 & abs(fullyum-xyum(i,2))<=1);
    [currindx,currindy] = ind2sub(size(fullxum),currind(1));
%     currindx = abs(fullnpix(1)-currindx);
    xynew(i,:) = [fullxpix(currindx,currindy),fullypix(currindx,currindy)];
end
%%%%%%%%%%%%%% Holemasks converted to pixels in current ROI/FOV

%%%%%%%%%%%%%% Create source masks from holemasks
sources = cell(nstrips,1);
cumnxpix = [0;cumsum(nxpix)];
SE=strel('disk',radius,4);
for n=1:nstrips
    idmasks = xynew(:,1)>cumnxpix(n) & xynew(:,1)<cumnxpix(n+1);
    currxy = [xynew(idmasks,1)-cumnxpix(n),xynew(idmasks,2)];
    nmasks = sum(idmasks);
    sources{n} = zeros(nypix(n),nxpix(n),nmasks);
    for i = 1:size(sources{n},3);
        sources{n}(currxy(i,2),currxy(i,1),i)=1;
        sources{n}(:,:,i)=imdilate(sources{n}(:,:,i),SE);
    end
end

temp = [];
for n=1:nstrips
    if(~isempty(sources{n}))
        currtemp = max(sources{n},[],3);
    else
        currtemp = zeros([size(sources{n},1),size(sources{n},2)]);
    end
    currtemp(:,1:2) = 1; currtemp(:,end-1:end) = 1;
    temp = cat(2,temp,currtemp);
end
figure(999);imagesc(temp)
   
   %% send targets to ScanImage 
   
   % WHAT PLANE ARE YOU LOOKING AT (1, 2 ,3, 4, 5, 6, or 7)????
   OPTOTUNE_PLANE = 4; %moving eagle center at that plane
   
   
   o = OPTOTUNE_PLANE;
   hSI.hIntegrationRoiManager.roiGroup.clear() 
   imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);
   
   OptoTuneDepthsToProbe = [-90 -60 -30 0 30 60 90];

   correctZ = 1; %Hacky correct Z cerrors added 9/30/19 by Ian
   if correctZ
       zMap=[ [-90 -60 -30 0 30 60 90];... %aka Zs % only planes 5,6,7 have sense, the rest is there so the vector would fit
           [-90 -60 -30 0 30 60 90] ]; % [-96 -64 -32 0 32 64 96] optotune units
       % --correction if right wing is brighter and ++ if left is brighter
%        temp1 = [-fliplr(zMap(1,2:end)),zMap(1,:)];
%        temp2 = [-fliplr(zMap(2,2:end)-zMap(2,1)),(zMap(2,:)-zMap(2,1))];
%        temp2 = temp2+zMap(2,1);
%        zMap = [temp1;temp2];
       disp(['Do you know that you are remapping Zs to ',num2str(zMap(2,:)),' ???'])
   else
       zMap=0;
   end

   xoffset = -8; % actually y offset in terms of SI (++ for down, -- for up)
                  % If using xoffset, use real number, if not set to NaN to
                  % use xrotate
   yoffset = 188; % (-- for left, ++ for right)
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
% centerXY = scanimage.mroi.util.xformPoints(centerXY,inv(pixelToRefTransform));
centerXY = fliplr(xynew);
holoRequest.targets=[fliplr(xyorig) centerZc];
holoRequest.actualtargets = [fliplr(xynew) centerZ];

holoRequest.xoffset=MODxoffset;
holoRequest.yoffset=MODyoffset;

try
    save([loc.HoloRequest_SI 'holoRequest.mat'],'holoRequest'); 
    save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');
    disp('Sent ROIs to the cloud')
catch
    disp('****WARNING: HOLOREQUEST SAVE ERROR!!! Find another way...****')
    disp('Trying to send via msocket to DAQ...')
    mssend(DAQSocket, holoRequest)

end
selectAllROIs;

%% Server Workaround
% 
% %run SImsocketPrep on DAQ computer first
% DAQmSocketPrep
% 
% mssend(DAQSocket, holoRequest)
