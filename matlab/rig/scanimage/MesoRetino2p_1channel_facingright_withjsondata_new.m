%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/MesoRetino2p_1channel_facingright_withjsondata_new.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

%% Paths and main variables

clearvars -EXCEPT hSI hSICtl
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
date = '20260414'; % folder with the TIFF data, organized in numbered folders
                   % The numbered folders are in sequence from the
                   % posterio-medial location going left M->L, then one row up P->A
                   % and then right L->M and so on, change as needed
                   % The superficial/vasculature fov tiffs for all fovs are also located directly in this
mousealt = mouseid(1:6); % name of folder with visual stim data ("result")

% Imaging settings
nplanes = 1;
nchannels = 1;
gfrate = 3; % imaging frame rate (i.e., "green frame rate")

retexpt = 101; % which expt #
root = [corepath,mouseid,'\',date,'\',num2str(retexpt(1)),'\'];
retjson = extractjsonparams(root);
retxpix = retjson.Lx(1); %184,620
retxum = retjson.szXY(1,2)*150; %400,620
retypix = retjson.Ly(1); %828,1550
retyum = retjson.szXY(1,1)*150; %3600,3100
ntilex = retjson.nrois;
ntilexrsz = ntilex*ntilex/2;
imsize = [retypix,retxpix];

expt = retexpt;
root = [corepath,mouseid,'\',date,'\',num2str(expt(1)),'\'];
currjson = extractjsonparams(root);
currxpix = currjson.Lx(1); %184,620
currxum = currjson.szXY(1,2)*150;
currypix = currjson.Ly(1); %828,1550
curryum = currjson.szXY(1,1)*150;

%%%% Do NOT round here in case the gfrate is not close to an integer value
%%%% Will be rounded later as a fraction of vfrate
gfrate = currjson.fs;
disp(['Actual gfrate = ',num2str(currjson.fs)]);

%%%% End from mesoscope_json_from_scanimage script

% Vis stim settings
visstimdir = [corepath,mouseid,'\',date,'\',mousealt,'\'];
stimfnames = dir([visstimdir,mouseid(1:6),'*.mat']);
for i=1:length(stimfnames)
    tempfname = stimfnames(i).name;
    if(~isempty(strfind(tempfname,num2str(expt))))
        stimfname = tempfname;
    end
end
load([visstimdir,stimfname])
vfrate = 60; % visual stim frame rate
vsize = [size(result.moviedata{1},1),size(result.moviedata{1},2)]; % size of vis stim monitor
% vsize = [128,128];
barwidth = result.oscbarwidth; % width of sweeping bar stimulus
swin = 32; % number of bins to divide pixels in EACH fov by
           % (i.e., the 750x750um fov or 512x512 pixels will be divided into swin x swin bins)
newswin = 4*[1,1*ntilex]; %actual size of pixels averaged in each bin
%2-64,4-16/32,8-16
isipre = result.isipre; % length of inter-stimulus interval in s
isipost = result.isipost;

trllength = result.stimduration+isipre+isipost; % trial length in s
ncutframes = nchannels*nplanes;
nsiframes = round(trllength*gfrate*nchannels*nplanes)-ncutframes; %
if(mod(nsiframes,2))
    nsiframes = nsiframes-1;
end
nfovs = length(expt); % Number of fovs

%% Load SI tiff files and extract/bin fov F information
% (takes a couple s per trial, few minutes overall)

nfovs = length(expt); % Number of fovs
fovntrials = zeros(1,1); % Number of trials for each fov updated below
gframes = cell(1,20); % some large number in 2nd position greater than #trials for any fov
for n=1:nfovs
    currexpt = expt(n);
    
    rawtiffdir = [corepath,mouseid,'\',date,'\',num2str(currexpt),'\']; % location of each numbered folder
    savefname = [rawtiffdir,'gframes_',num2str(n),'_newswin_[',num2str(newswin(1)),...
        ',',num2str(newswin(2)),']_ntilexrsz_',num2str(ntilexrsz),'.mat'];
    fname = dir(savefname);
    if(~isempty(fname))
        disp(['Loading ... expt ... ',num2str(currexpt)]);
        matfname = fname(1).name;
        load([rawtiffdir,matfname])
    else
        disp(['Analyzing ... expt ... ',num2str(currexpt)]);
        % All trial files for current fov
        tifffnames = dir([rawtiffdir,'*.tif']);
        ntrials = length(tifffnames);
        fovntrials(n) = ntrials;
        
        clear allframes
        for j=1:ntrials
            tic
            disp(['Trial ... ',num2str(j)])
            tifffname = tifffnames(j).name;
            
            gframes{n,j} = zeros([ceil(retypix/newswin(1)),ceil(retxpix*ntilexrsz/newswin(2)),nplanes,nsiframes/(nchannels*nplanes)]);
%             gframes{n,j} = zeros([ceil(ypix),ceil(xpix*ntilexrsz),nplanes,nsiframes/(2*nplanes)]);
            volct = 0;
            for i=1:nchannels:nsiframes
                temp = imread([rawtiffdir,tifffname],i);
                newframe = zeros(retypix,retxpix*ntilex);
                framec = [retypix,retxpix*ntilex]/2;
                scanfc = round(mean(currjson.cXY,1)*150);
                for k=1:currjson.nrois
                    currxyc = currjson.cXY(k,:)*150;
                    currxyc = currxyc-scanfc;
                    currsz = currjson.szXY(k,:)*150;
                    currirow = currjson.irow(:,k);
                    
                    currxlim = int16([(framec(2)+((currxyc(2)/currsz(2)-0.5)*(retxpix*currsz(2)/retxum)))+1,...
                        (framec(2)+((currxyc(2)/currsz(2)+0.5)*(retxpix*currsz(2)/retxum)))]);
                    if(currxlim(1)==0)
                        currxlim = currxlim+1;
                    end
                    currylim = int16([(framec(1)+((currxyc(1)/currsz(1)-0.5)*(retypix*currsz(1)/retyum)))+1,...
                        (framec(1)+((currxyc(1)/currsz(1)+0.5)*(retypix*currsz(1)/retyum)))]);
                    if(currylim(1)==0)
                        currylim = currylim+1;
                    end
                    newframe(currylim(1):currylim(2),currxlim(1):currxlim(2)) = ...
                        imresize(temp(currirow(1)+1:currirow(2),:),[length(currylim(1):currylim(2)),length(currxlim(1):currxlim(2))]);
                end
                if(mod(i+1,nchannels*nplanes)+1==1)
                    volct = volct + 1;
                end
                temp2 = imresize(conv2(newframe,ones(newswin),'same'),[ceil(retypix/newswin(1)),ceil(retxpix*ntilexrsz/newswin(2))]);
%                 temp2 = imresize(conv2(newframe,ones(newswin),'same'),[ceil(ypix),ceil(xpix*ntilexrsz)]);
                gframes{n,j}(:,:,mod(i+1,nchannels*nplanes)+1,volct) = temp2;
%                 gframes{n,j}(:,:,1,volct) = temp2;
            end
            
            toc
        end
        disp('Saving ...')
        try
        save(savefname,'gframes','fovntrials','ncutframes','-v7.3','-nocompression');
        catch
        save(savefname,'gframes','fovntrials','ncutframes','-v7.3');
        end
    end
end

%% Load vis stim "result" and extract bar position by time for each trial
clear stimdata stimxy
% All vis stim files for session
visstimdir = [corepath,mouseid,'\',date,'\',mousealt,'\'];
stimfnames = dir([visstimdir,'*.mat']);

for n=1:nfovs
    tic
    currexpt = expt(n);
    disp(['Analyzing ... expt ... ',num2str(currexpt)]);
    
    % Load vis stim file for current expt/fov
%     stimfname = stimfnames(n).name;
%     load([visstimdir,stimfname])
    frameT = result.contrast_period*vfrate;
    
    ntrials = fovntrials(n);
    dirflags = NaN(ntrials,1);
    for j=1:ntrials
        % Vis stim data
        stimdata{n,j} = double(result.moviedata{j});
        dirflags(j) = var(sum(sum(abs(stimdata{n,j}(:,:,:)-128),3),2)) >...
            var(sum(sum(abs(stimdata{n,j}(:,:,:)-128),3),1));
        nstimframes = size(stimdata{n,j},3);
        stimxy{n,j} = zeros(nstimframes,2);
        if(~dirflags(j))
            diffdim = 1;
            sumdim = 2;
        else
            diffdim = 2;
            sumdim = 1;
        end
        
        for i=1:nstimframes
            %%%%oscbar
            if(result.movtype==3.5)
                barcent = (-barwidth/2+((vsize(1)+barwidth)/frameT)*(mod(i,frameT)))*...
                    ~mod(floor(i/frameT),2)+...
                    ((vsize(1)+barwidth/2)-((vsize(1)+barwidth)/frameT)*(mod(i,frameT)))*...
                    mod(floor(i/frameT),2);
            end
            %%%%swpbar
            if(result.movtype==3.25)
                barcent = (-barwidth/2+((vsize(1)+barwidth)/frameT)*(mod(i-1,frameT)));
            end
%             densityvec = diff(sum(stimdata{n,j},sumdim));
%             barstart = find(densityvec,1);
%             barend = vsize(diffdim)-find(densityvec(end:-1:1),1);
%             barcent = (barstart+barend)/2;
            stimxy{n,j}(i,:) = [barcent*~dirflags(j),barcent*dirflags(j)];
        end
        
    end
    toc
end

%% Plot what stim bar moving looks like for kix

fov = 1; % Which expt vis stim do you want to plot
trial = 3; % Which trial
currstimdata = stimdata{fov,trial};
currstimxy = stimxy{fov,trial};

% Write to file if desired
writeflag = 0;
if(writeflag)
    vidobj = VideoWriter('HorzStimScan.avi');
    vidobj.FrameRate = 60;
    open(vidobj);
end

figure()
for i=1:length(result.tex)
    if(i==1)
        imh = imagesc(currstimdata(end:-1:1,end:-1:1,i));
        set(gca,'xlim',[-1 vsize(1)+1],'ylim',[-1 vsize(2)+1])
        colormap gray
        hold on
        posh = plot(currstimxy(i,1),currstimxy(i,2),'ko','MarkerFaceColor','k');
        set(gca,'YDir','normal','XDir','reverse')
    else
        set(imh,'CData',currstimdata(end:-1:1,end:-1:1,i))
        set(posh,'XData',currstimxy(i,1),'YData',currstimxy(i,2)) 
    end
    if(i<=600 & writeflag)
        writeVideo(vidobj,getframe(gca));
    end
    
    pause(0.005) % Change for good speed based on computer
end
if(writeflag)
    close(vidobj)
end

%% Compute retinotopic map and gradient sign map (for visual area boundaries)
% Bin stimxy to fit imaging rate and correlate for each fov

np = 1; % Which plane's data do you want to use to compute retinotopy

fovblocks = [];
fovtiles = [1,1];
for i=1:fovtiles(1)
    for j=1:fovtiles(2)
        if(j<fovtiles(2))
            fovblocks = [fovblocks;[fovtiles(1)-i+1,...
                mod(i,2)*(fovtiles(2)-mod(j,fovtiles(2))+1)+...
                ~mod(i,2)*j]];
        else
            fovblocks = [fovblocks;[fovtiles(1)-i+1,...
                mod(i,2)*1+~mod(i,2)*fovtiles(2)]];
        end
    end
end
nbins = 21; % Number of bins in which to bin horizontal and vertical locations
azbins = linspace(0-5,vsize(1)+5,nbins);
elbins = linspace(0-5,vsize(2)+5,nbins);
nbins = length(azbins)-1;
% % swin = size(gframes{2,1},1);
% % truncfac = 0*floor(0.2*newswin);
swinapx = ceil(retxpix*ntilexrsz/newswin(2)); %-2*truncfac;
swinapy = ceil(retypix/newswin(1)); %-2*truncfac;
% swinapx = ceil(xpix*ntilexrsz); %-2*truncfac;
% swinapy = ceil(ypix); %-2*truncfac;

allmeanazframes = NaN(swinapy*fovtiles(1),swinapx*fovtiles(2),nbins);
allmeanelframes = NaN(swinapy*fovtiles(1),swinapx*fovtiles(2),nbins);
% for fov = [2,3,5:12]
for fov = 1:prod(fovtiles)
    
    fovgframes = gframes(fov,:);
    fovstimxy = stimxy(fov,:);
    ntrials = length(fovstimxy);
    
    alltrialaz = [];
    alltrialel = [];
    alltrialazframes = [];
    alltrialelframes = [];
    fprintf('Trial ')
    for i=1:ntrials
        
        currgframes = squeeze(mean(fovgframes{i}(:,:,np,round(isipre*gfrate)+1:end-round(isipost*gfrate)+ncutframes),3));
        currg0pre = mean(squeeze(mean(fovgframes{i}(:,:,np,1:round(isipre*gfrate)),3)),3);
        currg0post = mean(squeeze(mean(fovgframes{i}(:,:,np,end-round(isipost*gfrate)+ncutframes:end),3)),3);
        currg0 = 0*(currg0pre+currg0post)/2;
        currgframes = currgframes-currg0;
        globalf = squeeze(mean(mean(currgframes,1),2));
%         for j=1:length(globalf)
%             currgframes(:,:,j) = currgframes(:,:,j)-globalf(j);
%         end
%         currgframes = currgframes-repmat(mean(currgframes,3),[1 1 size(currgframes,3)]);
        
        currstimxy = fovstimxy{i};
        %%%% ROUNDING while resampling is VERY IMPORTANT!!
%         currstimxy = resample(currstimxy,1,ceil(vfrate/gfrate));
        if(result.movtype==3.5)
            currstimxy = resample(currstimxy,1000,round(1000*vfrate/gfrate));
        end
        if(result.movtype==3.25)
            temp = [];
            for j=1:6
                temp2 = currstimxy((j-1)*270+(1:270),:);
                temp3 = resample(temp2,1000,round(1000*vfrate/gfrate));
                temp = [temp;temp3];
%                 temp3 = [];
%                 for k=1:2
%                     temp3 = [temp3;interp1((1:270)',temp2(:,k),1:20.053:270)];
%                 end
%                 temp = [temp;temp3'];
            end
            currstimxy = temp;
        end
            
        if(size(currstimxy,1)>length(globalf))
            currstimxy = currstimxy(1:length(globalf),:);
        end
        dirflag = find(sum(currstimxy,1));
        
        if(dirflag==1)
            alltrialazframes = cat(3,alltrialazframes,currgframes);
            alltrialaz = [alltrialaz;currstimxy(:,1)];
        else
            alltrialelframes = cat(3,alltrialelframes,currgframes);
            alltrialel = [alltrialel;currstimxy(:,2)];
        end
        fprintf('%d ',i)        
    end
    fprintf('\n')
    
    meanazframes = NaN(size(alltrialazframes,1),size(alltrialazframes,2),nbins);
    meanelframes = NaN(size(alltrialelframes,1),size(alltrialelframes,2),nbins);
    meanazlocs = NaN(nbins,1);
    meanellocs = NaN(nbins,1);
    for i=1:nbins
        
        azinds = alltrialaz>azbins(i) & alltrialaz<azbins(i+1);
        meanazframes(:,:,i) = mean(alltrialazframes(:,:,azinds),3);
        meanazlocs(i) = mean(alltrialaz(azinds));
        
        elinds = alltrialel>elbins(i) & alltrialel<elbins(i+1);
        meanelframes(:,:,i) = mean(alltrialelframes(:,:,elinds),3);
        meanellocs(i) = mean(alltrialel(elinds));
        
    end
    
%     meanazframes = permute(movmean(meanazframes(end:-1:1,:,:),7,3),[2 1 3]);
%     meanelframes = permute(movmean(meanelframes(end:-1:1,:,:),7,3),[2,1,3]);
    meanazframes = movmean(meanazframes(end:-1:1,:,:),2,3);
    meanelframes = movmean(meanelframes(end:-1:1,:,:),2,3);
    
%     meanazframes([1:truncfac, swin-truncfac+1:swin],:,:) = [];
%     meanelframes([1:truncfac, swin-truncfac+1:swin],:,:) = [];
    
    allmeanazframes(swinapy*(fovblocks(fov,1)-1)+1:swinapy*fovblocks(fov,1),...
        swinapx*(fovblocks(fov,2)-1)+1:swinapx*fovblocks(fov,2),:) = meanazframes;
    allmeanelframes(swinapy*(fovblocks(fov,1)-1)+1:swinapy*fovblocks(fov,1),...
        swinapx*(fovblocks(fov,2)-1)+1:swinapx*fovblocks(fov,2),:) = meanelframes;
    
end
% allmeanazframes(allmeanazframes<quantile(allmeanazframes(:),0.25)) = NaN;
% allmeanelframes(allmeanelframes<quantile(allmeanelframes(:),0.25)) = NaN;

%% Quick check az el traces and bins
figure
subplot(1,2,1)
plot(alltrialaz,'r.')
hold on
set(gca,'xlim',[0 size(alltrialaz,1)]);
plot(get(gca,'xlim')',[azbins;azbins],'k')
title('Azimuth')
subplot(1,2,2)
plot(alltrialel,'r.')
hold on
set(gca,'xlim',[0 size(alltrialel,1)]);
plot(get(gca,'xlim')',[elbins;elbins],'k')
title('Elevation')

%% Quick check movie of az/el activation
figure;
plotframes = meanelframes;
% plotframes = reshape(plotframes,[size(plotframes,1),size(plotframes,2),...
%     54,5]);
% plotframes = mean(plotframes,4);
for i=1:size(plotframes,3)-0
imagesc((plotframes(:,:,i)))
% imagesc((plotframes(:,:,i+1)-plotframes(:,:,i)))
title(num2str(i))
set(gca,'clim',[-100 1500])
axis square
colormap gray
colorbar
pause(0.1)
end

%% Compute preference and gradient sign maps

[~,azinds] = nanmax(allmeanazframes,[],3); azinds = nbins-azinds+1;
[~,elinds] = nanmax(allmeanelframes,[],3);
replaceinds = nanmax(allmeanazframes,[],3)<nanstd(allmeanazframes,0,3);
azinds(replaceinds) = randi(nbins,sum(replaceinds(:)),1);
replaceinds = nanmax(allmeanelframes,[],3)<nanstd(allmeanelframes,0,3);
elinds(replaceinds) = randi(nbins,sum(replaceinds(:)),1);


tbase = -10:0.5:10;
temp1 = repmat(pdf('norm',tbase,0,3),[length(tbase) 1]);
temp2 = repmat(pdf('norm',tbase,0,3)',[1 length(tbase)]);
gauss2d = temp1.*temp2; % if smoothing, comment next line out
                        % no smoothing is better for retinotopy, smoothing for gradient map
gauss2d = 1;

% azgrid = nanconv(azinds,gauss2d);
% elgrid = nanconv(elinds,gauss2d);

imlim = NaN;
gwidth = 1*[1,1]; % For good preference maps
gwidth2 = 24*[1,1]; %%%% CHANGE to get good gradient map
% azgrid = imgaussfilt(azinds,gwidth);
% elgrid = imgaussfilt(elinds,gwidth);
azgrid = medfilt2(azinds,gwidth);
elgrid = medfilt2(elinds,gwidth);

% azgrid = fliplr(azgrid);
% elgrid = fliplr(elgrid);
% azgrid = azgrid';
% elgrid = elgrid';

figure()
subplot(1,2,1)
if(isnan(imlim))
    imagesc(azgrid(1:end,1:end))
    newimsize = size(azgrid);
else
    imagesc(azgrid(1:imlim,1:imlim))
    newimsize = [imlim,imlim];
end
gco = get(gca,'Children');
set(gco,'AlphaData',~isnan(get(gco,'CData')))
set(gca,'clim',[1 nbins])
hc = colorbar;
set(hc,'Ticks',linspace(1,nbins,7),'TickLabels',num2str(linspace(-45,45,7)')) % 90'width (20cm) at 10cm dist
hold on
hold off
axis square
xlabel('Tissue M/L location (right is medial)')
ylabel('Tissue A/P location (top is anterior)')
% set(gca,'XTick',[],'YTick',[])
set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
title('Azimuth (horizontal) preference map')

subplot(1,2,2)
if(isnan(imlim))
    imagesc(elgrid(1:end,1:end))
    newimsize = size(elgrid);
else
    imagesc(elgrid(1:imlim,1:imlim))
    newimsize = [imlim,imlim];
end
gco = get(gca,'Children');
set(gco,'AlphaData',~isnan(get(gco,'CData')))
set(gca,'clim',[1 nbins])
hc = colorbar;
set(hc,'Ticks',linspace(1,nbins,7),'TickLabels',num2str(linspace(-36,36,7)')) % 72'width (15cm) at 10cm dist
hold on
hold off
axis square
xlabel('Tissue M/L location (right is medial)')
ylabel('Tissue A/P location (top is anterior)')
% set(gca,'XTick',[],'YTick',[])
set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
title('Elevation (vertical) preference map')

% sgt = sgtitle('Retinopic preference maps');
% sgt.FontSize = 15;sgt.FontWeight = 'bold';

azgrid = imgaussfilt(azinds,gwidth2);
elgrid = imgaussfilt(elinds,gwidth2);
% azgrid = medfilt2(azinds,gwidth2);
% elgrid = medfilt2(elinds,gwidth2);

[fxaz,fyaz] = gradient(azgrid,1);
% fxaz(abs(fxaz)>0.5)=0;fyaz(abs(fyaz)>0.5)=0;
angaz = atan2(fyaz,fxaz);
[fxel,fyel] = gradient(elgrid,1);
% fxel(abs(fxel)>0.5)=0;fyel(abs(fyel)>0.5)=0;
angel = atan2(fyel,fxel);
signf = -sin(angel-angaz);
% signf = -sin(angel-angaz).*(abs(mean(allmeanazframes,3)).^0.5);
% signf = -sin(angel-angaz).*(abs(var(allmeanazframes,0,3)).^0.25);
% signf = -sin(angel-angaz).*(1./(abs(mean(zscore(allmeanazframes,0,3),3))).^0.25);
temp1 = allmeanazframes-repmat(nanmedian(allmeanazframes,3),[1,1,nbins]);
temp2 = allmeanelframes-repmat(nanmedian(allmeanelframes,3),[1,1,nbins]);
signf = signf.*(nanmax(abs(temp1),[],3).*nanmax(abs(temp2),[],3));
% signf = signf./(nanmean(abs(temp1),3)./nanmean(abs(temp2),3));
% signf = signf.*(skewness(abs(temp1),0,3).*skewness(abs(temp2),0,3));
signf = signf/nanmax(abs(signf(:)));


figure()
mwidth = 2;
for i=1:0
signf = medfilt2(signf,[mwidth,mwidth])+0*edge(medfilt2(signf,[mwidth,mwidth]),'sobel');
end
signf = imgaussfilt(signf,mwidth*2);
% signf = flipud(signf); %%% With new orientation of mouse starting 11/12/21
% signf = fliplr(signf);
if(isnan(imlim))
    imagesc(signf(1:end,1:end))
    newimsize = size(signf);
else
    imagesc(signf(1:imlim,1:imlim))
    newimsize = [imlim,imlim];
end
% set(gca,'clim',[-0.005 0.005])
slideclim([-0.025 0.025])
colormap jet
hold on
hold off
axis square
xlabel('Tissue M/L location (right is medial)')
ylabel('Tissue A/P location (top is anterior)')
set(gca,'XTick',[],'YTick',[])
set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
ht = title('Gradient sign map');
ht.FontSize = 12;

% figure()
% subplot(1,2,1)
% figrad = 20;
% figazrad = nbins*((figrad/2)/45)/2;
% figelrad = nbins*((figrad/2)/36)/2;
% figzone = (azgrid-(nbins/2)).^2 <=figazrad^2 & (elgrid-(nbins/2)).^2 <= figelrad^2;
% imagesc(medfilt2(figzone,[4,4]))
% axis square
% subplot(1,2,2)
% borderzone = (azgrid-11).^2+(elgrid-11).^2 >= 3^2 & (azgrid-11).^2+(elgrid-11).^2 <= 6^2;
% imagesc(medfilt2(borderzone,[4,4]))
% axis square

%% Mark visual area boundaries
clear varea

temph = imfreehand();
varea.v1 = temph.createMask();
temph = imfreehand();
varea.am = temph.createMask();
temph = imfreehand();
varea.pm = temph.createMask();
temph = imfreehand();
varea.mma = temph.createMask();
temph = imfreehand();
varea.mmp = temph.createMask();
temph = imfreehand();
varea.rl = temph.createMask();
temph = imfreehand();
varea.lm = temph.createMask();
temph = imfreehand();
varea.al = temph.createMask();
temph = imfreehand();
varea.rll = temph.createMask();
temph = imfreehand();
varea.lla = temph.createMask();
temph = imfreehand();
varea.li = temph.createMask();
temph = imfreehand();
varea.p = temph.createMask();
temph = imfreehand();
varea.notv1 = temph.createMask();

save('vareas.mat','varea')

set(get(gca,'Children'),'AlphaData',vareamask*100) %% Apply to any of the maps

%% Plot all areas individually by colour
% load([rawtiffdir,'..\101\vareas.mat'])
varealist = {'v1','am','pm','mma','mmp','rl','lm','al','rll','lla','li','p','a','rsc','notv1'};
%varealist = {'v1','am','pm','mma','rl','lm','al','li','p','rsc'};
temp1 = varealist;
temp2 = zeros(ceil(retypix/newswin(1)),ceil(retxpix*ntilex/(newswin(1)*2)));% [207,207] or [388,388]
% temp2 = zeros(97,97);
newimsize = size(temp2);
for i=1:15 %12prev
    if(isfield(varea,varealist{i}))
        temp2 = temp2+varea.(temp1{i})*i;
        temp2(temp2>i) = 0;
    end
end
hfig000 = figure;
% subplot(1,2,2)
imagesc(temp2)
vareamask = temp2;
for i=1:15
    if(isfield(varea,varealist{i}))
        [areaxpix,areaypix] = find(varea.(temp1{i}));
        text(median(areaypix),median(areaxpix),temp1{i},...
            'HorizontalAlignment','center')
    end
end
set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
xlabel('L --> M (um)')
ylabel('P --> A (um)')

axis square

%% Just text labels
for i=1:12
    if(isfield(varea,varealist{i}))
        [areaxpix,areaypix] = find(varea.(temp1{i}));
%         if(ismember(i,[1,2,5]))
%         text(median(areaypix),median(areaxpix),upper(temp1{i}),...
%             'HorizontalAlignment','center','FontSize',15,'FontWeight','bold',...
%             'Color',[0.5 0.5 0.5])
%         else
            text(median(areaypix),median(areaxpix),upper(temp1{i}),...
            'HorizontalAlignment','center','FontSize',15,'FontWeight','bold',...
            'Color',[0.0 0.0 0.0])
%         end
    end
end
%% Place area masks on average fov image

flipflag = 1; % 0 is no flip, same orientation as recorded, 1 is correct A-P orientation
trln = 2;

figure()
if(~flipflag)
    imagesc((mean(gframes{trln}(:,:,1,:),4)))
else
    imagesc(flipud(mean(gframes{trln}(:,:,1,:),4)))
end
axis square
colormap gray
slideclim([-1000,6000])

pause()
newclim = get(gca,'clim');

figure()
subplot(1,2,1)
if(flipflag)
    imagesc(flipud(mean(gframes{trln}(:,:,1,:),4)))
else
    imagesc((mean(gframes{trln}(:,:,1,:),4)))
end
axis square
colormap gray
set(gca,'clim',newclim)

set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
xlabel('L --> M (um)')
ylabel('P --> A (um)')

subplot(1,2,2)
if(flipflag)
    hfov = imagesc(flipud(mean(gframes{trln}(:,:,1,:),4)));
else
    hfov = imagesc((mean(gframes{trln}(:,:,1,:),4)));
end
axis square
colormap gray
set(gca,'clim',newclim)
if(flipflag)
    set(hfov,'AlphaData',vareamask*100) %% Apply to any of the maps
else
    set(hfov,'AlphaData',flipud(vareamask)*100) %% Apply to any of the maps
end

set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
xlabel('L --> M (um)')
ylabel('P --> A (um)')

%% Draw scanfield rectangles
clear hand
hand = struct();
%%
temph = impoly();
%%
hand(2).sfmask = temph.createMask();
hand(2).sfpos = sortrows(temph.getPosition(),1);
%%
save('handsf.mat','hand')

%% Show fov activity movie and moving bar side by side

fov = 1; % Which expt vis stim do you want to plot
dirtrials = find(~dirflags);
trial = dirtrials(1); % Which trial
% dirtrials = trial;
currstimdata = stimdata{fov,trial};
currstimxy = stimxy{fov,trial};
ndirtrials = length(dirtrials);
currframes = [];
for n=1:ndirtrials
    currframes = cat(5,currframes,gframes{dirtrials(n)});
end
currframes = mean(currframes,5);
% f0 = repmat(median(currframes,4),[1 1 1 size(currframes,4)]);
currg0pre = repmat(mean(currframes(:,:,:,1:round(isipre*gfrate)),4),[1 1 1 size(currframes,4)]);
currg0post = repmat(mean(currframes(:,:,:,end-round(isipost*gfrate)+ncutframes:end),4),[1 1 1 size(currframes,4)]);
f0 = (currg0pre+currg0post)/2;
currframes = currframes-f0;
% currframes = currframes./f0;

% Write to file if desired
writeflag = 0;
if(writeflag)
    vidobj = VideoWriter('HorzStimScan_2x.mp4','MPEG-4');
    vidobj.FrameRate = vfrate*2;
    open(vidobj);
end

figure()
set(gcf,'Units','Normalized','Position',[0.02 0.02 0.96 0.9])
vidframes = cell(200,1);
avgwin = 3;
for i=1:length(result.tex)
    currsec = isipre+floor(i/vfrate);
    currframen = ceil((i+isipre*vfrate)*gfrate/vfrate)+[-avgwin:avgwin];
    currframen(currframen<1) = [];
    currframen(currframen>size(currframes,4)) = [];
    if(i==1)
        subplot(4,2,1:2:7)
        newimsize = size(currframes);newimsize = newimsize(1:2);
        imfovh = imagesc(flipud(mean(currframes(:,:,1,currframen),4)));
%         set(gca,'clim',[-50 200])
        slideclim([-10 50])
        axis square
        set(gca,'XTick',ceil(0:1000:retyum)*newimsize(1)/retyum,'YTick',ceil(0:500:retyum)*newimsize(1)/retyum)
        set(gca,'XTickLabel',num2str((0:1000:retyum)'),'YTickLabel',num2str((0:500:retyum)'))
%         set(imfovh,'AlphaData',vareamask*100) %% Apply to any of the maps
        xlabel('L --> M (um)')
        ylabel('P --> A (um)')
        title('FOV activity')
        
        subplot(4,2,[4,6])
        imh = imagesc(currstimdata(end:-1:1,end:-1:1,i));
        set(gca,'xlim',[-1 vsize(1)+1],'ylim',[-1 vsize(2)+1])
        colormap gray
        hold on
        posh = plot(currstimxy(i,1),currstimxy(i,2),'ko','MarkerFaceColor','k');
        set(gca,'YDir','normal','XDir','reverse')
        title('Visual stimulus')
    else
%         subplot(4,2,1:2:7)
        set(imfovh,'CData',flipud(mean(currframes(:,:,1,currframen),4)))
%         set(hfov,'AlphaData',vareamask*100) %% Apply to any of the maps
%         axis square
        
%         subplot(4,2,[4,6])
        set(imh,'CData',currstimdata(end:-1:1,end:-1:1,i))
        set(posh,'XData',currstimxy(i,1),'YData',currstimxy(i,2)) 
    end

    if(i<=3240 & writeflag)
        writeVideo(vidobj,getframe(gcf));
    end
    
    pause(0.005) % Change for good speed based on computer
end
if(writeflag)
    close(vidobj)
end