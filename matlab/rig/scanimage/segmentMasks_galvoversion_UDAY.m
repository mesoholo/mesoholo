%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/segmentMasks_galvoversion_UDAY.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

%% Gets available holographic FOVs given a SI mesoscale FOV
%Select your current imaging FOV. Make sure during all these steps to have
%the pixel size set to 1x1 um/pixel (matched with actual holo FOV initial
%parameter)
clearvars -EXCEPT hSI hSICtl
[XYnewtosave,indexestosave,concatenatedXYum] = countdisplayHoloFOVs(hSI);
disp('Number of Holographic FOVs in current SI mesoscale FOV:'); 
disp(size(indexestosave,1));
%You can now Update the integrations tab: ROIs with centers of holographic
%FOVs should be displayed on the ROI Group Editor 
%% Paths and dataset selection
% This script was historically run as a one-off per experiment day and
% edited by commenting/uncommenting blocks. Configure the dataset below.
mesoholo_setup();

cfg = struct();
cfg.corepath = getenv("MESOHOLO_DATA_ROOT");
if strlength(cfg.corepath) == 0
    r = mesoholo_repo_root();
    r = r(1:end-1);
    cfg.corepath = string(fullfile(r, 'data', 'sessions'));
else
    cfg.corepath = string(cfg.corepath);
end
cfg.corepath = [char(cfg.corepath) filesep];

cfg.mouseid = 'MU76_2_aav189'; % name of main mouse folder inside core path
cfg.date = '20260503/000'; % folder with the TIFF data, organized in numbered folders
                  % The numbered folders are in sequence from the
                   % posterio-medial location going left M->L, then one row up P->A
                   % and then right L->M and so on, change as needed
                   % The superficial/vasculature fov tiffs for all fovs are also located directly in this

% Imaging settings
cfg.nplanes = 1;
cfg.nchannels = 1;
cfg.chantouse = 1; % 1 for green, 2 for red
cfg.planetouse = 1;

