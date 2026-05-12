%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/extractPSTHsFromROIs.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

%%
mesoholo_setup();

cr = getenv('MESOHOLO_DATA_ROOT');
if isempty(cr)
    r = mesoholo_repo_root();
    r = r(1:end-1);
    corepath = fullfile(r, 'data', 'sessions');
else
    corepath = cr;
end
if ~endsWith(corepath, filesep)
    corepath = [corepath filesep];
end
mouseid = 'MU76_2_aav189'; % name of main mouse folder inside core path
date = '20260503'; % folder with the TIFF data, organized in numbered folders
                   % The numbered folders are in sequence from the
                   % posterio-medial location going left M->L, then one row up P->A
                   % and then right L->M and so on, change as needed
                   % The superficial/vasculature fov tiffs for all fovs are also located directly in this
mousealt = mouseid(1:6); % name of folder with visual stim data ("result")

% Imaging settings
nplanes = 1; %%%%%% IMPORTANT set this
planetouse = 1; %%%%% This TOO
nchannels = 1;
chantouse = 1;
gfrate = 6; % imaging frame rate (i.e., "green frame rate")

retexpt = '000'; % which expt #
root = [corepath,mouseid,'\',date,'\',retexpt,'\'];
retjson = extractjsonparams(root); currjson = retjson;
xpix = retjson.Lx(1); %184,620
xum = retjson.szXY(1,2)*150; %400,620
ypix = retjson.Ly(1); %828,1550
yum = retjson.szXY(1,1)*150; %3600,3100
ntilex = retjson.nrois;
ntilexrsz = ntilex*ntilex/2;
imsize = [ypix,xpix*ntilex];
xppu = round(xpix)/round(xum);
yppu = round(ypix)/round(yum);

gfrate = round(retjson.fs);

%% Overlay roi masks on image
% holofovx = [-800,400];
% holofovy = [300,-900];
% holowest = (holofovx(1)*xppu)+(xpix*ntilex/2);
% holoeast = (holofovx(2)*xppu)+(xpix*ntilex/2);
% holonorth = (holofovy(1)*yppu)+ypix/2;
% holosouth = (holofovy(2)*yppu)+ypix/2;
%
nstrips = ntilex;
masterframe = [];
masterxy = [];
currextdata = extdata_fullfov; %%%% Which makeMasks
for i=1:nstrips
    masterframe = [masterframe,imgData(:,:,i)];
    curroc = currextdata(i).OC;
    if(~isempty(curroc))
        currxy = curroc(:,1:2);
%         currxy = round(currxy*0.5);
        masterxy = [masterxy;[currxy(:,1)+xpix*(i-1),currxy(:,2)]];
    end
end

% masterxy = round(calibratedTargets(:,1:2));
masterxy = duplicateTrimmer(masterxy,calibratedTargets);

%%%% IF sorting by targets AND off-targets
ncells = size(masterxy,1);
nstim = size(calibratedTargets,1);
offrad = 50;
offinds = offTargetIndexer(masterxy,nstim,offrad);
nstimoff = nstim+length(offinds);
targinds = (1:nstim)';
nontarginds = ((nstim+1):ncells)';
nontarginds(ismember(nontarginds,offinds)) = [];
masterxy = masterxy([targinds;offinds;nontarginds],:);
%%%%
[length(targinds),length(offinds),length(nontarginds)]


figure;imagesc(medfilt2(masterframe,[2,2]));hold on
plot(masterxy(:,1),masterxy(:,2),'ro')
title([num2str(size(masterxy,1)),' targets'])
colormap gray
axis square
slideclim([-5,50])
% plot([holowest;holowest],[holonorth;holosouth],'k')
% plot([holowest;holoeast],[holonorth;holonorth],'k')
% plot([holowest;holoeast],[holosouth;holosouth],'k')
% plot([holoeast;holoeast],[holonorth;holosouth],'k')
%%
cellxy = masterxy;
save('cellxy_fullfov_25targs_61offtargs.mat','masterxy','cellxy')
%%
masterframe_day1 = masterframe; masterxy_day1 = masterxy;
%%
masterframe_day2 = masterframe; masterxy_day2 = masterxy;
%%
nrois = size(masterxy,1);
% nrois = 1342;
roimasks = zeros(size(masterframe,1),size(masterframe,2),nrois,'uint8');
npilmasks = zeros(size(masterframe,1),size(masterframe,2),nrois,'uint8');
radius = 7; %9 or 7
filtsz = [radius*2*yppu radius*2*xppu];
SE = makeroistrel(filtsz);
% SE=strel('disk',radius,4);
npexcl = 3; %3 or 3
npmult = 3; %2 or 3
npilradius = radius*npmult+npexcl;
filtsz = [npilradius*2*yppu npilradius*2*xppu];
SEnpil = makeroistrel(filtsz);
% SEnpil=strel('disk',npilradius,4);
npilradius2 = radius+npexcl;
filtsz = [npilradius2*2*yppu npilradius2*2*xppu];
SEnpil2 = makeroistrel(filtsz);
fprintf('Masking ROI ')
iroioff = 0;
for i=1:nrois
    iroi = i+iroioff;
%     plot(masterxy(iroi,1),masterxy(iroi,2),'ro')
    fprintf('%d ',i)
    if(~mod(i,30))
        fprintf('\n')
    end
    npilmasks2 = zeros(size(masterframe,1),size(masterframe,2),'uint8');

    roimasks(masterxy(iroi,2),masterxy(iroi,1),i) = 1;
    roimasks(:,:,i) = uint8(imdilate(logical(roimasks(:,:,i)),SE));
    npilmasks2(masterxy(iroi,2),masterxy(iroi,1)) = 1;
    npilmasks2 = uint8(imdilate(logical(npilmasks2),SEnpil2));
    npilmasks(masterxy(iroi,2),masterxy(iroi,1),i) = 1;
    npilmasks(:,:,i) = uint8(imdilate(logical(npilmasks(:,:,i)),SEnpil));
    npilmasks(:,:,i) = npilmasks(:,:,i)-npilmasks2;
end
fprintf('\n')
nroipix = sum(sum(roimasks(:,:,1)~=0,1),2);
nnpilpix = sum(sum(npilmasks(:,:,1)~=0,1),2);
disp(['Roi pix = ',num2str(sum(nroipix)),', Npil pix = ',num2str(sum(nnpilpix))])
%%
figure;hfov = imagesc(medfilt2(masterframe,[2,2]));hold on
slideclim([-5,50]);
% set(gca,'clim',[0 15])
colormap gray
axis square
% plot([holowest;holowest],[holonorth;holosouth],'k')
% plot([holowest;holoeast],[holonorth;holonorth],'k')
% plot([holowest;holoeast],[holosouth;holosouth],'k')
% plot([holoeast;holoeast],[holonorth;holosouth],'k')
temp0 = ones(size(masterframe));
temp1 = sum(roimasks,3);
temp2 = sum(npilmasks,3);
set(hfov,'AlphaData',(temp0*0.67+temp1*0.33+temp2*0.18))
%% Extract PSTHs
exptid = '102';
root = [corepath,mouseid,'\',date,'\',exptid,'\'];
savepath = [corepath,mouseid,'\',date,'\',mousealt,'\psths_',exptid,'_r',...
    num2str(radius),'_np',num2str(npmult),'x+ann',num2str(npexcl),'.mat'];
savepathgfr = [corepath,mouseid,'\',date,'\',mousealt,'\allgframes_',exptid,'.mat'];

% nchannels = 1;
fs = dir(fullfile(root, '*vis*.tif'));
[~,minfsind] = min([fs.bytes]);
fname = fs(minfsind).name;
fname = fullfile(root, fname);
header = imfinfo(fname);
nframes = length(header);
tlength = floor(nframes/(nchannels*nplanes));

nfiles = length(fs);
psths = zeros(nrois,tlength,nfiles);
psthsnp = zeros(nrois,tlength,nfiles);
allgframes = cell(nfiles,1);
for n=1:nfiles
    tic
    fname = fs(n).name;
    fname = fullfile(root, fname);
    header = imfinfo(fname);
    nframes = length(header);
    gframes = zeros([imsize,round(nframes/(nchannels*nplanes))]);
    gframes5 = zeros(ceil(ypix/4),ceil(xpix*5/8),size(gframes,3));
    ct = 0;
    for i=nchannels*(planetouse-1)+chantouse:nchannels*nplanes:nframes
        ct = ct+1;
        temp = imread(fname,i);
        newframe = zeros(imsize);
        framec = imsize/2;
        for k=1:ntilex
            currjson = retjson;
            currxpix = xpix;
            currypix = ypix;
            currxyc = currjson.cXY(k,:)*150;%currxyc(1)=0;
            currsz = currjson.szXY(k,:)*150;
            currirow = currjson.irow(:,k);
            
            currxlim = [(k-1)*currxpix + 1 ,(k-1)*currxpix + currxpix];
            currylim = [1,currypix];
            newframe(currylim(1):currylim(2),currxlim(1):currxlim(2)) = ...
                imresize(temp(currirow(1)+1:currirow(2),:),...
                [length(currylim(1):currylim(2)),length(currxlim(1):currxlim(2))]);
        end
        gframes(:,:,ct) = newframe;
%         gframes5(:,:,ct) = imresize(newframe,[ceil(ypix/4),ceil(xpix*5/8)]);
    end
%     allgframes{n} = int16(gframes5(:,:,1:tlength));
%     allgframes{n} = single(gframes(holosouth:holonorth,holowest:holoeast,:));
%     allgframes{n} = single(gframes(601:1000,1201:2000,:));
    
    for i=1:nrois
        iroi = i+iroioff;
        currwinx = masterxy(iroi,1)+(-(radius+1):(radius+1));
        currwiny = masterxy(iroi,2)+(-(radius+1):(radius+1));
        currpsth = gframes(currwiny,currwinx,1:tlength).*...
            repmat(double(roimasks(currwiny,currwinx,i)),[1,1,tlength]);
        currpsth = squeeze(sum(sum(currpsth,1),2))/nroipix;
        
        currnpx = masterxy(iroi,1)+(-(npilradius+1):(npilradius+1));
        currnpy = masterxy(iroi,2)+(-(npilradius+1):(npilradius+1));
        currnpil = gframes(currnpy,currnpx,1:tlength).*...
            repmat(double(npilmasks(currnpy,currnpx,i)),[1,1,tlength]);
        currnpil = squeeze(sum(sum(currnpil,1),2))/nnpilpix;
        
        psths(i,:,n) = currpsth(1:tlength);
        psthsnp(i,:,n) = currnpil(1:tlength);
    end
        
    disp(['Trial ',num2str(n),' tlength ',num2str(tlength)])
    toc
end
save(savepath,'psths','psthsnp')
% save(savepathgfr,'allgframes','-v7.3')

%% Find stim target inds among all cells
masterxy_full = masterxy;
%%
masterxy_holofov = masterxy;
%%
srcinds = find(ismember(masterxy_full,masterxy_holofov,'rows'));
nsrcinds = find(~ismember(masterxy_full,masterxy_holofov,'rows'));
masterxy_src = masterxy_full(srcinds,:);
srcnsrcinds = find(~ismember(masterxy_holofov,masterxy_src,'rows'));
allvalmat(srcnsrcinds,:) = [];

%% Assign cellvareas
retxpix = xpix;
retypix = ypix;
varealist = {'v1','am','pm','mma','mmp','rl','lm','al','rll','lla','li','p','a','rsc','notv1'};
nareas = length(varealist);
vareaind = 1:nareas;
areapix = cell(nareas,1);
masterxy_touse = masterxy_full;
nallcells = size(masterxy_touse,1);
cellvarea = zeros(nallcells,1);
cellxy = masterxy_touse(:,2:-1:1);
for i=1:nareas
    if(isfield(varea,varealist{i}))
        [temp1,temp2] = find(varea.(varealist{i}));
        areapix{i} = [temp1,temp2];
        currind = ismember(round([(retypix-cellxy(:,1))/4,...
            (retxpix*ntilex-(retxpix*ntilex-cellxy(:,2)))/8]),areapix{i},'rows');
%         currind = ismember(round([cellxy(:,1)/4,(1656-cellxy(:,2))/8]),areapix{i},'rows'); % Old
        currind(cellvarea>0) = 0;
        cellvarea(currind) = vareaind(i);
    end
end
%%% Plot all areas individually by colour
temp1 = varealist;
temp2 = zeros(ceil(retypix/4),ceil(retxpix*ntilex/8));% [207,207] or [388,388]
% temp2 = zeros(207,207);
newimsize = size(temp2);
for i=1:nareas
    if(isfield(varea,varealist{i}))
        temp2 = temp2+varea.(temp1{i})*i;
        temp2(temp2>i) = 0;
    end
end
hfig000 = figure;
% subplot(1,2,2)
imagesc(temp2)
vareamask = temp2;
for i=1:nareas
    if(isfield(varea,varealist{i}))
        [areaxpix,areaypix] = find(varea.(temp1{i}));
        text(median(areaypix),median(areaxpix),temp1{i},...
            'HorizontalAlignment','center')
    end
end
% set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
% set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
xlabel('L --> M (um)')
ylabel('P --> A (um)')

axis square

%%%% Plot all points corresponding to a given area
hold on
areainds = [1:nareas];
plotcellinds = [];
plotcellxy = [];
for areaind = areainds
    areacellinds = find(cellvarea==areaind);
    areacellxy = cellxy(areacellinds,:);
    plotcellinds = [plotcellinds;areacellinds];
    plotcellxy = [plotcellxy;areacellxy];
end
plot(plotcellxy(:,2)/8,(retypix-plotcellxy(:,1))/4,'r.')
plot(cellxy(1:30,2)/8,(retypix-cellxy(1:30,1))/4,'ko')

%% prepPSTHsForSubspace
% Preprocess matrices for comm subspace analysis
%%%%%%%%% For local v1 fov data
nuoris = 1;
nallcells = size(psths,1);
tlength = size(psths,2);
ntrials = size(psths,3);
cellprob = logical(ones(nallcells,1));
osis = ones(nallcells,1);
% cellvarea = zeros(nallcells,1);
% cellvarea(:,1) = 1;
% cellvarea(:,1) = 2;
cellvarea(srcinds,1) = 1;
cellvarea(cellvarea==1 & ~ismember((1:length(cellvarea))',srcinds),1) = 99;
% vareaind = 1;
% varealist = {'v1','notv1'};
%%%%%%%%%

newpsths = psths-0.7*psthsnp;
psthmat = reshape(newpsths,[nallcells,tlength*ntrials]);
dF0 = median(psthmat,2);
oriDFF = cell(nuoris,1);
for i=1:300
    tempdf = newpsths(:,:,i);
    tempdff = (tempdf-repmat(dF0,[1 tlength]))./repmat(dF0,[1 tlength]);
    tempdff = (tempdff-repmat(mean(tempdff(:,1:5),2),[1 tlength]));
    oriDFF{1,1}(:,:,i) = tempdff;
end

sigma = 1;
f = -100:100;
gaussf = (1/(sigma*sqrt(2*pi)))*exp((-f.^2)/(2*sigma^2));
gaussf = gaussf/sum(gaussf);

szind = 1;

orisignal = oriDFF;
nuoris = length(orisignal);
% First upsample and smooth
orisignalhi = cell(nuoris,1);
nupsamp = 1;
nallcells = size(orisignal{1,szind},1);
tlength = size(orisignal{1,szind},2);
for i=1:nuoris
    orintrials = size(orisignal{i,szind},3);
    orisignalhi{i} = zeros(size(orisignal{i,szind},1),...
        size(orisignal{i,szind},2)*nupsamp,orintrials);
    
    temporisignal = shiftdim(double(orisignal{i,szind}),1);

    totlength = tlength*orintrials*nallcells;
    temporisignalhi = interp1(1:totlength,temporisignal(:),1:(1/nupsamp):totlength+1-(1/nupsamp));
%     temporisignalhi = zscore(temporisignalhi);
    temporisignalhi = conv(temporisignalhi,gaussf,'same');
    
    orisignalhi{i} = reshape(temporisignalhi,[nupsamp*tlength,orintrials,nallcells]);
    orisignalhi{i} = shiftdim(orisignalhi{i},2);
%     orisignalhi{i} = mean(orisignalhi{i}(:,6:end,:),2); %upsamp 1
%     orisignalhi{i} = mean(orisignalhi{i}(:,14:end,:),2); %upsamp 3
    i
end

resorisig = orisignalhi;

resorisig = cell(nuoris,1);
% temp = randperm(nallcells);
% tempcellinds = temp(1:6000);
% cellvarea = cellvarea(tempcellinds);
% osis = osis(tempcellinds);
for i=1:nuoris
    orintrials = size(orisignalhi{i},3);
    resorisig{i} = orisignalhi{i}-repmat(mean(orisignalhi{i},3),[1,1,orintrials]);
%     temp = randperm(240);
%     resorisig{i} = resorisig{i}(:,:,temp(1:240));
%     resorisig{i} = resorisig{i}(tempcellinds,:,temp(1:240));
end

%%
loc = MesoLocFile_SI();
holoRequest = holoRequests;

subtouse = abs(rectsub);
% fullsubtouse = zeros(size(psths,1),1);
fullsubtouse = zeros(size(holoRequest.targets,1),1);
fullsubtouse(srcinds) = subtouse;
%%
% fullsubtouse = [linspace(0.125,1,17),linspace(1,0.125,17)]';

powscales = [1,8];
nscales = length(powscales);
%%%%%%%% Base sub (not used)
subinds = find(fullsubtouse);
desiredvec = fullsubtouse(subinds)/mean(fullsubtouse(subinds));
desiredvec = desiredvec*mean(sum(allvalmat(subinds,:),1))/sum(desiredvec);
[~,p0inds] = min(abs(allvalmat(subinds,:)-desiredvec),[],2);
p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
p0 = [];
for i=1:length(p0inds)
    p0 = [p0;allpows(p0inds(i))];
end
basetargs = holoRequest.targets(subinds,:);
baseactualtargs = holoRequest.actualtargets(subinds,:);
basesub = desiredvec;
baseweights = p0;
basegroupID = ones(length(subinds),1);
holoRequest.targets = [];
holoRequest.actualtargets = [];
holoRequest.sub = [];
holoRequest.roiWeights = [];
holoRequest.groupID = [];

%%%%%%%% Actual sub
desiredvec = fullsubtouse(subinds)/mean(fullsubtouse(subinds));
for k=1:length(powscales)
    powscale = powscales(k);
    desiredvec = powscale*desiredvec*mean(sum(allvalmat(subinds,:),1))/sum(desiredvec);
    [~,p0inds] = min(abs(allvalmat(subinds,:)-desiredvec),[],2);
    disp(['Actual sub powscale ',num2str(powscale),...
        ' Satpow for ',num2str(sum(p0inds==length(allpows))),' targs'])
    p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
    p0 = [];
    for i=1:length(p0inds)
        p0 = [p0;allpows(p0inds(i))];
    end
    holoRequest.targets = [holoRequest.targets;basetargs];
    holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
    holoRequest.sub = [holoRequest.sub;desiredvec];
    holoRequest.roiWeights = [holoRequest.roiWeights;p0];
    lastgroup = max(unique(holoRequest.groupID));
    if(isempty(lastgroup));lastgroup=0;end
    holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];
end
%%%%%%%% naive actual sub
% desiredvec = fullsubtouse(subinds)/sum(fullsubtouse(subinds));
% holoRequest.targets = [holoRequest.targets;basetargs];
% holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
% holoRequest.sub = [holoRequest.sub;desiredvec];
% holoRequest.roiWeights = [holoRequest.roiWeights;desiredvec];
% lastgroup = max(unique(holoRequest.groupID));
% if(isempty(lastgroup));lastgroup=0;end
% holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];

%%%%%%%% Randomize
nrand = 1;
for n=1:nrand
    desiredvec = basesub(randperm(length(subinds)));
    for k=1:length(powscales)
        powscale = powscales(k);
        desiredvec = powscale*desiredvec*mean(sum(allvalmat(subinds,:),1))/sum(desiredvec);
        [~,p0inds] = min(abs(allvalmat(subinds,:)-desiredvec),[],2);
        disp(['Rand sub powscale ',num2str(powscale),...
            ' Satpow for ',num2str(sum(p0inds==length(allpows))),' targs'])
        p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
        p0 = [];
        for i=1:length(p0inds)
            p0 = [p0;allpows(p0inds(i))];
        end
        holoRequest.targets = [holoRequest.targets;basetargs];
        holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
        holoRequest.sub = [holoRequest.sub;desiredvec];
        holoRequest.roiWeights = [holoRequest.roiWeights;p0];
        lastgroup = max(unique(holoRequest.groupID));
        if(isempty(lastgroup));lastgroup=0;end
        holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];
    end
end
%%%%%%%%

%%%%%%%% Invert
desiredvec = fullsubtouse(subinds)/sum(fullsubtouse(subinds));
[~,temp] = sort(desiredvec,'descend');
[~,temp2] = sort(desiredvec,'ascend');
invsub = desiredvec;
invsub(temp) = desiredvec(temp2);
desiredvec = invsub;
for k=1:length(powscales)
    powscale = powscales(k);
    desiredvec = powscale*desiredvec*mean(sum(allvalmat(subinds,:),1))/sum(desiredvec);
    [~,p0inds] = min(abs(allvalmat(subinds,:)-desiredvec),[],2);
    disp(['Inv sub powscale ',num2str(powscale),...
        ' Satpow for ',num2str(sum(p0inds==length(allpows))),' targs'])
    p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
    p0 = [];
    for i=1:length(p0inds)
        p0 = [p0;allpows(p0inds(i))];
    end
    holoRequest.targets = [holoRequest.targets;basetargs];
    holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
    holoRequest.sub = [holoRequest.sub;desiredvec];
    holoRequest.roiWeights = [holoRequest.roiWeights;p0];
    lastgroup = max(unique(holoRequest.groupID));
    if(isempty(lastgroup));lastgroup=0;end
    holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];
end
%%%%%%%% naive inv sub
% desiredvec = invsub;
% holoRequest.targets = [holoRequest.targets;basetargs];
% holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
% holoRequest.sub = [holoRequest.sub;desiredvec];
% holoRequest.roiWeights = [holoRequest.roiWeights;desiredvec];
% lastgroup = max(unique(holoRequest.groupID));
% if(isempty(lastgroup));lastgroup=0;end
% holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];

