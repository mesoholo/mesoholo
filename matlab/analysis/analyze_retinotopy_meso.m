%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/analysis/analyze_retinotopy_meso.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

clear all; 
% close all; clc

mesoholo_setup();

%%
dimflip = 1; % 1 vertical, 2 horizontal

sireaderpath = getenv('MESOHOLO_SI_MATLAB');
if isempty(sireaderpath)
    repo0 = mesoholo_repo_root();
    repo0 = repo0(1:end-1);
    third = fullfile(repo0, 'third_party', 'Analyze_IC_mesoscope');
    if exist(third, 'dir')
        sireaderpath = third;
    else
        sireaderpath = fullfile(repo0, 'python', 'suite2p_pipeline');
    end
end

addpath(genpath(sireaderpath))
import ScanImageTiffReader.ScanImageTiffReader;

% mousedate = 'HS_VIPHalo_15/220705/';
mousedate = 'MU23_1/220803/';
mousedate = 'MU24_1/220803/';
% mousedate = 'HS_Ai203_2/220721/';

depth = '101';
nexp = '001';

repo0 = mesoholo_repo_root();
repo0 = repo0(1:end-1);
relSession = strrep(strtrim(mousedate), '/', filesep);
sipath = fullfile(repo0, 'data', 'sessions', relSession, 'retinotopy1');
visBase = fullfile(repo0, 'data', 'visstiminfo', relSession);
if isfolder(fullfile(visBase, 'visstiminfo'))
    visstimDir = fullfile(visBase, 'visstiminfo');
else
    visstimDir = visBase;
end
cd(visstimDir);
load(fullfile(visstimDir, sprintf('visstim_retinotopy_subscreen_%s_%s.mat', depth, nexp)));

% %%
tiffns = dir(fullfile(sipath, '*.tif'));
if numel(tiffns)-1 ~= retinotopy_subscreen.numtrials
    error('number of tif files %d should equal the number of trials %d plus one', numel(tiffns), retinotopy_subscreen.numtrials)
end

header = imfinfo(fullfile(sipath, tiffns(1).name));
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
stack = loadFramesBuff(fullfile(sipath, tiffns(1).name),1,1,1);

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


numframes2avg = round(fs*retinotopy_subscreen.durvisstim);

ny = size(retinotopy_subscreen.locs, 1);
nx = size(retinotopy_subscreen.locs, 2);
each_loc = cell(ny,nx,retinotopy_subscreen.repetitions);
loccnt = zeros(ny,nx);
tic
for itrial = 1:size(retinotopy_subscreen.locinds,1)
% import ScanImageTiffReader.ScanImageTiffReader;
trialfile=ScanImageTiffReader(fullfile(sipath, tiffns(itrial+1).name));
trialdata = trialfile.data();
    trialmean = squeeze(mean(trialdata(:,:,1:numframes2avg),3));
    
    trialloc=retinotopy_subscreen.locinds(itrial,:);
    y=trialloc(1); x = trialloc(2);
    loccnt(y,x) = loccnt(y,x)+1;    
    each_loc{y,x,loccnt(y,x)} = trialmean;
end
toc
clearvars trialdata

avg_by_loc = cell(ny,nx);
for y = 1:ny
    for x = 1:nx
        avg_by_loc{y,x} = squeeze(mean(cat(3,each_loc{y,x,:}), 3));
    end
end

% %% 
% for every pixel, find the maximal RF and add a transparency mask
% proportional to the normalized RF activity, defined as
% (adjusted activity at RF)/(sum of adjusted activity at all RF), 
% where adjusted activity is (activity at each loc) - (activity at min loc)
% and has a max value of 1 and min value of 1/(ny*nx)
% further adjustment: ((normalized RF activity)*(ny*nx) - 1)/(ny*nx-1)