root = [cfg.corepath, cfg.mouseid,'\',cfg.date,'\'];
currjson = extractjsonparams(root);
currxpix = currjson.Lx(1); %184,620
currxum = currjson.szXY(1,2)*150;
currypix = currjson.Ly(1); %828,1550
curryum = currjson.szXY(1,1)*150;
ntilex = currjson.nrois;
imsize = [currypix,currxpix*ntilex];

gfrate = round(currjson.fs); % derived from JSON

fs = dir(fullfile(root, '*.tif'));
fname = fs(1).name;
fname = fullfile(root, fname);
header = imfinfo(fname);
nframes = length(header);
gframes = zeros([imsize,round(nframes/(nchannels*nplanes))]);
ct = 0;
for i=nchannels*(planetouse-1)+chantouse:nchannels*nplanes:nframes
    ct = ct+1;
    temp = imread(fname,i);
    newframe = zeros(imsize);
    framec = imsize/2;
    for k=1:ntilex
        currxyc = currjson.cXY(k,:)*150;%currxyc(1)=0;
        currsz = currjson.szXY(k,:)*150;
        currirow = currjson.irow(:,k);
        
        currxlim = [(k-1)*currxpix + 1 ,(k-1)*currxpix + currxpix];
        currylim = [1,currypix];
        newframe(currylim(1):currylim(2),currxlim(1):currxlim(2)) = ...
            imresize(temp(currirow(1)+1:currirow(2),:),[length(currylim(1):currylim(2)),length(currxlim(1):currxlim(2))]);
    end
    gframes(:,:,ct) = newframe;
end

%% assign all 3 planes in base;

%top left, top right, bottom left
clear img
nstrips = ntilex;
for n=1:nstrips
    ImageData = mean(gframes(1:currypix,(n-1)*currxpix+(1:currxpix),:),3);
    img{n} = real(ImageData);
end

% img{3}=zeros(512,512,3);
[ypix,xpix] = size(ImageData);

%% Set current actualholofov parameters and plot holofov on image
Opts.xppu = round(currxpix)/round(currxum);
Opts.yppu = round(currypix)/round(curryum);
Opts.channel = 'green';%'red';
if strcmp(Opts.channel,'red');
channel = 1;
elseif strcmp(Opts.channel,'green');
channel = 1;
else
disp('Error - select red or green');
end

imgData = zeros(ypix,xpix,numel(img));
skimgData = zeros(ypix,xpix,numel(img));
for n = 1:numel(img)
imgData(:,:,n) = single(img{n}(:,:,channel));
%     skimgData(:,:,n) = single(skimg{n}(:,:,channel));
%     imgData(:,:,n) = single(max(img{n}(:,:,channel)))-single(img{n}(:,:,channel));
end

%%%%%% SET ActualHoloFOV parameters here
nstrips_orig = 3;
nxpix_orig = 200*ones(nstrips_orig,1);
nypix_orig = 600*ones(nstrips_orig,1);
fullnpix_orig = [sum(nxpix_orig),mean(nypix_orig)];
fullxsize_orig = 200*nstrips_orig; %um
fullysize_orig = 600; %um
fullxcenter_orig = 425; %um
fullycenter_orig = 0; %um
%%%%%%

fullim = [];
for i=1:size(imgData,3)
    temp = imgData(:,:,i);
    temp(:,[1:2,end-1:end]) = 100;
    fullim = [fullim,temp];
end
imxsz = size(fullim,2); imysz = size(fullim,1);
imypixcenter = imysz/2;
imxpixcenter = imxsz/2;
imytruecenter = mean(currjson.cXY(:,1)*150);
imxtruecenter = mean(currjson.cXY(:,2)*150);
%holoytruecenter = fullycenter_orig;
%holoxtruecenter = fullxcenter_orig;
%holoxpixcenter = imxpixcenter+(holoxtruecenter-imxtruecenter)*Opts.xppu;
%holoypixcenter = imypixcenter+(holoytruecenter-imytruecenter)*Opts.yppu;

%holowest = holoxpixcenter-((1200-200)/2)*Opts.xppu; holowest(holowest<1) = 1;
%holoeast = holoxpixcenter+((1200-200)/2)*Opts.xppu; holoeast(holoeast>imxsz) = imxsz;
%holonorth = holoypixcenter+((1200-200)/2)*Opts.yppu; holonorth(holonorth<1) = 1;
%holosouth = holoypixcenter-((1200-200)/2)*Opts.yppu; holosouth(holosouth>imysz) = imysz;

figure()
imagesc(fullim);hold on;colormap gray
%plot([holowest;holowest],[holonorth;holosouth],'k')
%plot([holowest;holoeast],[holonorth;holonorth],'k')
%plot([holowest;holoeast],[holosouth;holosouth],'k')
%plot([holoeast;holoeast],[holonorth;holosouth],'k')
slideclim([0 20])

%% Define options and extract
Opts.maxSourcesPerPlane = 300; %75
Opts.radius = [7,10]*mean([Opts.xppu,Opts.yppu]); %center/surround [3,7] for red, [7,10] for green, [9,13] for ppu1
Opts.width = 31:xpix-35;%101:512-100 for zoom1.5 32/64, 141:512-120 for zoom1.5 40/64, 141:512-120 for zoom1 40/64
%71:xpix-75 %31:xpix-35
Opts.height = 400:800; %301:1200;%11:512-10 for zoom1.5, 51:512-50 for zoom1on the display that's the height of the total image
Opts.distThreshold = 20; %10 or 15 in pix %22 for 30um % 7-8 @ zoom 1 for 15um
Opts.brightestFirst = 1; %1 default 1
Opts.redQuantileRange = [0.25 1]; % 0.67, 0.5 for low thresh
params.Opts = Opts;
params.nfilts = 40;
params.shockval = 0.5;
params.edgemethod = 'canny';
params.perilo = 0.05;
params.perihi = 0.95;
params.circlo = 0.1;
params.circhi = 1;
params.mindistfromnewbad = 20;
params.mindistfromnewgood = 20;
params.mindistfromany = 20;
params.sourceR = 6; %4
%don't change below here

tseg = tic;
[sources_all,extdata_all]=extractROIs3_uday(imgData,skimgData,params.Opts);
% [sources_all,extdata_all]=segmentROIs3(imgData,params);
toc(tseg)
%load('C:\Users\MesoRig\Documents\MATLAB\temp.mat')

%% Visualize rois on fov and holographic FOV centers
figure()
imagesc(fullim);hold on;colormap gray
%plot([holowest;holowest],[holonorth;holosouth],'k')
%plot([holowest;holoeast],[holonorth;holonorth],'k')
%plot([holowest;holoeast],[holosouth;holosouth],'k')
%plot([holoeast;holoeast],[holonorth;holosouth],'k')
for i=1:length(extdata_all)
    if (~isempty(extdata_all(i).OC))
    plot(extdata_all(i).OC(:,1)+(i-1)*size(imgData,2),extdata_all(i).OC(:,2),'ro') %OC(:,1)columns, OC(:,2)ROWS
    end
end
hold on 
%Plot all centers of holographic FOVS  
slideclim([0 20])
%% Assign all cells to holographic FOV 
%This just plots the HoloFOV centers for visualization
hold on 
for i=1:length(XYnewtosave)
    plot(XYnewtosave(i,1),XYnewtosave(i,2),'x','Color','g','Markersize',10,'LineWidth',2) %OC(:,1)columns, OC(:,2)ROWS
end

%%
%Calculates the number of total segmented targets
ntargets = 0;
for i=1:length(extdata_all)
    if (~isempty(extdata_all(i).OC))
    ntargetstripe = length(extdata_all(i).OC(:,1));
    ntargets = ntargets + ntargetstripe;
    end
end
ntargetstr = num2str(ntargets);
disp([ntargetstr ' total targets found']);

%Assigns each segmented target to a holographic FOV
targetarray = zeros(ntargets,10);%Columns: Xcoordtarget,Ycoordtarget,Stripenumber, IdxX holoFOV, IdxY holoFOV, AO0, AO1,distancetocenter,minindex,t)
u=1;
for i=1:length(extdata_all)
    if (~isempty(extdata_all(i).OC))
    for t=1:length(extdata_all(i).OC(:,1))
        target = [extdata_all(i).OC(t,1)+(i-1)*size(imgData,2),extdata_all(i).OC(t,2)]; %columns,rows
        %Calculates the euclidian distance of the target to all holographic
        %FOV centers
        distances = sqrt(sum((XYnewtosave-target).^2,2));
        [min_distance, min_index] = min(distances);
        %Retrieve the closest point
        closest_point = XYnewtosave(min_index,:);
        targetarray(u,1) = target(1);
        targetarray(u,2) = target(2);
        targetarray(u,3) = i;
        targetarray(u,4) = XYnewtosave(min_index,1);
        targetarray(u,5) = XYnewtosave(min_index,2);
        targetarray(u,6) = indexestosave(min_index,1)*0.5-2.5;
        targetarray(u,7) = indexestosave(min_index,2)*0.5-2.5;
        targetarray(u,8) = min_distance;
        targetarray(u,9) = min_index;
        targetarray(u,10) = t;
        u=u+1;
    end
    end