%%%%%%%% 111ize
desiredvec = ones(length(subinds),1);
p0111 = [];
for k=1:length(powscales)
    powscale = powscales(k);
    desiredvec = powscale*desiredvec*mean(sum(allvalmat(subinds,:),1))/sum(desiredvec);
    [~,p0inds] = min(abs(allvalmat(subinds,:)-desiredvec),[],2);
    disp(['111 sub powscale ',num2str(powscale),...
        ' Satpow for ',num2str(sum(p0inds==length(allpows))),' targs'])
    p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
    p0 = [];
    for i=1:length(p0inds)
        p0 = [p0;allpows(p0inds(i))];
    end
    p0111 = [p0111,p0];
    holoRequest.targets = [holoRequest.targets;basetargs];
    holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
    holoRequest.sub = [holoRequest.sub;desiredvec];
    holoRequest.roiWeights = [holoRequest.roiWeights;p0];
    lastgroup = max(unique(holoRequest.groupID));
    if(isempty(lastgroup));lastgroup=0;end
    holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];
end
%%%%%%%%

%%%%%%%% naive 111
% desiredvec = ones(length(subinds),1);
% for k=1:length(powscales)
%     powscale = powscales(k);
%     desiredvec = powscale*desiredvec*mean(sum(allvalmat(subinds,:),1))/sum(desiredvec);
%     p0 = desiredvec*sum(p0111(:,k))/sum(desiredvec);
%     holoRequest.targets = [holoRequest.targets;basetargs];
%     holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
%     holoRequest.sub = [holoRequest.sub;desiredvec];
%     holoRequest.roiWeights = [holoRequest.roiWeights;p0];
%     lastgroup = max(unique(holoRequest.groupID));
%     if(isempty(lastgroup));lastgroup=0;end
%     holoRequest.groupID = [holoRequest.groupID;(lastgroup+1)*basegroupID];
% end
%%%%%%%%

