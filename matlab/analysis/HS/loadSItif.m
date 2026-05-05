% generate a avg image from a raw SI tif file
% check that this matches with the suite2p meanimg, i.e., that it is not flipped in any dimension

% How can I select multiple points using the Data Cursor and export the coordinates to the MATLAB workspace?
% https://www.mathworks.com/matlabcentral/answers/94353-how-can-i-select-multiple-points-using-the-data-cursor-and-export-the-coordinates-to-the-matlab-work
% 1. Generate figure.
% 2. Click the Data Cursor button on the toolbar of the generated figure.
% 3. Click any point of your choice on the line in the figure.
% 4. While pressing the Alt key, repeat step 3 as many times as you like until you have selected your desired set of points.
% 5. Right-click (or control-click if you are on a Mac) anywhere on the figure, and select the 'Export Cursor Data to Workspace...' option from the context menu.
% 6. Accept the default variable name, "cursor_info", and click "OK".
% 7. Type "cursor_info.Position" at the MATLAB command prompt and hit "Enter".
addpath 'C:\Users\MesoDAQ\Documents\MATLAB\MesoSICode\HScode\suite2p_pipeline'

tiffn = 'S:\Hyeyoung\SI\HS\MU23_1\220728copy\RFtracking\file_03331.tif';

header = imfinfo(tiffn);
hSIh = header(1).Software;
hSIh = regexp(splitlines(hSIh), ' = ', 'split');
for n=1:length(hSIh)
    if strfind(hSIh{n}{1}, 'SI.hRoiManager.scanVolumeRate')
        fs = str2double(hSIh{n}{2});
    end
end

artist_info     = header(1).Artist;
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
stack = loadFramesBuff(tiffn,1,1,1);

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

import ScanImageTiffReader.ScanImageTiffReader;
% f0=ScanImageTiffReader([sipath tiffns(1).name]);
% f0data = f0.data();
% f0mean = mean(f0data,3);

imfile=ScanImageTiffReader(tiffn);
imdata = imfile.data();
immean = squeeze(mean(imdata,3));
immaxproj = squeeze(max(imdata,[],3));

meanimg = zeros(max(Ly), sum(Lx));
maxprojimg = zeros(max(Ly), sum(Lx));
for istrip = 1:numel(Ly)
    meanimg(1:Ly(istrip), sum(Lx(1:istrip-1))+1:sum(Lx(1:istrip))) = immean(:,data.lines{istrip}+1)';
    maxprojimg(1:Ly(istrip), sum(Lx(1:istrip-1))+1:sum(Lx(1:istrip))) = immaxproj(:,data.lines{istrip}+1)';
end

figure; hold all
imagesc(meanimg)
% plot(xynew(:,1), xynew(:,2), 'rx')

