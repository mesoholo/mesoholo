%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/FitPowerCurveAndWeight_F.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

%% If reloading PSTHs
tempPath = getenv('MESOHOLO_PSTH_CACHE');
if isempty(tempPath)
    r = mesoholo_repo_root();
    r = r(1:end-1);
    tempPath = fullfile(r, 'data', 'sessions', 'MU76_2_aav189', '20260414', '004', ...
        'MU76_2_stimtest_depth220_3.1x3.1_z0_g3Hz_pow48_89targs_1x100ms@105ipi_PSTHs.mat');
end
temp = load(tempPath);
PSTHs = temp.out.PSTHs;
powers = temp.out.powers;

%% Shaped weighting by stimmability threshold
ncells = size(PSTHs,2);
upows = unique(powers);
npows = length(upows);
gfrate = round(3); %% IMP SET This!!
preframes = 2*gfrate;
postframes = 3*gfrate;
allcurrpsths = zeros(npows,ncells,size(PSTHs,3));
allcurrFs = zeros(npows,ncells);
alltrialFs = zeros(npows,ncells,ceil(size(PSTHs,1)/npows)-2);

for p=1:npows
    for n=1:ncells
        currpow = upows(p);
        powinds = powers==currpow;
        currpsths = squeeze(PSTHs(powinds,n,:));
        currbases = repmat(nanmean(currpsths(:,1:preframes),2),[1,size(PSTHs,3)]);
        currpsths = (currpsths-currbases);
        [~,minind] = min(max(currpsths(:,preframes+1:end),[],2));
        [~,maxind] = max(max(currpsths(:,preframes+1:end),[],2));
        currpsths([minind;maxind],:) = [];
        allcurrpsths(p,n,:) = mean(currpsths,1);
        allcurrFs(p,n) = max(allcurrpsths(p,n,preframes+1:end),[],3);        
    end
end

%%
plotflag = 1;
if(plotflag)
    figure;
end
goodcells = [];
goodpows = [];
badcells = [];
satthresh = 0.9; %0.95 chrmine 0.8 ai203 proportion of highest response (y-axis)
satcutoff = 0.67; % 0.6 chrmine 0.75 ai203 fraction of highest power (x-axis)
hillb1cutoff = 0.75; % 0.5 ai203, was 2.25 before
hill_fit = @(b,x) b(1)./(1+(b(2)./x).^b(3));
opts = optimoptions('lsqcurvefit');
opts.FunctionTolerance = 1E-12;
opts.OptimalityTolerance = 1E-12;
opts.StepTolerance = 1E-12;
opts.MaxIterations = 1000;
opts.Display = 'off';
allpowmat = [];
allvalmat = [];
hillbs = [];
satpows = [];
satinds = [];
for n=1:ncells
    
    temp2 = allcurrFs(:,n)';
    temp2 = temp2-temp2(1);
    b0 = [max(temp2),max(upows)/2,6];
    [hillb,~,~,eflag] = lsqcurvefit(hill_fit,b0,upows,temp2,[-10;0;4],[50;1;8],opts);
    hillbs = [hillbs;hillb];
    
    allpows = 0:0.001:max(upows);
    allvals = hill_fit(hillb,allpows);
    [~,satind] = min(abs(allvals-satthresh*hillb(1)));
    satpow = allpows(satind);
    if(satpow > satcutoff*max(upows) | hillb(1)<hillb1cutoff)
        satpow = 0;
        satind = 0;
    end
    satpows = [satpows;satpow];
    satinds = [satinds;satind];
    allpowmat = [allpowmat;allpows];
    allvalmat = [allvalmat;allvals];
    goodcells = [goodcells;n];
    
    if(plotflag & satpow~=0)
        subplot(1,2,1)
        plot(allpows,allvals,'k') %%commentout
        hold on %%commentout
        plot(upows,temp2,'ko') %%commentout
        plot(satpow,allvals(satind),'ro')     
    end

    if(plotflag)
%         hold off %%commentout
%         set(gca,'xlim',[-0.1 0.41],'ylim',[0 1]) %%commentout
        pause(0.01) %%commentout
    end
end
ylim = get(gca,'ylim');
xlabel('Requested power (W)')
ylabel('Response (a.u.)')
title('All cells')
%