abl = cat(3,avg_by_loc{:});
avgbyloc = zeros(max(Ly), sum(Lx), size(abl,3));
for iloc = 1:size(abl,3)
for iplane = 1:numel(Ly)
    avgbyloc(1:Ly(iplane), sum(Lx(1:iplane-1))+1:sum(Lx(1:iplane)), iloc) = abl(:,data.lines{iplane}+1,iloc)';
end
end
% flipavgbyloc = flip(avgbyloc, 2);

trialfile=ScanImageTiffReader(fullfile(sipath, tiffns(1).name));
trialdata = trialfile.data();
basetif = squeeze(mean(trialdata(:,:,1:numframes2avg),3));
baseframe = zeros(max(Ly), sum(Lx));
for iplane = 1:numel(Ly)
    baseframe(1:Ly(iplane), sum(Lx(1:iplane-1))+1:sum(Lx(1:iplane))) = basetif(:,data.lines{iplane}+1)';
end

[RFactivity, iRF] = max(avgbyloc,[],3);
[minlocactivity, iminloc] = min(avgbyloc,[],3);

% adjnormRFact = ((RFactivity-minlocactivity)./(squeeze(mean(avgbyloc,3))-minlocactivity) -1)/(ny*nx-1);
% bv= prctile(adjnormRFact(:),1);
% bw = 0.001; bv = mode(bw*(-0.5+round(adjnormRFact(:)/bw +0.5)));
% mv = prctile(adjnormRFact(:),99);
% 
% % figure; hold all; histogram(adjnormRFact(:)); 
% % yl = ylim; plot([mv mv],yl,'r-', 'LineWidth', 1)
% % plot([bv bv],yl,'r-', 'LineWidth', 1)
% 
% adjnormRFact = (adjnormRFact-bv)/ (mv-bv);
% adjnormRFact(adjnormRFact>1)=1;
% adjnormRFact(adjnormRFact<0)=0;


% clearvars each_loc avg_by_loc abl

%{
%%
figure
% opticalzoom = info.config.magnification_list(info.config.magnification);
% switch info.scanmode % unidir if 1
%     case 0
% modedi = 'bidirectional';
%     case 1
% modedi = 'unidirectional';
% end
% annotation('textbox', [0.05 0.91 .9 .1], 'String', ...
%     [mousedate 'retinotopy_subscreen_', nexp, ' ', modedi, ' ', opticalzoom 'X zoom'], ...
%     'interpreter', 'none', 'EdgeColor', 'none', 'FontSize', 14, 'FontWeight', 'bold')

ax1=subplot(2,2,1);
imagesc(squeeze(mean(avgbyloc,3)))
colorbar
% title([mousedate ' mean image'], 'interpreter', 'none')
title('mean image', 'interpreter', 'none')
colormap(ax1, 'gray')

ax2=subplot(2,2,2);
imagesc(squeeze(max(avgbyloc,[],3)))
colorbar
% title([mousedate ' max image'], 'interpreter', 'none')
title('max image', 'interpreter', 'none')
colormap(ax2, 'gray')

ax3=subplot(2,2,3);
% ax3=figure;
imagesc(5 - mod(iRF-1, ny) )%, 'AlphaData', adjnormRFact)
colorbar
title('monitor vertical axis (red is up)')
colormap(ax3, 'jet')

ax4=subplot(2,2,4);
% ax4=figure;
imagesc(1+ (ceil(iRF/ny)-1) )%, 'AlphaData', adjnormRFact)
colorbar
title('monitor horizontal axis (red is right)')
colormap(ax4, 'jet')

%}

% %%
if ny==5 && nx==5
cjy = [0 0 1; 0 1 1; 0 1 0; 1 1 0; 1 0 0];
cjx = cjy;
else
cjy = jet(ny);
cjx = jet(nx);
end

