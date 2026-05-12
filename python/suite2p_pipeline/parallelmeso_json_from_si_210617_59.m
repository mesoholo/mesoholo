%MESOHOLO-DOC
% Repository: mesoholo (Abdeladim et al., 2026). File: python/suite2p_pipeline/parallelmeso_json_from_si_210617_59.m
% Purpose: Build suite2p JSON from ScanImage TIFFs for a fixed session layout under ``data/sessions``.
%
% this script errors in Matlab R2016b. Run in later versions

% set to folder with tiffs (repository-local)
root = fullfile(mesoholo_repo_from_script(), 'data', 'sessions', 'HS_CamKIIGC6s_59', '210617', 'RFcircleCI1');
fs = dir(fullfile(root, '*.tif'));
fname = fullfile(fs(1).folder, fs(1).name);

% try
header = imfinfo(fname);
stack = loadFramesBuff(fname,1,1,1);

% get frame rate fs
%     Software = header(1).Software;
%     Software = ['{', Software, '}'];
%     X = jsondecode(header(1).Software);
%     fs = X.SI.hRoiManager.scanVolumeRate;
%try
%    fs = hSI.hRoiManager.scanVolumeRate;
%catch
%    fs = 4;
%end

% get relevant infomation for TIFF header
artist_info     = header(1).Artist;

% retrieve ScanImage ROIs information from json-encoded string 
artist_info = artist_info(1:find(artist_info == '}', 1, 'last'));

artist = jsondecode(artist_info);
%
hSIh = header(1).Software;
hSIh = regexp(splitlines(hSIh), ' = ', 'split');
for n=1:length(hSIh)
	if strfind(hSIh{n}{1}, 'SI.hRoiManager.scanVolumeRate')
		fs = str2double(hSIh{n}{2});
	end
	if strfind(hSIh{n}{1}, 'SI.hFastZ.userZs')
		zs = str2num(hSIh{n}{2}(2:end-1));
		nplanes = numel(zs);
	end
	
end


%% make ops.json for all MROIs combined
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
n_rows_sum = sum(Ly);
n_flyback = (size(stack, 1) - n_rows_sum) / max(1, (nrois - 1));

irow = [0 cumsum(Ly'+n_flyback)];
irow(end) = [];
irow(2,:) = irow(1,:) + Ly';

data = [];
data.fs = fs;
data.nplanes = nplanes;
data.nrois = size(irow,2);
if data.nrois == 1
	data.mesoscan = 0;
else
	data.mesoscan = 1;
end
data.diameter = [6,9];
data.num_workers_roi = 5;
data.keep_movie_raw = 0;
data.delete_bin = 1;
data.batch_size = 1000;
data.nimg_init = 400;
data.tau = 2.0;
data.combined = 1;
data.nonrigid = 1;

if data.mesoscan
    data.nrois = size(irow,2);
    for i = 1:size(irow,2)
        if data.mesoscan
            data.dx(i) = int32(imin(i,2));
            data.dy(i) = int32(imin(i,1));
        end
        data.lines{i} = irow(1,i):(irow(2,i)-1);
    end
end

% %% SAVE JSON

% data path is from tiff location
s = regexp(root, filesep, 'split');
fpath = s{1};
for j = 2:numel(s)
    fpath = [fpath '/' s{j}];
end
data.data_path{1} = fpath;
disp(fpath)

fastRoot = getenv('MESOHOLO_SUITE2P_FAST_DISK');
if isempty(fastRoot)
    data.save_path0 = fpath;
else
    fpathSave = fastRoot;
    for j = 2:numel(s)
        fpathSave = [fpathSave '/' s{j}];
    end
    data.save_path0 = fpathSave;
end
disp(data.save_path0)

d = jsonencode(data);
disp(fullfile(root, 'ops.json'))
fileID = fopen(fullfile(root, 'ops.json'),'w');
fprintf(fileID, d);
fclose(fileID);


%% make ops.json for each MROI stripe
si_rois = artist.RoiGroups.imagingRoiGroup.rois;
% get ROIs dimensions for each z-plane
Lyall = [];
Lxall = [];
cXYall = [];
szXYall = [];

for k = 1:numel(si_rois)
	Lyall(k,1) = si_rois(k).scanfields(1).pixelResolutionXY(2);
	Lxall(k,1) = si_rois(k).scanfields(1).pixelResolutionXY(1);
	cXYall(k, [2 1]) = si_rois(k).scanfields(1).centerXY;
	szXYall(k, [2 1]) = si_rois(k).scanfields(1).sizeXY;
end

cXYall = cXYall - szXYall/2;
cXYall = cXYall - min(cXYall, [], 1);
muall = median([Lyall, Lxall]./szXYall, 1);
iminall = cXYall .* muall;

% deduce flyback frames from most filled z-plane
n_rows_sum = sum(Lyall);
n_flyback = (size(stack, 1) - n_rows_sum) / max(1, (numel(si_rois) - 1));

irowall = [0 cumsum(Lyall'+n_flyback)];
irowall(end) = [];
irowall(2,:) = irowall(1,:) + Lyall';

for iroi = 1:numel(si_rois)

% get ROIs dimensions for each z-plane
nrois = 1;
Ly = Lyall(iroi);
Lx = Lxall(iroi);
cXY = cXYall(iroi,:);
szXY = szXYall(iroi,:);

mu = median([Ly, Lx]./szXY, 1);
imin = cXY .* mu;

irow = irowall(:,iroi);

data = [];
data.fs = fs;
data.nplanes = nplanes;
data.nrois = size(irow,2);
% if data.nrois == 1
% 	data.mesoscan = 0;
% else
% 	data.mesoscan = 1;
% end
data.mesoscan = 1;
data.diameter = [6,9];
data.num_workers_roi = 5;
data.keep_movie_raw = 0;
data.delete_bin = 1;
data.batch_size = 1000;
data.nimg_init = 400;
data.tau = 2.0;
data.combined = 1;
data.nonrigid = 1;

if data.mesoscan
    data.nrois = size(irow,2);
    for i = 1:size(irow,2)
        if data.mesoscan
            data.dx(i) = int32(imin(i,2));
            data.dy(i) = int32(imin(i,1));
        end
        data.lines{i} = irow(1,i):(irow(2,i)-1);
    end
end

% %% SAVE JSON

% data path is from tiff location
s = regexp(root, filesep, 'split');
fpath = s{1};
for j = 2:numel(s)
    fpath = [fpath '/' s{j}];
end
data.data_path{1} = fpath;
% disp(fpath)

fastRoot = getenv('MESOHOLO_SUITE2P_FAST_DISK');
if isempty(fastRoot)
    data.save_path0 = fpath;
else
    fpathSave = fastRoot;
    for j = 2:numel(s)
        fpathSave = [fpathSave '/' s{j}];
    end
    data.save_path0 = fpathSave;
end
% disp(data.save_path0)

d = jsonencode(data);
opsfn = [root 'ops_', num2str(iroi-1), '.json'];
disp(opsfn)
fileID = fopen(opsfn,'w');
fprintf(fileID, d);
fclose(fileID);

end

%{
%% SAVE ZSTACK FROM Z-MOTION CORRECTION
if isempty(me_saved) || me_saved==0
    filePath  = fullfile(root, 'MotionEstimator.me');
    hSI.hMotionManager.saveManagedEstimators(filePath); % when called without arguments, this function opens a file dialog.
    me_saved = 1;
end

save(fullfile(root, 'zstack.mat'), 'Z')
fprintf('Succesfully saved zstack\n')

% catch
%     warning('could not write out ops file')
% end
%}
