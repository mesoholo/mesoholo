function jsonparams = extractjsonparams(root)

fs = dir(fullfile(root, '*.tif'));

fname = fs(1).name;
fname = fullfile(root, fname);
header = imfinfo(fname);
stack = loadFramesBuff(fname,1,1,1);
try
    fs = hSI.hRoiManager.scanVolumeRate;
catch
    fs = 4;
end
artist_info     = header(1).Artist;
artist_info = artist_info(1:find(artist_info == '}', 1, 'last'));
artist = jsondecode(artist_info);
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
if(nplanes==0)
    nplanes=1;
end

si_rois = artist.RoiGroups.imagingRoiGroup.rois;
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
% cXY = cXY - szXY/2;
% cXY = cXY - min(cXY, [], 1);
mu = median([Ly, Lx]./szXY, 1);
imin = cXY .* mu;
n_rows_sum = sum(Ly);
n_flyback = (size(stack, 1) - n_rows_sum) / max(1, (nrois - 1));
irow = [0 cumsum(Ly'+n_flyback)];
irow(end) = [];
irow(2,:) = irow(1,:) + Ly';

jsonparams.fs = fs;
jsonparams.nplanes = nplanes;
jsonparams.nrois = nrois;
jsonparams.Lx = Lx;
jsonparams.Ly = Ly;
jsonparams.cXY = cXY;
jsonparams.szXY = szXY;
jsonparams.irow = irow;