% triminds = satpows<0.002 | max(allvalmat,[],2)<2.5 | max(allvalmat,[],2)>20; % w/out vis
% triminds = satpows<0.004 | max(allvalmat,[],2)<1 | max(allvalmat,[],2)>10 | (pkinds<3); % w/vis
triminds = satpows<0.008 | max(allvalmat,[],2)<5 | max(allvalmat,[],2)>50; % ppsf
goodcells(triminds)=[];
satpows(triminds)=[];
satinds(triminds)=[];
allvalmat = allvalmat(~triminds,:);
allpowmat = allpowmat(~triminds,:);

disp([num2str(length(goodcells)),' good cells, Fmax 5% cutoff = ',...
    num2str(quantile(hillbs(:,1),0.05))])
colmap = jet(length(goodcells));
subplot(1,2,2)
for i=1:size(allpowmat,1)
plot(allpowmat(i,:),allvalmat(i,:),'col',colmap(i,:)) %%commentout
hold on %%commentout
plot(satpows(i),allvalmat(i,satinds(i)),'ro') %%commentout
end
set(gca,'ylim',ylim)
xlabel('Requested power (W)')
ylabel('Response (a.u.)')
title('Filtered cells')

nallpows = size(allvalmat,2);
allvalmatperm = zeros(size(allvalmat,1),nallpows*10000);
for i=1:10000
    temp = allvalmat;
    for j=1:size(temp,1)
        temp(j,:) = temp(j,randperm(nallpows));
    end
    allvalmatperm(:,(i-1)*nallpows+1:i*nallpows) = temp;
end

powcurve.goodcells = goodcells;
powcurve.satpows = satpows;
powcurve.satinds = satinds;
powcurve.allvalmat = allvalmat;
powcurve.allpowmat = allpowmat;
powcurve.allpows = allpows;
powcurve.satthresh = satthresh;
powcurve.satcutoff = satcutoff;

%%
hill_fits = @(b,pvec) b(:,1)./(1+(b(:,2)./pvec).^b(:,3));

desiredvec = ones(ncells,1);
desiredvec = desiredvec/mean(desiredvec);

desiredvec = desiredvec*0.5*mean(sum(allvalmat,1))/sum(desiredvec);
desiredvec = desiredvec*1;

[~,p0inds] = min(abs(allvalmat-desiredvec),[],2);
p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
p0 = [];
for i=1:length(p0inds)
    p0 = [p0;allpows(p0inds(i))];
end
[desiredvec,hill_fits(hillbs,p0)]
sum(p0)
%%
figure;
desiredvec = desiredvec*mean(sum(allvalmat,1))/sum(desiredvec);
desiredvec = desiredvec*0.5;

subplot(2,1,1)
plot(sum(abs(allvalmatperm-desiredvec),1),'ko')
subplot(2,1,2)
temp = allvalmatperm./repmat(sqrt(sum(allvalmatperm.^2,1)),[12,1]);
temp2 = desiredvec/norm(desiredvec,2);
plot(temp'*temp2,'ro')

[~,minind1] = min(sum(abs(allvalmatperm-desiredvec),1));
[~,maxind2] = max(temp'*temp2);
[~,minmaxind] = min(sum(abs(allvalmatperm-desiredvec),1)'.*(1-(temp'*temp2)));
[desiredvec,allvalmatperm(:,minind1),allvalmatperm(:,maxind2),allvalmatperm(:,minmaxind)]

%%
hill_fits = @(b,pvec) b(:,1)./(1+(b(:,2)./pvec).^b(:,3));
objmin = @(p) sum(abs(hill_fits(hillbs,p)-desiredvec));
opts = optimoptions('simulannealbnd');
opts.AnnealingFcn = @annealingboltz;
[~,p0inds] = min(abs(allvalmat-desiredvec),[],2);
p0 = [];
for i=1:length(p0inds)
    p0 = [p0;allpows(p0inds(i))];
end
ptemp = simulannealbnd(objmin,p0,0*ones(12,1),0.4*ones(12,1),opts);
[desiredvec,hill_fits(hillbs,p0),hill_fits(hillbs,ptemp)]

%% Flat weighting with min power cutoff
ncells = size(PSTHs,2);
upows = unique(powers);
npows = length(upows);
preframes = 2*gfrate;
postframes = 3*gfrate;
allcurrpsths = zeros(npows,ncells,size(PSTHs,3));

