function [ xyorig,xynew,xyum,nstrips,z,sources ] = makeHBeagle(xy,tilteagle,hSI)

%% Create Array of Targets
% clearvars -EXCEPT hSI hSICtl


sipix = 512;
radius = 5;

z=zeros([size(xy,1) 1]);

%%%%% Choose flat (0) or tilted (1) eagle based on scalar
for i=1:11
    z(find(xy(:,1)==30*i+20+56))=tilteagle*5*(6-i); %*tilteagle for flat eagle pattern
end
%%%%% Uncomment to have fork tips on 0 plane
% z(find(xy(:,1)==30*5+20+56 & xy(:,2)~=256))=0;
% z(find(xy(:,1)==30*7+20+56 & xy(:,2)~=256))=0;
%%%%% Offset from center of holo fov
xy(:,1) = xy(:,1)-10; %[-100:100] Offset the eagle by these many pixels
% (- moves it left, + moves it right)
xy(:,2) = xy(:,2)+100; %[-100:100] Offset the eagle by these many pixels
% (- moves it up, + moves it down)
% (-80x, 0y) avoids zero order in the center fork and also roughly
% balances DEs in both wings

xynorm = xy/sipix;
xyum = xynorm;
xynew = xynorm;
%%%%%%%%%%%%%% Holemasks generated in normalized coordinates
%%%% Temp grid holes
% clear xynorm
% % [xynorm1,xynorm2] = meshgrid(linspace(0.05,0.45,10),linspace(0.3,0.7,10));
% [xynorm1,xynorm2] = meshgrid(linspace(0.45,0.55,10),linspace(0.45,0.55,10));
% xynorm(:,1) = xynorm1(:);
% xynorm(:,2) = xynorm2(:);
% z = zeros(size(xynorm,1),1);
% xyum = xynorm;
% xynew = xynorm;
%%%%
%%%%%%%%%%%%%% Convert holemasks to calibrated holo fov pixel coordinates
nstrips_orig = 3;
nxpix_orig = 200*ones(nstrips_orig,1);
nypix_orig = 600*ones(nstrips_orig,1);
fullnpix_orig = [sum(nxpix_orig),mean(nypix_orig)];
 
xyorig = xynorm;
xyorig(:,1) = round(xynorm(:,1)*fullnpix_orig(1));
xyorig(:,2) = round(xynorm(:,2)*fullnpix_orig(2));
%%%%%%%%%%%%%% Holemasks converted to pixel coordinates with respect to
%%%%%%%%%%%%%% calibrated holo fov

%%%%%%%%%%%% Convert holemasks to absolute um coords
[fullxpix_orig,fullypix_orig] = meshgrid(linspace(1,fullnpix_orig(1),fullnpix_orig(1)),...
    linspace(1,fullnpix_orig(2),fullnpix_orig(2)));
fullxsize_orig = 200*nstrips_orig; %um
fullysize_orig = 600; %um
fullxcenter_orig = 425; %um
fullycenter_orig = 0; %um
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