end

%Dislay to check Holo FOV assignment 
numColors = length(XYnewtosave);
% colors = rand(numColors,3);
figure()
imagesc(fullim); axis equal; hold on;colormap gray
for k = 1:length(targetarray)
    colorindex = targetarray(k,9);
    plot(targetarray(k,1),targetarray(k,2),'ro','Color',colors(colorindex,:));
end
hold on 
slideclim([0 20])
plotindexes = 1;
for i=1:length(XYnewtosave)
    plot(XYnewtosave(i,1),XYnewtosave(i,2),'x','Color',colors(i,:),'Markersize',10,'LineWidth',2) %OC(:,1)columns, OC(:,2)ROWS
    if plotindexes == 1
        text(XYnewtosave(i,1),XYnewtosave(i,2),['(' num2str(indexestosave(i,1)) ',' num2str(indexestosave(i,2)) ')'], 'FontSize',8,'HorizontalAlignment','center');
    end
end
title('Segmented cells and Assigned holographic FOVS')
%% Here instead of filtering based on manually selected ROIs as before, we filter based on wether the associated FOV is calibrated or not
loc = MesoLocFile_SI();
load(fullfile(loc.HoloRequest_DAQ_Galvos, 'allinfo.mat'))
disp(['Found ' num2str(size(allinfo,1)) ' calibrated holo FOVs']);
indexes_calibrated = allinfo(:,1:2);
subIndexesmain = zeros(size(indexes_calibrated,1),1);
outsidefov = [];
for i = 1:size(indexes_calibrated,1)
    [isMember,rowindex] = ismember(indexes_calibrated(i,:),indexestosave,'rows');
    if isMember
        subIndexesmain(i) = rowindex;
    else
       outsidefov =[outsidefov,i];
    end
