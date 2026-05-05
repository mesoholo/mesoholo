function [xynew] = maketiledSIrois( allinfo,newnumNonNanElements,hSI)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

%%
tilteagle = 0;

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
%% Here we tile the holeburn pattern

%% Here we tile the holo FOVs across the current SI FOV 
% Range of current FOV in microns
rangeSIFOV_Xum = [min(min(fullxum)), max(max(fullxum))];
rangeSIFOV_Yum = [min(min(fullyum)), max(max(fullyum))];


concatenatedXYum = [];
for n=1:newnumNonNanElements
    newvector = xyum;
    newvector(:,1) = newvector(:,1)+allinfo(n,4)*700; %A01*-700 (check sign empirically)
    newvector(:,2) = newvector(:,2)-allinfo(n,3)*700; %A00*-700 (negative voltages, down in the SI FOV)
    concatenatedXYum = [concatenatedXYum; newvector];
end
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
for n=1:nstrips
    idmasks = xynew(:,1)>cumnxpix(n) & xynew(:,1)<=cumnxpix(n+1);
    currxy = [xynew(idmasks,1)-cumnxpix(n),xynew(idmasks,2)];
    nmasks = sum(idmasks);
    sources{n} = zeros(nypix(n),nxpix(n),nmasks);
    [columnsInImage rowsInImage] = meshgrid(1:nxpix(n), 1:nypix(n));
    for i = 1:size(sources{n},3)
        sources{n}(:,:,i) = double(((rowsInImage-currxy(i,2)).^2)/((4*yppu)^2) + ...
            ((columnsInImage-currxy(i,1)).^2)/((4*xppu)^2) <= 1 );
%         sources{n}(currxy(i,2),currxy(i,1),i)=1;
%         sources{n}(:,:,i)=imdilate(sources{n}(:,:,i),SE);
    end
end
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
figure(999);imagesc(temp)
   
   %% send targets to ScanImage
   
   % WHAT PLANE ARE YOU LOOKING AT (1, 2 ,3, 4, 5, 6, or 7)????
   OPTOTUNE_PLANE = 3; %moving eagle center at that plane
   
   
   o = OPTOTUNE_PLANE;
   hSI.hIntegrationRoiManager.roiGroup.clear()
   imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);
   
   OptoTuneDepthsToProbe = [-250 -100 0 100 250];

   

   number = 0;
   nerror = [];
   ierror = [];
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
       %intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
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
   end
   


end

