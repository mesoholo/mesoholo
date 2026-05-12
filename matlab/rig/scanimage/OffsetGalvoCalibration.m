%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/OffsetGalvoCalibration.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

clearvars -EXCEPT hSI hSICtl
% User initializes the offsets of the FOV to calibrate. FOV to calibrate
% will correspond to non-Nan values.AO0 values (X galvos) correspond to
% rows and A01 values (Y galvos) correspond to columns. 
%A0 values in order: -2,-1.5,-1,-0.5,0,0.5,1,1.5,2. For AO0 values, rows
%also correspond to SI rows but inverted ( upper rows, negaiv voltage
%values, corresopnd to botton SI FOVs). 9x9 corresponds to our 9x9 FOV
%grids
%IMPORTANT: current SI hSI FOV needs to have 1um X and Y pixel size (same
%as reference calibrated FOV) and it needs to include all requested FOVs to
%calibrate.


mesoholo_setup();

%% Configuration (toggle behavior here)
cfg = struct();
cfg.preloadExisting = true;      % load previous grids from shared folder
cfg.runSanityChecks = false;     % verify all grids share same non-NaN pattern

locations = MesoLocFile_SI();

if cfg.preloadExisting
    folderpath = locations.HoloRequest_DAQ_Galvos;
    %Get a list of all .MAT files in the folder. The folder should only
    %have 5 files corresponding to the 5 grids. 
    files = dir(fullfile(folderpath,'*.mat'));
    for k=1:length(files)
        fullpath = fullfile(folderpath,files(k).name);
        
        loadedData = load(fullpath);
        [~,varName,~] = fileparts(files(k).name);
        varName = matlab.lang.makeValidName(varName);
        
        eval([varName ' = loadedData;']);
    end
    
else
Xoffsetgrid.Xoffsetgrid = nan(9,9);%To do initialize as struct
Yoffsetgrid.Yoffsetgrid = nan(9,9);
Zoffsetgrid.Zoffsetgrid = nan(9,9);
Tilteaglegrid.Tilteaglegrid = nan(9,9);
Powergrid.Powergrid = nan(9,9);
Currfovgrid.Currfovgrid = nan(9,9);
end

%%%
%User needs to manually fill the grid with initialization values. 
disp('Now enter or update Initial HB Grid values');

array = Currfovgrid.Currfovgrid;
[col,row,numNonNanElements] = getFOVtocalibrate(array,1,0);

%% Sanity check that grids are filled properly
if cfg.runSanityChecks
    array = Yoffsetgrid.Yoffsetgrid;
    [newcol,newrow,~] = getFOVtocalibrate(array,0,0);
    if ~isequal(col,newcol), disp ('Something is off, please check your Y grid'); end
    if ~isequal(row,newrow), disp ('Something is off, please check your Y grid'); end

    array = Zoffsetgrid.Zoffsetgrid;
    [newcol,newrow,~] = getFOVtocalibrate(array,0,0);
    if ~isequal(col,newcol), disp ('Something is off, please check your Z grid'); end
    if ~isequal(row,newrow), disp ('Something is off, please check your Z grid'); end

    array = Tilteaglegrid.Tilteaglegrid;
    [newcol,newrow,~] = getFOVtocalibrate(array,0,0);
    if ~isequal(col,newcol), disp ('Something is off, please check your Tilteagle grid'); end
    if ~isequal(row,newrow), disp ('Something is off, please check your Tilteagle grid'); end

    array = Powergrid.Powergrid;
    [newcol,newrow,~] = getFOVtocalibrate(array,0,0);
    if ~isequal(col,newcol), disp ('Something is off, please check your Power grid'); end
    if ~isequal(row,newrow), disp ('Something is off, please check your Power grid'); end
end

%%%%%%%%%%%%%%%%%%%%%%%%
%%% Make and send Holorequest (with custom offsets, tilieagle,power, galvo voltages) for each FOV to calibrate
%Delete all temporary holorequests before making new ones
folderpath = locations.HoloRequest_DAQ_Galvos;
files = dir(fullfile(folderpath,'holoRequest*.mat'));
for i =1:length(files)
    filepath = fullfile(folderpath,files(i).name);
    delete(filepath);