sigalpha = 0.05;
for p=1:npows
    for n=1:ncells
        currpow = upows(p);
        powinds = powers==currpow;
        currpsths = nanmean(squeeze(PSTHs(powinds,n,:)),1);
        currpsths = (currpsths-mean(currpsths(1:preframes)))/mean(currpsths(1:preframes));
        allcurrpsths(p,n,:) = currpsths;
        
        preF = currpsths(1:preframes);
        if(currpow==0)
            postF0 = currpsths(preframes+(1:postframes));
        end
        postF = currpsths(preframes+(1:postframes));
        [sigp,sigh] = ranksum(preF,postF,'tail','left','alpha',sigalpha);
        [sigp0,sigh0] = ranksum(postF0,postF,'tail','left','alpha',sigalpha);
        stimp2(p,n) = sigp;
        stimh2(p,n) = sigh;
        stimp20(p,n) = sigp0;
        stimh20(p,n) = sigh0;
    end
    currpow
end
stimh2 = logical(stimh2);
stimh20 = logical(stimh20);
%% Flat weighting part 2
goodcells = [];
goodpows = [];
badcells = [];
threshpow = 0.1;
lowpows = upows(upows<=threshpow);
[~,minpowind] = min(threshpow-lowpows);
minpowind = find(upows==lowpows(minpowind));
for n=1:ncells
    
    if(stimh2(minpowind,n) & stimh2(minpowind,n))
        goodcells = [goodcells;n];
        goodpows = [goodpows;threshpow];
    else
        badcells = [badcells;n];
    end

end
disp([num2str(length(goodcells)),' good cells'])

%% Further filter good cells based on distance
distthresh = 30*512/680;
goodxyz = holoRequests.targets(goodcells,:);
gooddistmat = pdist2(goodxyz(:,1:2),goodxyz(:,1:2));
gooddistmat = gooddistmat+diag(diag(gooddistmat)+9999);
% figure;imagesc(gooddistmat);

gooddistcells = [];
gooddistpows = [];
baddistcells = [];
for i=1:length(goodcells)
    if(all(gooddistmat(i,:) > distthresh))
        gooddistcells = [gooddistcells,goodcells(i)];
        gooddistpows = [gooddistpows,goodpows(i)];
    else
        baddistcells = [baddistcells;goodcells(i)];
    end
end
badcells = [badcells;baddistcells];
goodcells = gooddistcells;
goodpows = gooddistpows;
disp([num2str(length(gooddistcells)),' good dist cells'])

%% PCA on filtered cells
goodpsth = [];
for i=1:size(PSTHs,1)
    goodpsth = [goodpsth,squeeze(PSTHs(i,goodcells,:))];
end
[coeff,score,latent,~,expl] = pca(goodpsth');
pcaweights = mean(abs(coeff(:,1:100)),2);
[~,neuinds] = sort(pcaweights,'descend');
newpsth = goodpsth(ismember(1:size(goodpsth,1),neuinds(1:100)),:);


%% Trim holoRequests and recompute holoRequest
holoRequest = holoRequests;
holoRequest.targets(badcells,:) = [];
holoRequest.actualtargets(badcells,:) = [];
if(length(holoRequest.xoffset)>1)
    holoRequest.xoffset(badcells,:) = [];
end
holoRequest.roiWeights = goodpows'/max(goodpows);

holoRequest = xformHoloRequest(holoRequest,0*(512/680),0*(512/680),0); % [xshift(left/right),yshift,zshift]

loc=MPhoenixLocFile();
save([loc.HoloRequest 'holoRequest.mat'],'holoRequest');
save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');
disp('Sent ROIs to the cloud')

hSI.hIntegrationRoiManager.roiGroup.clear()
imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);
%%launch
i= 0;
count = 0;
for n = 1:size(sources,2)
    theSources=sources{n};
    for k = 1:size(theSources,3)
        i=i+1;
        if(ismember(i,goodcells))
            count = count+1;
            mask = theSources(:,:,k);
            intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
            intsf.threshold = 100;
            introi = scanimage.mroi.Roi();
            introi.discretePlaneMode=1;
            introi.add(Zplanes(n), intsf);
            introi.name = ['ROI ' num2str(i+1) ];%' Depth ' num2str(zDepth(n))];
            hSI.hIntegrationRoiManager.roiGroup.add(introi);
        end
    end
end
disp(['Added ' num2str(count) ' sources to integration']);
