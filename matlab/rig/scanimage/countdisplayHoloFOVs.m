%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/countdisplayHoloFOVs.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [XYnewtosave,indexestosave,concatenatedXYum] = countdisplayHoloFOVs(hSI)
%countdisplayHoloFOVs takes in current SI FOV (WARNING: needs to be sent at
%1x1um/pixel same as calibration of actual holo central fov), and sends coordinates of centers of masses and IDs of all holoFOVs within the imaging FOVs.  
%   This is based on a 9x9 Grid, with centers spaced  by 350um (0.5V
%   galvos), hardcoded.
%% Create Array of Targets
% clearvars -EXCEPT hSI hSICtl
tilteagle = 0;

sipix = 512;
radius = 5;

xy = [256 256];% Central point in the FOV
%xy = xy+repmat([56,56],[16,1]);
xy = xy*sipix/512;

[ xyorig,xynew,xyum,nstrips,z,sources ] = makeHBeagle(xy,tilteagle,hSI);

%%%%%%%%%%%%% Calculate pix/um for current/imaged sf/ROI
currsf = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);
xppu = round(currsf.pixelRatio(1))/150; % 150 for 1ppu
yppu = round(currsf.pixelRatio(2))/150; % 150 for 1ppu
%%%%%%%%%%%%%

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
    linspace(fullxcenter-fullxsize/2,fullxcenter+fullxsize/2,fullnpix(1)/xppu),...
    linspace(fullycenter-fullysize/2,fullycenter+fullysize/2,fullnpix(2)/yppu)...
    );
fullxum = round(fullxum);
fullyum = round(fullyum);

for i=1:size(xyum,1)
%     currind = find(abs(fullxum-xyum(i,1))<=1 & abs(fullyum-xyum(i,2))<=1);
%     changed by HS 220714 to make isequal(xyorig, xynew) true
%     when ActualHoloFOV.roi is used
    currind = find(abs(fullxum-xyum(i,1))==min(min(abs(fullxum-xyum(i,1)))) & ...
        abs(fullyum-xyum(i,2))==min(min(abs(fullyum-xyum(i,2)))));
    [currindx,currindy] = ind2sub(size(fullxum),currind(1));
%     currindx = abs(fullnpix(1)-currindx);
    xynew(i,:) = [fullxpix(round(currindx*yppu),round(currindy*xppu)),...
        fullypix(round(currindx*yppu),round(currindy*xppu))];
end
%%%%%%%%%%%%%% Holemasks converted to pixels in current ROI/FOV
%% Here we tile the holo FOVs across the current SI FOV 
% Range of current FOV in microns
rangeSIFOV_Xum = [min(min(fullxum)), max(max(fullxum))];
rangeSIFOV_Yum = [min(min(fullyum)), max(max(fullyum))];


concatenatedXYum= [];%Holographic centers in absolute micron coordinates 
indexes = [];
for xn=1:9 %number of rows (FOVs)
    for yn=1:9
 
        newvector = xyum;
        
        AO0 = xn*0.5-2.5;
        AO1 = yn*0.5-2.5;
        newvector(:,1) = newvector(:,1)+ AO1*700; %A01*-700 (check sign empirically)
        newvector(:,2) = newvector(:,2)-AO0*700; %A00*-700 (negative voltages, down in the SI FOV)
        if (newvector(1)>rangeSIFOV_Xum(1)) && (newvector(1)<rangeSIFOV_Xum(2)) && (newvector(2)<rangeSIFOV_Yum(2)) && (newvector(2)>rangeSIFOV_Yum(1))
            concatenatedXYum = [concatenatedXYum; newvector];
            newindexes(:,1) = xn;
            newindexes(:,2) = yn;
            indexes = [indexes;newindexes];
        
        end
    end
end

% Conversion of holographic centers from absolute micron coordinates to
% relative coordinates in current SI FOV
for i=1:size(concatenatedXYum,1)
%     currind = find(abs(fullxum-xyum(i,1))<=1 & abs(fullyum-xyum(i,2))<=1);
%     changed by HS 220714 to make isequal(xyorig, xynew) true
%     when ActualHoloFOV.roi is used
    currind = find(abs(fullxum-concatenatedXYum(i,1))==min(min(abs(fullxum-concatenatedXYum(i,1)))) & ...
        abs(fullyum-concatenatedXYum(i,2))==min(min(abs(fullyum-concatenatedXYum(i,2)))));
    [currindx,currindy] = ind2sub(size(fullxum),currind(1));
%     currindx = abs(fullnpix(1)-currindx);
    concatenatedXYnew(i,:) = [fullxpix(round(currindx*yppu),round(currindy*xppu)),...
        fullypix(round(currindx*yppu),round(currindy*xppu))];
end
xynew = concatenatedXYnew;