end
%Make Holorequests for FOVs to calibrate (1HR per FOV)
allinfo = zeros(numNonNanElements,9);
for n=1:numNonNanElements
    allinfo(n,1) = row(n);
    allinfo(n,2) = col(n);
    allinfo(n,3) = row(n)*0.5-2.5; %AO0
    allinfo(n,4) = col(n)*0.5-2.5; %Ao1
    allinfo(n,5) = Xoffsetgrid.Xoffsetgrid(row(n),col(n));
    allinfo(n,6) = Yoffsetgrid.Yoffsetgrid(row(n),col(n));
    allinfo(n,7) = Zoffsetgrid.Zoffsetgrid(row(n),col(n));
    allinfo(n,8) = Tilteaglegrid.Tilteaglegrid(row(n),col(n));
    allinfo(n,9) = Powergrid.Powergrid(row(n),col(n));
    generatedrequest = MakeHBHolorequest(allinfo(n,1),allinfo(n,2),allinfo(n,5),allinfo(n,6),allinfo(n,7),allinfo(n,8),allinfo(n,9), allinfo(n,3),allinfo(n,4),hSI);  
end
% Displays all ROIS on ScanImageIntegration
xynew = maketiledSIrois(allinfo,numNonNanElements,hSI);
%%%% Z: --correction if right wing is brighter and ++ if left is brighter
%%%% X: (++ to move holes down, -- for up)
%%%% Y: (-- to move holes left, ++ for right)

%% Saves all offset grids (This needs to be ran all the times since the segmantation code is reading from the grids)

savepath = locations.HoloRequest_DAQ_Galvos;

%%%% Just to make sure allinfo is updated for final changes to offset
%%%% (without another holeburn)
[col,row,numNonNanElements] = getFOVtocalibrate(array,1,0);
allinfo = zeros(numNonNanElements,9);
for n=1:numNonNanElements
    allinfo(n,1) = row(n);
    allinfo(n,2) = col(n);
    allinfo(n,3) = row(n)*0.5-2.5; %AO0
    allinfo(n,4) = col(n)*0.5-2.5; %Ao1
    allinfo(n,5) = Xoffsetgrid.Xoffsetgrid(row(n),col(n));
    allinfo(n,6) = Yoffsetgrid.Yoffsetgrid(row(n),col(n));
    allinfo(n,7) = Zoffsetgrid.Zoffsetgrid(row(n),col(n));
    allinfo(n,8) = Tilteaglegrid.Tilteaglegrid(row(n),col(n));
    allinfo(n,9) = Powergrid.Powergrid(row(n),col(n));
end
fullsavepath = fullfile(savepath,'allinfo.mat');
save(fullsavepath,'allinfo');

Xoffsetgrid = Xoffsetgrid.Xoffsetgrid;
fullsavepath = fullfile(savepath,'Xoffsetgrid.mat');
save(fullsavepath,'Xoffsetgrid');
Yoffsetgrid = Yoffsetgrid.Yoffsetgrid;
fullsavepath = fullfile(savepath,'Yoffsetgrid.mat');
save(fullsavepath,'Yoffsetgrid');
Zoffsetgrid = Zoffsetgrid.Zoffsetgrid;
fullsavepath = fullfile(savepath,'Zoffsetgrid.mat');
save(fullsavepath,'Zoffsetgrid');
Tilteaglegrid = Tilteaglegrid.Tilteaglegrid;
fullsavepath = fullfile(savepath,'Tilteaglegrid.mat');
save(fullsavepath,'Tilteaglegrid');
Powergrid = Powergrid.Powergrid;
fullsavepath = fullfile(savepath,'Powergrid.mat');
save(fullsavepath,'Powergrid');
Currfovgrid = Currfovgrid.Currfovgrid;
fullsavepath = fullfile(savepath,'Currfovgrid.mat');
save(fullsavepath,'Currfovgrid');

files = dir(fullfile(savepath,'*.mat'));
for k=1:length(files)
    fullpath = fullfile(folderpath,files(k).name);
    
    loadedData = load(fullpath);
    [~,varName,~] = fileparts(files(k).name);
    varName = matlab.lang.makeValidName(varName);
    
    eval([varName ' = loadedData;']);
end

disp ('Updated and saved everything!')