end
logicalindex = true(size(subIndexesmain,1),1);
logicalindex(outsidefov)= false;
subIndexsmain_filtered = subIndexesmain(logicalindex,:) ;
indexes_calibrated_filtered = indexes_calibrated(logicalindex,:);
indexes_calibrated = indexes_calibrated_filtered;
subIndexesmain = subIndexsmain_filtered;
allinfo_filtered = allinfo(logicalindex,:);
allinfo = allinfo_filtered;
disp(['Found ' num2str(size(subIndexesmain ,1)) ' calibrated holo FOVs in the current imaging FOV']);
indexes_calibrated(:,3) = subIndexesmain ;

%Finding targets that belong to a calibrated holo FOVs
isMatch = ismember(targetarray(:,9),subIndexesmain);
%Create a new target array with only the targets matched to pre-calibrated
%FOVs
calibratedTargets = targetarray(isMatch,:);

figure()
imagesc(fullim);axis equal; hold on;colormap gray
for k = 1:length(calibratedTargets)
    colorindex = calibratedTargets(k,9);
    hMarkers = plot(calibratedTargets(k,1),calibratedTargets(k,2),'ro','Color',colors(colorindex,:));
end
hold on 
slideclim([0 20])

for i=1:length(subIndexesmain)
    plot(XYnewtosave(subIndexesmain(i),1),XYnewtosave(subIndexesmain(i),2),'x','Color',colors(subIndexesmain(i),:),'Markersize',10,'LineWidth',2) %OC(:,1)columns, OC(:,2)ROWS
end
title('Calibrated FOVs and Matched targets');
%% Interactive filtering Mode 1: Option to remove cells. Run, click on cells to remove (iterate zoom&pan with roi selection, close window when done)

selectedPoints_1 = interactive_Cell_Select(fullim,calibratedTargets,colors,0,20,subIndexesmain,XYnewtosave);

% Find closest match in calibratedTargets and delete
deselectedROIs_1 = [];
%mindistances1 = []; Sanity check
for i=1:size(selectedPoints_1,1)
    distances1 = sqrt((calibratedTargets(:,1)-selectedPoints_1(i,1)).^2 + (calibratedTargets(:,2)-selectedPoints_1(i,2)).^2);
    [mindist,idx] = min(distances1);
    deselectedROIs_1 =[deselectedROIs_1;idx];
    %mindistances1 = [mindistances1;mindist]; Sanity check 
end
calibratedTargets(deselectedROIs_1,:)=[];
%% Interactive filtering Mode 2: Option to add new cells. Run, click on cells to add (iterate zoom&pan with roi selection, close window when done)
selectedPoints_2 = interactive_Cell_Select(fullim,calibratedTargets,colors,0,20,subIndexesmain,XYnewtosave);

%mindistances1 = []; Sanity check
% Assign selected points to holoFOVs, find stripe number and Add selected points to calibratedTargets 
v = size(calibratedTargets,1)+1;
stripeSizes=zeros(1,length(extdata_all));
for i=1:length(extdata_all)
    stripeSizes(1,i) = length(extdata_all(i).OC(:,1));
end
for i=1:size(selectedPoints_2,1)
    distances2 = sqrt((XYnewtosave(:,1)-selectedPoints_2(i,1)).^2 + (XYnewtosave(:,2)-selectedPoints_2(i,2)).^2);
    [mindist,idx] = min(distances2);
    calibratedTargets(v,1)=selectedPoints_2(i,1);
    calibratedTargets(v,2)=selectedPoints_2(i,2);
    Q = floor(selectedPoints_2(i,1)/size(imgData,2))+1;
    calibratedTargets(v,3)= Q; 
    calibratedTargets(v,10)= stripeSizes(1,Q)+1;
    stripeSizes(1,Q)= stripeSizes(1,Q)+1;
    calibratedTargets(v,4)=XYnewtosave(idx,1);
    calibratedTargets(v,5)=XYnewtosave(idx,2);
    calibratedTargets(v,6)=indexestosave(idx,1)*0.5-2.5;
    calibratedTargets(v,7)=indexestosave(idx,2)*0.5-2.5;
    calibratedTargets(v,8)=mindist;
    calibratedTargets(v,9)=idx;
    v = v+1;
    %mindistances1 = [mindistances1;mindist]; Sanity check 
