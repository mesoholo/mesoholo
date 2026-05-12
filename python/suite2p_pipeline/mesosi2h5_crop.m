%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: python/suite2p_pipeline/mesosi2h5_crop.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

%% EDIT files that do not have frame numbers that are multiples of Nplanes * numchannels
% this script replaces check_before_suite2p
% this should be done in savio
% this is really slow compared to Mora's python script...

clear all;
loadall = true;

repo0 = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo0, 'matlab'));

mesoSIpath = fullfile(repo0, 'data', 'sessions', 'HS_Ai203_2', '220531');
vispath = fullfile(mesoSIpath, 'visstiminfo');

xlb = 1002; % horizontal
xub = 1906; % horizontal
ylb = 415;
yub = 865;

visfiles = dir(fullfile(vispath, '*.mat'));
for ii= 1:numel(visfiles)
    disp(visfiles(ii).name)
end
ls(mesoSIpath)
foldername = {'staticICtxi0'};
disp(foldername)
input('USER NEEDS TO INPUT FOLDER NAMES FOR EVERY SESSION IN ORDER MATCHING EXPTIDN')

%%
sireaderpath = getenv('MESOHOLO_SI_MATLAB');
if isempty(sireaderpath)
    third = fullfile(repo0, 'third_party', 'Analyze_IC_mesoscope');
    if exist(third, 'dir')
        sireaderpath = third;
    else
        sireaderpath = fullfile(repo0, 'python', 'suite2p_pipeline');
    end
end
addpath(genpath(sireaderpath))
import ScanImageTiffReader.ScanImageTiffReader;

fnh = fullfile(mesoSIpath, 'merged_cropped.h5');
if exist(fnh, 'file')
    delete(fnh)
end

% tiffns = cat(1, dir([SIpath, '*.tif']), dir([SIpath, '*/*.tif']));
for f = 1:numel(foldername)
    if f == 1
        tiffns = dir(fullfile(mesoSIpath, foldername{f}, '*.tif'));
    else
        tiffns = cat(1, tiffns, dir(fullfile(mesoSIpath, foldername{f}, '*.tif')));
    end
end
% tiffns = cat(1, tiffns, dir([mesoSIpath, '*.tif']));

%% dimensions of mesoscope scanimage tif files
tiffile = fullfile(mesoSIpath, foldername{1}, tiffns(1).name);
tiffheader = imfinfo(tiffile);
hSIh = tiffheader(1).Software;
hSIh = regexp(splitlines(hSIh), ' = ', 'split');
for n=1:length(hSIh)
    if strfind(hSIh{n}{1}, 'SI.hChannels.channelSave')
        nch = n;
        channelssaved = str2num(hSIh{n}{2});
    end
end
numchannels = numel(channelssaved);

artist_info     = tiffheader(1).Artist;
artist_info = artist_info(1:find(artist_info == '}', 1, 'last'));
artist = jsondecode(artist_info);
si_rois = artist.RoiGroups.imagingRoiGroup.rois;
% get ROIs dimensions for each z-plane
nrois = numel(si_rois);

Ly = [];
Lx = [];
cXY = [];
szXY = [];
for k = 1:nrois
    Ly(k,1) = si_rois(k).scanfields(1).pixelResolutionXY(2);
    Lx(k,1) = si_rois(k).scanfields(1).pixelResolutionXY(1);
    cXY(k, [2 1]) = si_rois(k).scanfields(1).centerXY;
    szXY(k, [2 1]) = si_rois(k).scanfields(1).sizeXY;
end
cXY = cXY - szXY/2;
cXY = cXY - min(cXY, [], 1);
mu = median([Ly, Lx]./szXY, 1);
imin = cXY .* mu;

% deduce flyback frames from most filled z-plane
stack = loadFramesBuff(tiffile,1,1,1);

n_rows_sum = sum(Ly);
n_flyback = (size(stack, 1) - n_rows_sum) / max(1, (nrois - 1));