%%
%%%%%%%%%%%%%% Create source masks from holemasks
sources = cell(nstrips,1);
cumnxpix = [0;cumsum(nxpix)];
SE=strel('disk',radius,4);
combined_mask = false(size(concatenatedXYum,1),1);%This initializes a boolean variable that will register all xynew coordinates that are included in the current imaging FOV, smmarizing all instances of idmasks across loops basically. 
for n=1:nstrips
    idmasks = xynew(:,1)>cumnxpix(n) & xynew(:,1)<=cumnxpix(n+1);
    combined_mask = combined_mask | idmasks;
    currxy = [xynew(idmasks,1)-cumnxpix(n),xynew(idmasks,2)];
    nmasks = sum(idmasks);
    available_fovs = sum(combined_mask);
    sources{n} = zeros(nypix(n),nxpix(n),nmasks);
    [columnsInImage rowsInImage] = meshgrid(1:nxpix(n), 1:nypix(n));
    for i = 1:size(sources{n},3)
        sources{n}(:,:,i) = double(((rowsInImage-currxy(i,2)).^2)/((4*yppu)^2) + ...
            ((columnsInImage-currxy(i,1)).^2)/((4*xppu)^2) <= 1 );
%         sources{n}(currxy(i,2),currxy(i,1),i)=1;
%         sources{n}(:,:,i)=imdilate(sources{n}(:,:,i),SE);
    end
end

%Variables to save
XYnewtosave = concatenatedXYnew(combined_mask,:);
indexestosave = indexes(combined_mask,:);
%%%%%%%%%%%%%% Sources created from holemasks

%%%%%%%%%%%%%% Display/plot holemasks wrt current fov scanfields
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
figure(999);imagesc(temp) %NB: DISPLAY IS WEIRD. Makes it look like it is not working but actually it is working great. 
   
   %% send targets to ScanImage
   
   % WHAT PLANE ARE YOU LOOKING AT (1, 2 ,3, 4, 5, 6, or 7)????
   OPTOTUNE_PLANE = 3; %moving eagle center at that plane
   
   
   o = OPTOTUNE_PLANE;
   hSI.hIntegrationRoiManager.roiGroup.clear()
   imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);
   
   OptoTuneDepthsToProbe = [-100 -50 0 50 100];

   

   number = 0;
   nerror = [];
   ierror = [];
   ngood = [];
   igood = [];
   for n=1:nstrips
   currsf = hSI.hRoiManager.currentRoiGroup.rois(n).scanfields(1);
   imagingScanfield = currsf;
   for i = 1:size(sources{n},3)

       mask = sources{n}(:,:,i);
       if any(mask(:))==1
       try
       intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
       catch
           nerror = [nerror;n];
           ierror = [ierror;i];
       end
       
       intsf.threshold = 100;
       introi = scanimage.mroi.Roi();
       introi.discretePlaneMode=1;
       %        introi.add(z(i)+OptoTuneDepthsToProbe(o), intsf);
       introi.add(OptoTuneDepthsToProbe(o), intsf); %send Scan Image without Z info
       introi.name = ['ROI ' num2str(number+1) ];%' Depth ' num2str(zDepth(n))];
       hSI.hIntegrationRoiManager.roiGroup.add(introi);
       number=number+1;
       ngood = [ngood;n];
       igood = [igood;i];

       end
       
   end
   end
goodindexes = [];
for gd = 1:length(ngood)  
cumulativelength = 0;
cellNumber = ngood(gd);
indexwithin = igood(gd);
for j=1:(cellNumber-1)
   cumulativelength = cumulativelength+size(sources{j},3);
end
flattenedindex = cumulativelength+indexwithin;
goodindexes = [goodindexes;flattenedindex];
end

retain_mask = false(size(XYnewtosave,1));
retain_mask(goodindexes) = true;
%combined_mask(~retain_mask)=false;

XYnewtosave = XYnewtosave(retain_mask,:);
indexestosave = indexestosave(retain_mask,:);

%% Display the holographic FOVs
matrixSize = 9;
grayvalue=0.5;
matrix = grayvalue*ones(matrixSize);
greenvalue = 2;
for i=1:length(indexestosave)
    matrix(indexestosave(i,1),indexestosave(i,2)) = 2;
end
figure;
imagesc(matrix);
cmap = [0.5 0.5 0.5;0 1 0];
colormap(cmap);
colorbar;
axis equal tight
hold on 
for k=0.5:1:matrixSize+0.5
    plot([0.5,matrixSize+0.5],[k,k],'k');
    plot([k,k],[0.5,matrixSize+0.5],'k');
end
hold off
title('Available holographic FOVs');

%% Warning in case something goes off
if length(XYnewtosave) ~= length(concatenatedXYum)
    disp('Check calculations, something is off');
else
    disp ('Conversions all good')
end