end

%Finding targets that belong to a calibrated holo FOVs
isNewMatch = ismember(calibratedTargets(:,9),subIndexesmain);
%Create a new target array with only the targets matched to pre-calibrated
%FOVs
calibratedTargets = calibratedTargets(isNewMatch,:);

%% Interactive filtering Mode 3: Option to correct centers. Run, click on best center positions (iterate zoom&pan with roi selection, close window when done)
selectedPoints_3 = interactive_Cell_Select(fullim,calibratedTargets,colors,0,20,subIndexesmain,XYnewtosave);
betterselectedROIs_3 = [];
%mindistances1 = []; Sanity check
for i=1:size(selectedPoints_3,1)
    distances3 = sqrt((calibratedTargets(:,1)-selectedPoints_3(i,1)).^2 + (calibratedTargets(:,2)-selectedPoints_3(i,2)).^2);
    [mindist,idx] = min(distances3);
    betterselectedROIs_3 =[betterselectedROIs_3;idx];
    calibratedTargets(idx,1)=selectedPoints_3(i,1);
    calibratedTargets(idx,2)=selectedPoints_3(i,2);
    %mindistances1 = [mindistances1;mindist]; Sanity check 
end

% Find closest match in calibratedTargets and replaces it

%% Remove cells based on stimmability (for 1 fov)
calibratedTargets = calibratedTargets(goodcells,:);

%% Check final targets
figure()
imagesc(fullim);axis equal; hold on;colormap gray
for k = 1:size(calibratedTargets,1)
    colorindex = calibratedTargets(k,9);
    hMarkers = plot(calibratedTargets(k,1),calibratedTargets(k,2),'ro','Color',colors(colorindex,:));
end
hold on 
slideclim([0 40])

for i=1:length(subIndexesmain)
    plot(XYnewtosave(subIndexesmain(i),1),XYnewtosave(subIndexesmain(i),2),'x','Color',colors(subIndexesmain(i),:),'Markersize',10,'LineWidth',2) %OC(:,1)columns, OC(:,2)ROWS
end
title('Final Calibrated FOVs and Matched targets');