yRF = 5 - mod(iRF-1, ny);
yRFrgb = zeros([size(iRF) 3]);
for y = 1:ny
    yind = find(yRF==y);
    yRFrgb(yind) = cjy(y,1);
    yRFrgb(numel(iRF) + yind) = cjy(y,2);
    yRFrgb(2*numel(iRF) + yind) = cjy(y,3);
end
    
xRF = 1+ (ceil(iRF/ny)-1);
xRFrgb = zeros([size(iRF) 3]);
for x = 1:nx
    xind = find(xRF==x);
    xRFrgb(xind) = cjx(x,1);
    xRFrgb(numel(iRF) + xind) = cjx(x,2);
    xRFrgb(2*numel(iRF) + xind) = cjx(x,3);
end

% fovim = squeeze(max(z,[],3));
fovim = squeeze(mean(avgbyloc,3));
% fovim = (fovim-min(fovim(:)))/range(fovim(:));

%{
%% 
figure
% opticalzoom = info.config.magnification_list(info.config.magnification);
% switch info.scanmode % unidir if 1
%     case 0
% modedi = 'bidirectional';
%     case 1
% modedi = 'unidirectional';
% end
% annotation('textbox', [0.05 0.91 .9 .1], 'String', ...
%     [mousedate 'retinotopy_subscreen_', nexp, ' ', modedi, ' ', opticalzoom 'X zoom'], ...
%     'interpreter', 'none', 'EdgeColor', 'none', 'FontSize', 14, 'FontWeight', 'bold')
subplot(2,2,1)
imshow(fovim)
title([mousedate ' mean image'], 'interpreter', 'none')

subplot(2,2,2)
imshow(adjnormRFact)
title([mousedate ' normRFactivity filter'], 'interpreter', 'none')

subplot(2,2,3)
imshow(xRFrgb)
title('monitor horizontal axis (red is right)')

subplot(2,2,4)
imshow(yRFrgb)
title('monitor vertical axis (red is up)')

%%
figure
% opticalzoom = info.config.magnification_list(info.config.magnification);
% switch info.scanmode % unidir if 1
%     case 0
% modedi = 'bidirectional';
%     case 1
% modedi = 'unidirectional';
% end
% annotation('textbox', [0.05 0.91 .9 .1], 'String', ...
%     [mousedate 'retinotopy_subscreen_', nexp, ' ', modedi, ' ', opticalzoom 'X zoom'], ...
%     'interpreter', 'none', 'EdgeColor', 'none', 'FontSize', 14, 'FontWeight', 'bold')
subplot(2,2,1)
imshow(xRFrgb)
hold on
h=imshow(fovim);
set(h,'AlphaData', 0.6)
title('monitor horizontal axis (red is right)')

subplot(2,2,2)
imshow(yRFrgb)
hold on
h=imshow(fovim);
set(h,'AlphaData', 0.6)
title('monitor vertical axis (red is up)')

% figure
% imshow(fovim);
% hold on
% h=imshow(xRFrgb);
% set(h,'AlphaData', 0.5)
% title('monitor horizontal axis (red is right)')

subplot(2,2,3)
h=imshow(xRFrgb);
set(h,'AlphaData', fovim)
title('monitor horizontal axis (red is right)')

subplot(2,2,4)
h=imshow(yRFrgb);
set(h,'AlphaData', fovim)
title('monitor vertical axis (red is up)')
%}

% %%
fs=18;
% figure
% h=imshow(xRFrgb);
% % set(h,'AlphaData', fovim)
% title('2p image: monitor horizontal axis (red is right)', 'FontSize', fs)
% 
% figure
% h=imshow(yRFrgb);
% % set(h,'AlphaData', fovim)
% title('2p image: monitor vertical axis (red is up)', 'FontSize', fs)

figure
h=imshow(flip(xRFrgb,dimflip));
% set(h,'AlphaData', fovim)
title('flipped: monitor horizontal axis (red is right)', 'FontSize', fs)

figure
h=imshow(flip(yRFrgb,dimflip));
% set(h,'AlphaData', fovim)
title('flipped: monitor vertical axis (red is up)', 'FontSize', fs)