%%%%%%%% orthoize
% holoRequest.targets = [holoRequest.targets;basetargs];
% holoRequest.actualtargets = [holoRequest.actualtargets;baseactualtargs];
% holoRequest.groupID = [holoRequest.groupID;basegroupID+nrand+1+1+1+1];
% %%%%
% desiredvec = basesub'*basesub*ones(length(subinds),1) - ...
%     ones(length(subinds),1)'*basesub*basesub;
% desiredvec = desiredvec*0.5*mean(sum(allvalmat,1))/sum(desiredvec);
% [~,p0inds] = min(abs(allvalmat-desiredvec),[],2);
% p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
% p0 = [];
% for i=1:length(p0inds)
%     p0 = [p0;allpows(p0inds(i))];
% end
% holoRequest.roiWeights = [holoRequest.roiWeights;p0];
% holoRequest.sub = [holoRequest.sub;desiredvec];
%%%%

holoRequest.otargets = basetargs;
holoRequest.oroiWeights = reshape(holoRequest.roiWeights,...
    [size(basetargs,1),size(holoRequest.roiWeights,1)/size(basetargs,1)])';
holoRequest.sub = reshape(holoRequest.sub,...
    [size(basetargs,1),size(holoRequest.sub,1)/size(basetargs,1)])';