%% Interactive filtering Mode 4: Only keep cells within manually drawn ROIs (Uday's version) 
%To do later
%% Generate Source ROI masks and HoloRequests
%Initialize main holoRequest
%Initialize array of array All_sources
hSI.hIntegrationRoiManager.roiGroup.clear()
%For each calibrated holoFOV, count and display number of segmented
%targets, convert XY new to non-galvo values, generate sources & masks,
fovtargets = zeros(1,size(indexes_calibrated,1));
all_local_sources = {};
rois = {};
all_centersXY = {};
all_centersZ = {};
all_XYnew = {};
all_zMaps = {};
all_xoffsets = {};
all_yoffsets = {};
all_AO0s = {};
all_AO1s = {};
all_powers = {};
%Count and display #targets
%fov=1;
for fov=1:size(indexes_calibrated,1)
    currfov = indexes_calibrated(fov,3);
    %Select the targets that belong to current fov
    rows_with_fov = calibratedTargets(:,9)==currfov;
    num_rows_with_fov = sum(rows_with_fov);
    %Condition: There are cells in given calibrated FOV
    if num_rows_with_fov>0
       fovtargets(1,fov) = num_rows_with_fov;
       disp([num2str(num_rows_with_fov) ' cells found in FOV ' num2str(fov)]);
       arrayfov = calibratedTargets(rows_with_fov,:);
       
    %Convert to Actual Holo Coordinates%NOT TAKEN INTO ACCOUNT IN SOURCES 
    arrayfov(:,11) = arrayfov(:,1) - 700*allinfo(fov,4);%X in actual holo coords/AO1
    arrayfov(:,12) = arrayfov(:,2) + 700*allinfo(fov,3);%Y in actual holo coords/AO0
    %Generate sources
    local_sources  = make_sources(imgData,arrayfov,params.Opts,sources_all,nstrips);
    all_local_sources{fov} = local_sources;
    
    
    %Add sources to integration 
    %%%% launch
        hSI.hIntegrationRoiManager.roiGroup.clear()
        Zplanes = hSI.hFastZ.userZs; % modded to this by uday 1/8/20
        number= 0;
        stripnumbers_all = 0;
      
        for n = 1:nstrips
           currsf = hSI.hRoiManager.currentRoiGroup.rois(n).scanfields(1);
           imagingScanfield = currsf;

           theSources=local_sources{n};
           currsize = size(theSources,3);
            if(isempty(theSources))
                disp('empty the Sources');
                currsize = 0;
            else
                disp('Updating the Sources');
            end
            stripnumbers_all = [stripnumbers_all,currsize];
            for k = 1:currsize
                mask = theSources(:,:,k);
                try
                intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
                intsf.threshold = 100;
                introi = scanimage.mroi.Roi();
                introi.discretePlaneMode=1;
                introi.add(Zplanes(planetouse), intsf);
                introi.name = ['ROI ' num2str(number+1) ];%' Depth ' num2str(zDepth(n))];
                hSI.hIntegrationRoiManager.roiGroup.add(introi);
                number=number+1;
                catch
                    disp('try didnt work')
                end
            end
        end
        disp(['Added ' num2str(number) ' sources to integration']);

    %Read offset calibration information 
      correctZ = 1; %Hacky correct Z cerrors added 9/30/19 by Ian
      zoffset = allinfo(fov,7);
         if correctZ
             zMap=[ [-100 -50 0 50 100];... %aka Zs % only planes 5,6,7 have sense, the rest is there so the vector would fit
                 [-100 -50 0 50 100] + zoffset]; % [-96 -64 -32 0 32 64 96] optotune units
             disp(['Do you know that you are remapping Zs to ',num2str(zMap(2,:)),' ???'])
         else
             zMap = 0;
         end

       xoffset = allinfo(fov,5); % actually y offset in terms of SI (++ for down, -- for up)
                      % If using xoffset, use real number, if not set to NaN to
                      % use xrotate
       yoffset = allinfo(fov,6); % (-- for left, ++ for right)
       xrotate = 0*[0 0 0 0 0 0 0]; % fix for rotation along 1 axis (offsets with respect to z along x)
                                        % If using xrotate, set xoffset to NaN
       yrotate = 0*[-1.5 -0.5 -1 0 1 0.5 1.5]; %
    %Convert150 and get centers from ROIs 
    %%%%%%%%%%%%%%% Convert masks to absolute um coords
    rois{fov} = evalin('base','hSI.hIntegrationRoiManager.roiGroup.rois');
    centerXY = zeros(length(rois{fov}),2);
    centerZ = zeros(length(rois{fov}),1);
    for idx = 1:length(rois{fov})
        centerXY(idx,1:2) = (rois{fov}(idx).scanfields.centerXY)*150;
        centerZ(idx,1) = rois{fov}(idx).zs;
    end

    %Convert XY center coordinates to main Galvo FOV
    for idx = 1:length(rois{fov})
        centerXY(idx,1) = centerXY(idx,1)-700*allinfo(fov,4);%AO1
        centerXY(idx,2) = centerXY(idx,2)+700*allinfo(fov,3);%AO0
    end
  
    %Convert centers XY to XYnew and do galvo adjustment
        [fullxpix_orig,fullypix_orig] = meshgrid(linspace(1,fullnpix_orig(1),fullnpix_orig(1)),...
        linspace(fullnpix_orig(2),1,fullnpix_orig(2)));
    [fullxum_orig,fullyum_orig] = meshgrid(...
        linspace(fullxcenter_orig-fullxsize_orig/2,fullxcenter_orig+fullxsize_orig/2,fullnpix_orig(1)),...
        linspace(fullycenter_orig+fullysize_orig/2,fullycenter_orig-fullysize_orig/2,fullnpix_orig(2))...
        );
    fullxum_orig = round(fullxum_orig);
    fullyum_orig = round(fullyum_orig);
    xyum = (centerXY);
    xynew = zeros(size(xyum,1),2);
    for i=1:size(xyum,1)
        currind = find(abs(fullxum_orig-xyum(i,1))<=1 & abs(fullyum_orig-xyum(i,2))<=1);
        if(~isempty(currind))
    %     [currindx,currindy] = ind2sub(size(fullxum_orig),currind(1));
    % %     currindx = abs(fullnpix(1)-currindx);
    %     xynew(i,:) = [fullxpix_orig(currindx,currindy),fullypix_orig(currindx,currindy)];
        xynew(i,:) = [fullxpix_orig(currind(1)),fullypix_orig(currind(1))];
        else
            xynew(i,:) = [1,1];
        end
    end
        all_centersXY{fov} = centerXY;
        all_centersZ{fov} =  centerZ;
        all_XYnew{fov} = xynew;
    
    
     all_zMaps{fov} =  zMap;
     all_xoffsets{fov} = xoffset;
     all_yoffsets{fov} = yoffset;
     all_AO0s{fov} = allinfo(fov,3);
     all_AO1s{fov} = allinfo(fov,4);
     all_powers{fov} =allinfo(fov,9);

    else
        disp(['No cells found in FOV ' num2str(fov)]);
        all_local_sources{fov} = [];
        rois{fov} = [];
        all_centersXY{fov} = [];
        all_centersZ{fov} = [];
        all_XYnew{fov} = [];
        all_zMaps{fov} =  [];
        all_xoffsets{fov} = [];
        all_yoffsets{fov} = [];
        all_AO0s{fov} = [];
        all_AO1s{fov} = [];
        all_powers{fov} =[];
    end

