% this function is essentially the inverse of updateSIrois_meso
% NOTE, USE Zc NOT Z=0!!!
% xynew should come from suite2p'd targets
function holoRequest = s2ptoholoRequest(xynew, hSI, fullnpix_orig, fullxsize_orig, fullysize_orig, fullxcenter_orig, fullycenter_orig)

disp('proceed if holoRequest was from today''s holeburn')
disp('check that xynew(:,1) is the horizontal axis, xynew(:,2) is the vertical axis')
loc=MesoLocFile_SI();
load([loc.HoloRequest_SI 'holoRequest.mat'],'holoRequest');
holoRequest_old = holoRequest;

Zc = unique(holoRequest_old.targets(:,3));
if numel(Zc)~=1
    error('there should be only one corrected z value in this holoRequest')
else
    fprintf('corrected Z at imaging plane: %d\n', Zc)
end

holoRequest = struct();
fields2copy = {'objective', 'zoom', 'xoffset', 'yoffset', 'hologram_config', 'ignoreROIdata'};
for f = 1:numel(fields2copy)
holoRequest.(fields2copy{f}) = holoRequest_old.(fields2copy{f});
end

%%%%%%%%%%%% Convert current MROI coordinates (i.e., suite2p coordinates, aka xynew) to absolute um coords
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

xyum = NaN(size(xynew));
for i=1:size(xynew,1)
%     currind = fullxpix==xynew(i,1) & fullypix==xynew(i,2);
    currind = find(abs(fullxpix-xynew(i,1))==min(min(abs(fullxpix-xynew(i,1)))) & ...
        abs(fullypix-xynew(i,2))==min(min(abs(fullypix-xynew(i,2)))));
    xyum(i,:) = [fullxum(currind(1)),fullyum(currind(1))];
end
%%%%%%%%%%%%% coordinates converted to absolute um coordinates

%%%%%%%%%%%%% Convert um coordinates to pixels in ActualHoloFOV
[fullxpix_orig,fullypix_orig] = meshgrid(linspace(1,fullnpix_orig(1),fullnpix_orig(1)),...
    linspace(1,fullnpix_orig(2),fullnpix_orig(2)));
% fullxsize_orig = 500*nstrips_orig; %um
% fullysize_orig = 1000; %um
% fullxcenter_orig = 0; %um
% fullycenter_orig = -200; %um
[fullxum_orig,fullyum_orig] = meshgrid(...
    linspace(fullxcenter_orig-fullxsize_orig/2,fullxcenter_orig+fullxsize_orig/2,fullnpix_orig(1)),...
    linspace(fullycenter_orig-fullysize_orig/2,fullycenter_orig+fullysize_orig/2,fullnpix_orig(2))...
    );
fullxum_orig = round(fullxum_orig);
fullyum_orig = round(fullyum_orig);
xyorig = NaN(size(xyum));
for i=1:size(xyum,1)
%     currind = fullxum_orig==xyum(i,1) & fullyum_orig==xyum(i,2);
    currind = find(abs(fullxum_orig-xyum(i,1))==min(min(abs(fullxum_orig-xyum(i,1)))) & ...
        abs(fullyum_orig-xyum(i,2))==min(min(abs(fullyum_orig-xyum(i,2)))));
    xyorig(i,:) = [fullxpix_orig(currind(1)),fullypix_orig(currind(1))];
end
%%%%%%%%%%%%%% um coordinates converted to pixels in ActualHoloFOV

centerZc = repmat(Zc,size(xyorig,1),1);
centerXY = fliplr(xyorig);
holoRequest.targets=[centerXY centerZc];