sum(holoRequest.sub,2)
sum(holoRequest.oroiWeights,2)

try
    save([loc.HoloRequest_SI 'holoRequest.mat'],'holoRequest');
    save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');
catch
    disp('****WARNING: HOLOREQUEST SAVE ERROR!!! Find another way...****')
end

%%
save('summary_18to10_v1-v1other_iterind45.mat','summary','randv1inds','randv2inds','osiinds',...
    'v2areainds','cellvarea','osis','cellprob','currresorisig','iterind',...
    'itopn','-v7.3')

%% Analyze stimmability
% Load masterxy from extdata_holofov (not stimmable)
targinds = 1:size(masterxy,1);

sigma = 0.75;
f = -100:100;
gaussf = (1/(sigma*sqrt(2*pi)))*exp((-f.^2)/(2*sigma^2));
gaussf = gaussf/sum(gaussf);

newpsths = psths-0.7*psthsnp;
% newpsths(:,5:6,:) = NaN;
f0 = nanmean(nanmean(nanmean(newpsths(targinds',:,ExpStruct.trialCond==1),3),1));
% f0 = nanmean(nanmean(newpsths(:,:,ExpStruct.trialCond==1),3),2);

newpsths2 = newpsths;
for i=1:size(newpsths,3)
    for j=1:size(newpsths,1)
        currpsth = newpsths(j,:,i);
        currpsth = (currpsth-f0)/f0;
        currpsth = nanconv(currpsth,gaussf,'same');
        newpsths2(j,:,i) = currpsth;
    end
end
usepsths = newpsths2;

stimcond = 4;
tempstim = nanmean(usepsths(targinds',:,ExpStruct.trialCond==stimcond),3);
fstim = [];
for i=1:length(targinds)
    try
        currstimtime = ceil(ExpStruct.outParams.firstStimTimes{stimcond}(i)*gfrate);
    catch
        currstimtime = 6;
    end
    if(currstimtime<=5)
        fstim = [fstim;padarray(tempstim(i,1:currstimtime+10),[0 5-currstimtime+1],NaN,'pre')];
    elseif(currstimtime+10>size(tempstim,2))
        fstim = [fstim;padarray(tempstim(i,currstimtime-5:end),size(tempstim,2)-currstimtime,NaN,'post')];
    else
        fstim = [fstim;tempstim(i,currstimtime+(-5:10))];
    end
end
fstim = fstim-repmat(nanmean(fstim(:,1:5),2),[1,size(fstim,2)]);
figure;
subplot(1,2,1)
imagesc(fstim)
subplot(1,2,2)
plot(fstim(mean(fstim(:,5:10),2)<=2*nanmedian(fstim(:)),:)','col',[0.5 0.5 0.5])
hold on
plot(fstim(mean(fstim(:,5:10),2)>2*nanmedian(fstim(:)),:)')
hold on
stimmableinds = mean(fstim(:,5:10),2)>2*nanmedian(fstim(:));
nstimmable = sum(stimmableinds)

%% Adhoc
% goodinds = [2,3,10,11,16,18,31,35,48];
goodinds = goodcells;
% goodinds = goodinds(stiminds);
xynew_holo = xynew(~ismember(1:size(xynew,1),outinds),:);
stimmableinds = ismember(1:size(xynew_holo,1),goodinds);

%% Trim holoRequests and makemasks based on only stimmable cells
xynew_holo = xynew(~ismember(1:size(xynew,1),outinds),:);
% outinds = find(sum(xynew,2)==2);
% xynew_holo(outinds,:) = [];
for i=1:size(xynew_holo,1)
    if(~stimmableinds(i))
        xynew_holo(i,:) = [1,1];
    end
end    
outinds = find(sum(xynew_holo,2)==2);

holoRequests = saveAllToHoloRequest(xynew_holo,yoffset,xoffset,xrotate,yrotate,zMap,hSI); % y,x offsets (-4, -2.8)

%% IF YOU WANT TO LOAD ORIGINAL Integration Rois, set outinds to empty
xynew = xynew(~ismember(1:size(xynew,1),outinds),:);
outinds = [];

%%
hSI.hIntegrationRoiManager.roiGroup.clear()
number= 0;
innumber = 0;
outnumber = 0;
insources = cell(1,nstrips);
inextdata = extdata_holofov;
stripnumbers_holofov = 0;
for n = 1:nstrips
    currsf = hSI.hRoiManager.currentRoiGroup.rois(n).scanfields(1);
    imagingScanfield = currsf;
    
    inextdata(n).OC = [];
    theSources=sources_holofov{n};
    currsize = size(theSources,3);
    if(isempty(theSources))
        currsize = 0;
    end
    stripnumbers_holofov = [stripnumbers_holofov,currsize];
    cumstripnumbers_holofov = cumsum(stripnumbers_holofov);
    
    for k = 1:currsize
        number=number+1;
        mask = theSources(:,:,k);
        intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
        intsf.threshold = 100;
        introi = scanimage.mroi.Roi();
        introi.discretePlaneMode=1;
        introi.add(Zplanes(planetouse), intsf);
        introi.name = ['ROI ' num2str(number+1) ];%' Depth ' num2str(zDepth(n))];
        if(~ismember(number,outinds))
            hSI.hIntegrationRoiManager.roiGroup.add(introi);
            innumber = innumber + 1;
            insources{n} = cat(3,insources{n},mask);
            currstriproinumber = number-cumstripnumbers_holofov(n);
            inextdata(n).OC = [inextdata(n).OC;extdata_holofov(n).OC(currstriproinumber,:)];
        else
            outnumber = outnumber+1;
        end
        
    end
end
sources_stimmable = insources;
extdata_stimmable = inextdata;
disp(['Removed ' num2str(outnumber) ' and retained ' num2str(innumber) ' sources to integration']);

selectAllROIs;
% save([hSI.hScan2D.logFilePath '/makeMasks3D_img_stimmable'],'img', 'imgData','sources_stimmable','extdata_stimmable','goodcells','-v7.3');
save([hSI.hScan2D.logFilePath '/makeMasks3D_img_goodcells'],'img', 'imgData','sources_stimmable','extdata_stimmable','goodcells','-v7.3');

% sources_holofov = insources;
% extdata_holofov = inextdata;
% save([hSI.hScan2D.logFilePath '/makeMasks3D_img_holofov_day1'],'img', 'imgData','sources_holofov','extdata_holofov','Opts','-v7.3');

disp('sent ROIs to the cloud');

%%
temp = psths-0.0*psthsnp;
visinds = find(result.contrasts_by_trial);
notvisinds = find(~result.contrasts_by_trial);
temp = temp-mean(temp(:,2:5,:),2);
temp = temp(goodcells,:,:);
[visvec,pkinds] = max(mean(temp(:,7:12,visinds),3),[],2);
figure;
plot(mean(temp(:,:,visinds),3)')
hold on
plot(pkinds+6,visvec,'ro')
% plot(mean(temp(:,:,notvisinds),3)','k')