irow = [0 cumsum(Ly'+n_flyback)];
irow(end) = [];
irow(2,:) = irow(1,:) + Ly';

data = struct();
data.nrois = size(irow,2);
for i = 1:size(irow,2)
    data.dx(i) = int32(imin(i,2));
    data.dy(i) = int32(imin(i,1));
    data.lines{i} = irow(1,i):(irow(2,i)-1);
end

%% load all tif files, reshape, crop and save as h5
% with Nframes2read = 10000, every qcnt takes 1.5 min
% still estimated ~45min for a holo session
% when calling h5write for every tif file, this takes a *long* time.
% approx 10 files per minute, when each file contains 200 frames (10000 frames ~5 min)
tic
numframesperfile = zeros(size(tiffns,1),1);

framecnt = 0;
q = [];
if loadall
    %q = zeros(yub-ylb+1, xub-xlb+1, 0, 'int16');
else
    qcnt = 0; Nframes2read = 50000;
end
% whichvisfile = zeros(size(suite2pfilelist,1),1);
for f = 1:size(tiffns,1)
    tiffile = [tiffns(f).folder '/' tiffns(f).name];
    
    reader=ScanImageTiffReader(tiffile);
    desc=reader.descriptions();
    numframesperfile(f) = size(desc,1);
    
    temp = reader.data();
    q = cat(3, q, temp);
    
    if loadall
    else
        if size(q,3)>=Nframes2read
            % reshape the data
            tempdata = zeros(max(Ly), sum(Lx), size(q,3));
            for istrip = 1:numel(Ly)
                tempdata(1:Ly(istrip), sum(Lx(1:istrip-1))+1:sum(Lx(1:istrip)), :) = permute(q(:,data.lines{istrip}+1,:),[2 1 3]);
            end
            % crop the data
            q = tempdata(ylb:yub, xlb:xub, :);
            
            qcnt = qcnt+1;
            if qcnt ==1
                h5create(fnh,'/data',[size(q,1) size(q,2) Inf], 'DataType','int16', 'ChunkSize',[size(q,1) size(q,2) size(q,3)]); %
                h5write(fnh,'/data',q,[1 1 1],[size(q,1) size(q,2) size(q,3)]);
            else
                h5write(fnh,'/data',q,[1 1 framecnt+1],[size(q,1) size(q,2) size(q,3)]);
            end
            framecnt = framecnt+size(q,3);
            q = [];
        end
    end
    if mod(f,50)==0
        fprintf('%d/%d files loaded\n', f, size(tiffns,1)); toc
    end
end
% reshape the data
tempdata = zeros(max(Ly), sum(Lx), size(q,3));
for istrip = 1:numel(Ly)
    tempdata(1:Ly(istrip), sum(Lx(1:istrip-1))+1:sum(Lx(1:istrip)), :) = permute(q(:,data.lines{istrip}+1,:),[2 1 3]);
end
% crop the data
q = tempdata(ylb:yub, xlb:xub, :);
if loadall
    h5create(fnh,'/data',[size(q,1) size(q,2) size(q,3)], 'DataType','int16'); %
    h5write(fnh,'/data',q,[1 1 1],[size(q,1) size(q,2) size(q,3)]);
else
    qcnt = qcnt+1;
    h5write(fnh,'/data',q,[1 1 framecnt+1],[size(q,1) size(q,2) size(q,3)]);
    framecnt = framecnt+size(q,3);
    q = [];
end
toc

if framecnt ~= sum(numframesperfile)
    error('check frame accumulation')
end
numplanes = 1;
numtimepointsperfile = numframesperfile/(numchannels*numplanes);

save(strcat(mesoSIpath, 'presuite2p_params.mat'), 'foldername', 'tiffns', ...
    'numframesperfile', 'numtimepointsperfile', 'numchannels') %, 'whichvisfile'

% 50/1352 files loaded
% Elapsed time is 37.521897 seconds.
% 100/1352 files loaded
% Elapsed time is 96.904541 seconds.
% 150/1352 files loaded
% Elapsed time is 206.123756 seconds.
% 200/1352 files loaded
% Elapsed time is 316.745725 seconds.
% 250/1352 files loaded
% Elapsed time is 461.644815 seconds.