% 
% figure
% h=imshow(imgaussfilt(flip(xRFrgb,2), 25));
% % set(h,'AlphaData', fovim)
% title('flipped: monitor horizontal axis (red is right)', 'FontSize', fs)
% 
% figure
% h=imshow(imgaussfilt(flip(yRFrgb,2), 25));
% % set(h,'AlphaData', fovim)
% title('flipped: monitor vertical axis (red is up)', 'FontSize', fs)


%% from analyze_visfieldsign: strategy 2: do imgaussfilter before averaging across trials and then
if exist('vis', 'var')
ny = size(vis.(exptidn).locs, 1);
nx = size(vis.(exptidn).locs, 2);
else
pixelretinotopy = flip(avgbyloc,dimflip);
tifXres = header(1).XResolution;
tifYres = header(1).YResolution;

ny = size(retinotopy_subscreen.locs, 1);
nx = size(retinotopy_subscreen.locs, 2);
end

% % 25um smoothing in Garrett et al
k = 25;
% neudia = round(10*mean([tifXres tifYres])*10^-4);
xker = round(k*tifXres*10^-4);
yker = round(k*tifYres*10^-4);

smpixelretinotopy = zeros(size(pixelretinotopy));
for iloc = 1:nx*ny
    smpixelretinotopy(:,:,iloc) = imgaussfilt(squeeze(pixelretinotopy(:,:,iloc)), [yker xker]);
end

[~, pixsmRF] = max(smpixelretinotopy,[],3);
[~, pixRF] = max(pixelretinotopy,[],3);

figure('Position', [100 400 1200 300]) 
subplot(1,3,1)
Fallpix = reshape(squeeze(mean(avgbyloc-baseframe,[1,2])), ny,nx);
imagesc(Fallpix); colorbar
xlabel('RF X-position')
ylabel('RF Y-position')
title('all pixels avg F')
subplot(1,3,2)
[Npix,EDGES,BIN] = histcounts(pixRF(:), 0.5:1:nx*ny+0.5);
Nallpix = reshape(Npix, ny,nx);
imagesc(Nallpix); colorbar
xlabel('RF X-position')
ylabel('RF Y-position')
title('pixel count')
subplot(1,3,3)
[Npix,EDGES,BIN] = histcounts(pixsmRF(:), 0.5:1:nx*ny+0.5);
Nallpix = reshape(Npix, ny,nx);
imagesc(Nallpix); colorbar
xlabel('RF X-position')
ylabel('RF Y-position')
title('pixel count (smoothed)')

pixsmRFele = nx - mod(pixsmRF-1, ny); % higher elevation higher number
pixsmRFazi = 1+ (ceil(pixsmRF/ny)-1); % higher number is more temporal

% figure; imagesc(pixsmRF); colormap jet
%
% figure; imagesc(pixsmRFele); colormap jet
% figure; imagesc(pixsmRFazi); colormap jet


% another round of smoothing?
pixsmRFele = imgaussfilt(pixsmRFele, [yker xker]);
pixsmRFazi = imgaussfilt(pixsmRFazi, [yker xker]);

% figure; imagesc(imgaussfilt(pixsmRF, [yker xker])); colormap jet


% calculate gradient
% d = 25;
% dx = round(d*tifXres*10^-4);
% dy = round(d*tifYres*10^-4);
% [FXele,FYele] = gradient(pixsmRFele, dx);
% [FXazi,FYazi] = gradient(pixsmRFazi, dy);
[FXele,FYele] = gradient(pixsmRFele);
[FXazi,FYazi] = gradient(pixsmRFazi);

% figure; quiver(FXazi,FYazi); title('azimuth gradient')
% set(gca, 'YDir', 'reverse'); axis([900 950 1300 1350])
% 
% figure; quiver(FXele,FYele); title('altitude gradient')
% set(gca, 'YDir', 'reverse'); axis([900 950 1300 1350])