end

%Custom groups to do: edits on the all_ variables
%Make main mesoRequest

MesoRequest = make_mesoRequest(all_XYnew,all_centersZ,all_yoffsets,all_xoffsets,xrotate,yrotate,all_zMaps,all_AO0s,all_AO1s,all_powers,hSI,0);

% % powcurve = [];
% MesoRequest = make_mesoRequest_uday(all_XYnew,all_centersZ,all_yoffsets,all_xoffsets,xrotate,yrotate,all_zMaps,all_AO0s,all_AO1s,all_powers,hSI,250,powcurve);
% figure;
% subplot(2,2,1);imagesc(MesoRequest.desiredFvec')
% subplot(2,2,2);imagesc(corr(MesoRequest.desiredFvec'));set(gca,'clim',[0 1])
% subplot(2,2,3);imagesc(MesoRequest.roiWeights')
% subplot(2,2,4);imagesc(corr(MesoRequest.roiWeights'));set(gca,'clim',[0 1])
% colormap redblue

%% Save sources and holoRequest data
selectAllROIs;

% save([hSI.hScan2D.logFilePath '/makeMasks3D_img_holofov'],'img', 'imgData','all_local_sources','calibratedTargets','-v7.3');
% save([hSI.hScan2D.logFilePath '/makeMasks3D_img_holofov_moremetadata'],'img', 'imgData','all_local_sources','calibratedTargets',...
%     'indexes_calibrated','allinfo','params','sources_all','nstrips','fullnpix_orig','fullxcenter_orig','fullycenter_orig',...
%     'fullxsize_orig','fullysize_orig','planetouse','-v7.3');

save([hSI.hScan2D.logFilePath '/makeMasks3D_img_stimmable'],'img', 'imgData','all_local_sources','calibratedTargets','powcurve','-v7.3');
save([hSI.hScan2D.logFilePath '/makeMasks3D_img_stimmable_moremetadata'],'img', 'imgData','all_local_sources','calibratedTargets','powcurve',...
    'indexes_calibrated','allinfo','params','sources_all','nstrips','fullnpix_orig','fullxcenter_orig','fullycenter_orig',...
    'fullxsize_orig','fullysize_orig','planetouse','-v7.3');

save([hSI.hScan2D.logFilePath,'/mesoRequest'],'MesoRequest')
disp('sent ROIs to the cloud');

%% Convert coordinates to actual holoFOV coordinates (reverse translation
% than FOV centers).

%% Make master holoRequest with group Ids and voltages 