normFXele = FXele./sqrt(FXele.^2+FYele.^2);
normFYele = FYele./sqrt(FXele.^2+FYele.^2);
normFXazi = FXazi./sqrt(FXazi.^2+FYazi.^2);
normFYazi = FYazi./sqrt(FXazi.^2+FYazi.^2);

normFXele(FXele==0 & FYele==0)=0;
normFYele(FXele==0 & FYele==0)=0;
normFXazi(FXazi==0 & FYazi==0)=0;
normFYazi(FXazi==0 & FYazi==0)=0;

k = 100;
% neudia = round(10*mean([tifXres tifYres])*10^-4);
xsm = round(k*tifXres*10^-4);
ysm = round(k*tifYres*10^-4);
smFXele = imgaussfilt(normFXele, [ysm xsm]);
smFYele = imgaussfilt(normFYele, [ysm xsm]);
smFXazi = imgaussfilt(normFXazi, [ysm xsm]);
smFYazi = imgaussfilt(normFYazi, [ysm xsm]);
% 
% figure; quiver(smFXazi,smFYazi); title('azimuth gradient')
% set(gca, 'YDir', 'reverse'); %axis([900 950 1300 1350])
% 
% figure; quiver(smFXele,smFYele); title('altitude gradient')
% set(gca, 'YDir', 'reverse'); %axis([900 950 1300 1350])

[Ftheta_ele, Frho_ele]=cart2pol(smFXele,-smFYele);
[Ftheta_azi, Frho_azi]=cart2pol(smFXazi,-smFYazi);
sinvf = sin(Ftheta_ele-Ftheta_azi);
sinsigma = std(sinvf(:));


% figure; imagesc(Ftheta_azi); colorbar
% figure; imagesc(Ftheta_ele); colorbar

% figure; imagesc(mod(Ftheta_ele-Ftheta_azi, 2*pi)); colorbar

thrfac = 1.5; % 1.5 in Garrett et al
thrsinvf = zeros(size(sinvf));
% thrsinvf(sinvf>thrfac*sinsigma) = 1;
% thrsinvf(sinvf<-thrfac*sinsigma) = -1;
valpix = Frho_ele<thrfac*std(Frho_ele(:)) & Frho_azi<thrfac*std(Frho_azi(:));
thrsinvf(valpix & sinvf>0) = 1;
thrsinvf(valpix & sinvf<0) = -1;


% figure; imagesc(sinvf); colormap jet

% figure; imagesc(thrsinvf); colorbar
% colormap jet

% figure
% jetcm=jet;
% h= imshow((sinvf+1)/2, 'Colormap', jetcm);
% jetcm=jet(128);

maxFOV = squeeze(max(avgbyloc,[],3));
% maxFOVscaled = (maxFOV-min(maxFOV(:)))/range(maxFOV(:));
maxFOVscaled = (maxFOV-min(maxFOV(:)))/(prctile(maxFOV(:), 99)-min(maxFOV(:)));

figure('Position', [100 100 1600 300])
subplot(1,4,1); imagesc(flip(maxFOVscaled,dimflip)); caxis([0 1]) 
% subplot(1,4,1); imagesc(flip(squeeze(max(avgbyloc,[],3)),2)); 
title('FOV')
subplot(1,4,2); imagesc(pixsmRFazi); caxis([1 nx])
title('Azimuth')
subplot(1,4,3); imagesc(pixsmRFele); caxis([1 ny])
title('Altitude')
subplot(1,4,4); imagesc(sinvf); caxis([-1 1])
title('Vis Field Sign')
colormap jet
annotation('textbox', [0.1 0.92 0.9 0.1], 'string', mousedate, 'edgecolor', 'none', 'FontSize', 12, 'interpreter', 'none')

%%
% clearvars each_loc avg_by_loc abl