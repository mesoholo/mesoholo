disp('RUN THIS IN THE INSTANCE RUNNING ')
% find out ActualHoloFOV boundaries using C:\Users\MesoDAQ\Documents\MATLAB\MesoSICode\HScode\makeMasks3D_holeburn_backup.m
%{
% xynew(:,1) is the horizontal axis, xynew(:,2) is the vertical axis
xyorig = [50 50; fullnpix_orig(1)-50 fullnpix_orig(2)-50];
xynew = convertcoords_HoloFOVtoCurrentFOV(hSI,xyorig, fullnpix_orig, fullxsize_orig, fullysize_orig, fullxcenter_orig, fullycenter_orig)
%}
% 220721 for 18gb data, parallels2p took 28min (27min with do_registration=0)
% 220722 the same exact file size took 50min?!

% neuronXYcoords(:,1) is vertical, neuronXYcoords(:,2) is horizontal
% xynew(:,1) is the horizontal axis, xynew(:,2) is the vertical axis
xlb = 1002; % horizontal
xub = 1906; % horizontal 
ylb = 415;
yub = 865;

mousedate = 'HS_Ai203_2/220722/';
% depth = '150';

neuopt = 'all';

%% load suite2p output: F, Fneu, spks, iscell, ops, redcell, stat
mesoSIpath = sprintf('D:/HS/%s', mousedate);
onlinepath = sprintf('D:/HS/%sOnline/', mousedate); %plane_0/suite2p/plane0/';
vispath = sprintf('S:/Hyeyoung/visstiminfo/%svisstiminfo/', mousedate);
% load(sprintf('%svisstim_staticICtxi_%s_%s.mat', vispath, depth, nexp))

visfiles = dir([vispath, '*.mat']);
for ii= 1:numel(visfiles)
disp(visfiles(ii).name)
end
ls(mesoSIpath)
foldername = {'retinotopy0', 'staticgratings'};
disp(foldername)
input('USER NEEDS TO INPUT FOLDER NAMES FOR EVERY SESSION IN ORDER MATCHING EXPTIDN')

%%
xoffsets = [0; cumsum(nxpix)];
merge = struct();
Nstrips = numel(nxpix);
for ii = 1:Nstrips
    % temps2p = load(strcat(suite2ppath, 'plane_', num2str(ii-1), '/suite2p/plane0/Fall.mat'));
    temps2p = load(sprintf('%splane_%d/suite2p/plane0/Fall.mat', onlinepath, ii-1));
    if ii==1
        merge = temps2p;
    else
        merge = [merge temps2p];
    end
end
clearvars temps2p

ops = merge(1).ops;
iscell = cat(1, merge.iscell);
switch neuopt
    case 'iscell'
        isneuron = boolean(iscell(:,1));
        % notredneurons = find(redcell(iscell(:,1)==1,1)==0);
        % redneurons = find(redcell(iscell(:,1)==1,1)==1);
    case 'all'
        isneuron = true(size(iscell,1),1);
    otherwise
        error('neuopt not recognized')
end
Nneurons = nnz(isneuron);

% neuronplane, neuronXYZcoords
neuronstrip = NaN(Nneurons, 1); % zero-based
neuronXYcoords = NaN(Nneurons, 2); % 1 is SI-horizontal, 2 is SI-vertical
cnt = 0;
for ii = 1:Nstrips
    % assign values to neuronplane
    switch neuopt
        case 'iscell'
            tempinds = cnt+1:cnt+nnz(merge(ii).iscell(:,1)==1);
        case 'all'
            tempinds = cnt+1:cnt+size(merge(ii).iscell, 1);
    end
    neuronstrip(tempinds) = ii-1;
    
    % assign values to neuronXYZcoords
    tempstat = cell2mat(merge(ii).stat);
    tempmed = cat(1, tempstat.med);
    switch neuopt
        case 'iscell'
            neuronXYcoords(tempinds, 1:2) = tempmed(isneuron,:);
        case 'all'
            neuronXYcoords(tempinds, 1:2) = tempmed;
    end
    neuronXYcoords(tempinds, 2) = neuronXYcoords(tempinds, 2)+xoffsets(ii);

    % update cnt
    cnt = tempinds(end);
end
if ~(cnt==Nneurons && all(~isnan(neuronstrip)) && all(all(~isnan(neuronXYcoords))) )
    error('not all neurons were accounted for')
end

% select cells within holoFOV
validXYROIs = neuronXYcoords(:,1)>ylb & neuronXYcoords(:,1) <=yub & ...
    neuronXYcoords(:,2)>xlb & neuronXYcoords(:,2) <=xub;
isneuron = isneuron & validXYROIs;
Nneurons = nnz(isneuron);
neuronXYcoords = neuronXYcoords(isneuron, :);
neuronstrip = neuronstrip(isneuron, :);

% F, Fneu, spks
try
    Fall = cat(1, merge.F);
    Fneuall = cat(1, merge.Fneu);
    spksall = cat(1, merge.spks);
catch
    warning('on')
    warning('Frame number mismatch between planes')
    Fsz = cellfun(@size, {merge.F}, 'UniformOutput', false);
    Fsz = cat(1, Fsz{:});
    disp(Fsz(:,2)')
    minNframes = min(Fsz(:,2));
    Fall = NaN(size(iscell,1), minNframes);
    Fneuall = NaN(size(iscell,1), minNframes);
    spksall = NaN(size(iscell,1), minNframes);
    cnt = 0;
    for ii = 1:Nstrips
        tempinds = cnt+1:cnt+size(merge(ii).iscell,1);
        Fall(tempinds,:) = merge(ii).F(:, 1:minNframes);
        Fneuall(tempinds,:) = merge(ii).Fneu(:, 1:minNframes);
        spksall(tempinds,:) = merge(ii).spks(:, 1:minNframes);
        cnt = cnt+size(merge(ii).iscell,1);
    end
end

% clearvars merge
save(strcat(onlinepath, 'online_params.mat'), 'xoffsets', 'xlb', 'xub', 'ylb', 'yub', ...
    'isneuron', 'neuronstrip', 'neuronXYcoords', 'Nstrips', 'foldername')

%% vis files
exptids = cell(size(visfiles));
nexpts = cell(size(visfiles));

vis = struct();
for ii= 1:numel(visfiles)
    % (visstimPC) load visstim information
    load(strcat(vispath, visfiles(ii).name))
        
    visvarname = who('-file',strcat(vispath, visfiles(ii).name));
    visvar = eval(visvarname{1});    
    
    exptids{ii} = visvar.exptid;
    nexpts{ii} = visvar.nexp;
    
%     visfp = strsplit(visfiles(ii).name, '_');
%     exptids{ii} = visfp{2};
%     nexpts{ii} = visfp{end}(1:end-4);
    
    exptidn = strcat(exptids{ii}, '_', nexpts{ii});    
    disp(exptidn)
    vis.(exptidn) = visvar;
    
    if strcmp('retss', who('-file', strcat(vispath, visfiles(ii).name)))
        retinotopy_subscreen = retss;
    end            
    if ~isfield(vis.(exptidn), 'numtrials') || ~isfield(vis.(exptidn), 'durvisstim') || ~isfield(vis.(exptidn), 'iti')
        switch exptids{ii}
            case 'retinotopy'
                vis.(exptidn).numtrials = size(vis.(exptidn).locinds, 1);
                vis.(exptidn).durvisstim = numel(vis.(exptidn).orientations) * vis.(exptidn).nCycles/vis.(exptidn).tFreq;
                vis.(exptidn).iti = vis.(exptidn).durvisstim * vis.(exptidn).ratio;
            case 'RFcircle'
                vis.(exptidn).numtrials = size(vis.(exptidn).RFinds, 1);
                vis.(exptidn).durvisstim = numel(vis.(exptidn).orientations) * vis.(exptidn).nCycles/vis.(exptidn).tFreq;
                vis.(exptidn).iti = vis.(exptidn).durvisstim * vis.(exptidn).ratio;
            case {'gratings', 'staticgratings'}
                if isfield(vis.(exptidn), 'durdrifting')
                    vis.(exptidn).durvisstim = vis.(exptidn).durdrifting;
                else
                    vis.(exptidn).durvisstim = vis.(exptidn).durstatic;
                end                
            case 'JuliaMovie'
                vis.(exptidn).durvisstim = 3;
                vis.(exptidn).numtrials = vis.(exptidn).repetitions;
            case 'DorisTracking'
                % stimOn marks the start of the dumbbell movement
                vis.(exptidn).durvisstim = 2.5;
                vis.(exptidn).numtrials = length(vis.(exptidn).stimOn);
            case 'RFtracking'
                % stimOn marks the start of movement (dynamic period)
                % after durvisstim, objects stay still for
                % vis.(exptidn).isi (static period)
                % vis.(exptidn).iqi marks the inter-trial interval after
                % four half-rotations. blankscreen if vis.(exptidn).displayblank
                % trial structure: SDSDS IQI
                vis.(exptidn).durvisstim = vis.(exptidn).Nsteps/vis.(exptidn).frameRate;
                vis.(exptidn).numtrials = length(vis.(exptidn).stimOn);
            otherwise
                error('numtrials/durvisstim/iti must be specified')
        end
    end
    if strcmp(exptids{ii}, 'wheel')
        vis.(exptidn).durvisstim = vis.(exptidn).nCycles/vis.(exptidn).tFreq;
    end
    
    if ~isfield(vis.(exptidn), 'Telapsed') && isfield(vis.(exptidn), 'Tstartvisstim') && isfield(vis.(exptidn), 'Tendvisstim') 
        vis.(exptidn).Telapsed = zeros(2*vis.(exptidn).numtrials, 1);
        vis.(exptidn).Telapsed(1:2:end-1) = vis.(exptidn).Tstartvisstim;
        vis.(exptidn).Telapsed(2:2:end) = vis.(exptidn).Tendvisstim;
    end
end

%% load suite2p combined and check that frame number matches expected from ScanImage .tif files
% % get frame number in each tif file in directory
% this takes a long long time using google drive file stream :(

sireaderpath = 'C:\Users\MesoDAQ\Documents\MATLAB';
addpath(genpath(sireaderpath))

if ops.look_one_level_down
    tiffns = cat(1, dir([mesoSIpath, '*.tif']), dir([mesoSIpath, '*/*.tif']));
else 
    tiffns = dir([mesoSIpath, '*.tif']);
end

suite2pfilelist = ops.filelist;
if size(tiffns,1) ~= size(suite2pfilelist,1)
    warning('number of files preprocessed by suite2p (%d) does not match number of files in scanimage folder (%d)', ...
        size(suite2pfilelist,1), size(tiffns,1))
end

tic
import ScanImageTiffReader.ScanImageTiffReader;    
numframesperfile = zeros(size(suite2pfilelist,1),1);
% whichvisfile = zeros(size(suite2pfilelist,1),1);
for f = 1:size(suite2pfilelist,1)
import ScanImageTiffReader.ScanImageTiffReader;    
    filename = suite2pfilelist(f,:);
    dotindex = strfind(filename, '.tif');
    tiffile = filename(1:dotindex+3);
    
    reader=ScanImageTiffReader(tiffile);
    desc=reader.descriptions();
    numframesperfile(f) = size(desc,1);
    
%     visind = find(contains(tiffile, exptids) & contains(tiffile, nexpts));
%     if numel(visind)>1
%         error('more than one corresponding vis file? check')
%     end
%     if isempty(visind)
%     whichvisfile(f) = 0; % blank file with no vis index
%     else
%     whichvisfile(f) = visind;
%     end
end
toc

tiffheader = imfinfo([tiffns(1).folder '\' tiffns(1).name]);
hSIh = tiffheader(1).Software;
hSIh = regexp(splitlines(hSIh), ' = ', 'split');
for n=1:length(hSIh)
	if strfind(hSIh{n}{1}, 'SI.hChannels.channelSave')
        nch = n;
		channelssaved = str2num(hSIh{n}{2});
	end
end
numchannels = numel(channelssaved);

%% %%%%%%% USER NEEDS TO INPUT FOLDER NAMES FOR EVERY SESSION %%%%%%%%%%%

dircontents = dir(mesoSIpath);
if ~( all(ismember(foldername, {dircontents.name})) && numel(exptids)==numel(foldername) && numel(nexpts)==numel(foldername) )
    error('check foldername: user did not input correctly')
end

suite2pfilelist = ops.filelist;
whichvisfile = zeros(size(suite2pfilelist,1),1);
filenamesplitter = mousedate;
% filenamesplitter = '/'; % this should be mousedate unless I changed folder name
for f = 1:size(suite2pfilelist,1)
    filename = suite2pfilelist(f,:);
    dotindex = strfind(filename, '.tif');
    tiffile = filename(1:dotindex+3);

    visind = 0;
    for ii = 1:numel(foldername)
        if contains(tiffile, foldername{ii})
            if visind~=0
                error('more than one corresponding vis file? check')
            end
            visind = ii;
        end
    end
    whichvisfile(f) = visind;
end
fprintf('%d files have visind=0\n', nnz(whichvisfile==0))
numtimepointsperfile = numframesperfile/numchannels;

if sum(numtimepointsperfile) ~= size(Fall,2)
    error('error: %d frames expected from scanbox files vs %d frames returned by suite2p', ...
        sum(numframesperfile/numchannels), size(Fall,2))
else
save(strcat(onlinepath, 'presuite2p_params.mat'), 'visfiles', 'exptids', 'nexpts', 'vis', ...
    'numframesperfile', 'numchannels') %, 'whichvisfile'
end

%%
%% save F, spks and dF/F for each exptid. Brace yourself, this takes a while!
% dF/F. To calculate the dF/F for each fluorescence trace,  we first calculated 
% baseline fluorescence by using a median filter of width 5,401 samples (180 s). 
% We then calculated the change in fluorescence relative to baseline fluorescence (?F), 
% divided by baseline fluorescence (F). 
% To prevent very small or negative baseline fluorescence, we set the 
% baseline as the maximum of the median filter-estimated baseline and the 
% s.d. of the estimated noise of the fluorescence trace.

% frame rate for mesoscope is too slow for mode -- use median instead

% Fall = Fall;
% Fneuall = Fneuall;
% spksall = spksall;
tic
for ii=0:numel(visfiles)
    if ii==0
    tempexptid = 'spontaneous';
    tempnexp = '';        
    else
    tempexptid = exptids{ii};
    tempnexp = nexpts{ii};
    
    exptidn = strcat(exptids{ii}, '_', nexpts{ii});
    if vis.(exptidn).numtrials+1 ~= nnz(whichvisfile==ii)
        warning('number of Scanimage tif files (%d) should match number of trials plus one (%d+1)', ...
            nnz(whichvisfile==ii), vis.(exptidn).numtrials)
    end
    end
    
    if nnz(whichvisfile==ii)==0
        continue
    end
    
ntpf = find(whichvisfile==ii);
sesstartind = sum(numtimepointsperfile(1:ntpf(1)-1))+1;
sesendind = sum(numtimepointsperfile(1:ntpf(end)));
sesframeinds = sesstartind:sesendind;
    
    % split into each exptid
    F = Fall(:, sesframeinds);
    Fneu = Fneuall(:, sesframeinds);
    spks = spksall(:, sesframeinds);
    if ~exist(strcat(onlinepath, tempexptid), 'dir')
        mkdir(strcat(onlinepath, tempexptid))
    end
    save(strcat(onlinepath, tempexptid, '/Fall_split', tempnexp, '.mat'), 'F', 'Fneu', 'isneuron', 'ops', 'spks')
    
    % dF/F, z-scored dF/F
    Fcell = F(isneuron,:);
    Fneucell = Fneu(isneuron,:); % neuropil
    spkscell = spks(isneuron,:);
    
    Fccell = Fcell - ops.neucoeff * Fneucell;
    % Fzcell = (Fccell-mean(Fccell,2))./std(Fccell,0,2);
    numbaseframes = min(round(ops.fs*180), size(Fccell,2)); % 180seconds; or the entire session if session length is less than 3 min (this happens in subretinotopy)
    
    
    % the following method will be used starting September 2020
    % only do rolling average if there's a significant difference in the
    % first 3 min vs last 3 min
%     p = signrank(mean(Fcell(:,1:numbaseframes),2), mean(Fcell(:,end-numbaseframes+1:end),2));
    % turns  out signrank is too sensitive, so using a different measure
    if round(ops.fs*180)>size(Fccell,2)
        % 180seconds; or the entire session if session length is less than 3 min (this happens in subretinotopy)
        rolling = false;
    else
        Fbasefirst = median(Fccell(:,1:numbaseframes), 2);
        Fbaselast = median(Fccell(:,end-numbaseframes+1:end), 2);
        prctgt = 100*mean(Fbasefirst>Fbaselast);
        fprintf('Fbasefirst vs Fbaselast signrank p=%.4f\n    %.0f%% got dimmer\n', signrank(Fbasefirst, Fbaselast), prctgt)
        rolling = prctgt>95||prctgt<5;
    end
    
    if rolling
        % do rolling mode if greater than 95% of the cells or less than
        % 5% of the cells have higher fluorescence in the first 3 min
        % compared to last 3 min
        disp('rolling mode: this will take a while')
        
        % rolling window binned at every timepoint
        medindrow1= [zeros(1,ceil(numbaseframes/2)) 1:size(Fccell,2)-numbaseframes (size(Fccell,2)-numbaseframes)*ones(1,floor(numbaseframes/2))];
        if length(medindrow1) ~= size(Fccell, 2)
            error('check medindrow1')
        end
        medind = [1:numbaseframes]' + medindrow1;
        Fbase=zeros(size(Fccell));
        tic
        for ci=1:Nneurons
            tempF = Fccell(ci,:);
            tempFbase = median(tempF(medind), 1);
            Fbase(ci,:) = tempFbase;
        end
        toc % takes ~3 times longer than doing median        
        
        % rolling window binned at 1/2 binwidth
%         medbinoverlap = 2;
%         numbaseframes = round(numbaseframes/medbinoverlap)*medbinoverlap;  % make it an even number
%         medind = [1:numbaseframes]' + (0:numbaseframes/medbinoverlap:size(Fccell,2)-numbaseframes);
%         Fbase=zeros(size(Fccell));
%         tic
%         for ci=1:Nneurons
%             tempF = Fccell(ci,:);
%             tempFbase = median(tempF(medind), 1);
%             Fbase(ci,1:length(tempFbase)*numbaseframes/medbinoverlap) = ...
%                 reshape(repmat(tempFbase,numbaseframes/medbinoverlap,1),[],1)';
%             Fbase(ci,length(tempFbase)*numbaseframes/medbinoverlap+1:end) = tempFbase(end);
%         end
%         toc % much much faster                
    else
%         Fbase = mode(bw*(-0.5+round(Fccell/bw +0.5)), 2);
        Fbase = median(Fccell, 2);
        Fbase = repmat(Fbase, 1,size(Fccell,2));
    end    
    if ~isequal(size(Fccell), size(Fbase))
        error('F0 and F must be same size. check code')
    end
    dFF = (Fccell-Fbase)./Fbase;
    
    save(strcat(onlinepath, tempexptid, '/dFFcell', tempnexp, '.mat'), 'dFF', 'spkscell');
end
toc
clear('merged', 'Fall', 'Fneuall','spksall')



%% psth for each exptid. this takes less than 10s
% load(strcat(path2p, 'suite2p/combined/Fall.mat'), 'ops', 'iscell')
% Nneurons = nnz(isneuron);

psthall = struct();
Rall = struct(); % response during stimulus duration
validexpts = false(numel(visfiles), 1);
tic
for ii= 1:numel(visfiles)
        load(strcat(onlinepath, exptids{ii}, '/dFFcell', nexpts{ii}, '.mat')) % 'dFF', 'dFFz', 'spkscell', 'notredneurons', 'redneurons'
    
    
    exptidn = strcat(exptids{ii}, '_', nexpts{ii});
    disp(exptidn)
    
    Rall.(exptidn).dFF_sesavg = mean(double(dFF),2);
    
    Rall.(exptidn).dFF_sesstd = std(double(dFF),0,2);
        
    if strcmp(exptids{ii}, 'blankscreen') %|| isempty(str2num(nexpts{ii})) %|| strcmp(exptids{ii}, 'RFcircleCI0')
        psthall.(exptidn).dFF = dFF;
        continue
    end    
    
    % note, the last frame of each file is trialtriginds
    trialtriginds = cumsum(numtimepointsperfile(whichvisfile==ii));
    if trialtriginds(end) == size(dFF,2)
        trialtriginds(end) = [];
    else
        error('number of frames mismatch')
    end
%     if contains(exptids{ii}, 'retinotopy')
%         trialtrigframes = trialtrigframes(2:end-10);
%     end
    
    if numel(trialtriginds)==0
        warning(strcat(exptidn, ' had no triggers registered'))
        continue
    end
    if ~isequal(numel(trialtriginds), vis.(exptidn).numtrials)
        warning('number of 2p triggers must be same as the number of trials')
    end
        
    % PSTH
    numpreinds = floor(ops.fs * 2 );
    numpostinds = floor(ops.fs * 2 );
    if strcmp(exptids{ii}, 'JuliaMovie')
        numpostinds = 0;
    end
    numdurtrialinds = floor(ops.fs * vis.(exptidn).durvisstim);
    %trialtimeline = -(numpreinds + numdurtrialinds):numpostinds;
    trialtimeline = -numpreinds:numdurtrialinds+numpostinds;
    
    trialstartind = trialtriginds;
    
    numrectrials = numel(trialstartind); % number of recorded trials
    
    if numrectrials<vis.(exptidn).numtrials
        while trialstartind(end)+trialtimeline(end) > size(dFF,2)
            numrectrials = numrectrials-1;
            trialstartind = trialstartind(1:numrectrials);
        end
    end
        
    psthall.(exptidn).trialstartind = trialstartind;
        
    psthtrialinds = trialstartind + trialtimeline;
    psthtimeline = 1/ops.fs * [-numpreinds:numdurtrialinds+numpostinds];
    
    % psthall.(exptid).numpreinds = numpreinds;
    % psthall.(exptid).numpostinds = numpostinds;
    psthall.(exptidn).numdurtrialinds = numdurtrialinds;
    psthall.(exptidn).psthtimeline = psthtimeline;
    
    psthall.(exptidn).dFF = zeros([Nneurons size(psthtrialinds)]);
%     psthall.(exptidn).dFFz = zeros([Nneurons size(psthtrialinds)]);
    for ci = 1:Nneurons % <3 seconds for 1000cells
        tempdFF = dFF(ci,:);
        psthall.(exptidn).dFF(ci,:,:) = tempdFF(psthtrialinds);
        
%         tempdFFz = dFFz(ci,:);
%         psthall.(exptidn).dFFz(ci,:,:) = tempdFFz(psthtrialinds);
    end
    

    if ~strcmp(exptids{ii}, 'JuliaMovie')
        Rall.(exptidn).dFF_sesbegin = mean(dFF(:,1:trialtriginds(1)-1),2);
        
        Rall.(exptidn).dFF_sesend = mean(dFF(:,trialtriginds(end)+1:end),2);
    end
    
    durstiminds = psthtimeline>0 & psthtimeline<vis.(exptidn).durvisstim;
    %     Rall.(exptidn).dFF = squeeze(mean(psthall.(exptidn).dFF(:,:,numpreinds+1:numpreinds+floor(ops.fs * 2)+1),3)); % 2 seconds after stim onset
    % %     Rall.(exptidn).dFFz = squeeze(mean(psthall.(exptidn).dFFz(:,:,numpreinds+1:numpreinds+floor(ops.fs * 2)+1),3)); % 2 seconds after stim onset
    %     Rall.(exptidn).spks = squeeze(mean(psthall.(exptidn).spks(:,:,numpreinds+1:numpreinds+floor(ops.fs * 2)+1),3)); % 2 seconds after stim onset
    for wf = 1
        switch wf
            case 0
                whichF = 'Fc';
            case 1
                whichF = 'dFF';
            case 2
                whichF = 'spks';
        end
        % stim duration response
%         Rall.(exptidn).(whichF) = squeeze(mean(psthall.(exptidn).(whichF)(:,:,numpreinds+1:numpreinds+numdurtrialinds ),3));        
        Rall.(exptidn).(whichF) = squeeze(mean(psthall.(exptidn).(whichF)(:,:,durstiminds ),3));        
    end
    if numrectrials >= vis.(exptidn).numtrials*0.8
    validexpts(ii) = true;
    else
    validexpts(ii) = false;
    end
end
toc

save(strcat(onlinepath, 'postprocessed.mat'), 'visfiles', 'validexpts', 'exptids', 'nexpts', 'vis', 'Rall', '-v7.3')
save(strcat(onlinepath, 'postprocessed_psth.mat'), 'psthall', '-v7.3')

%%
exptidns = fieldnames(Rall);
Gexptidn = exptidns{contains(exptidns, 'staticgratings')};

Noris = length(vis.(Gexptidn).orientations);
trialoriind = mod(vis.(Gexptidn).trialorder, 100);
blanktrials = vis.(Gexptidn).trialorder==0;

Rblank = mean(Rall.(Gexptidn).dFF(:,blanktrials),2);
Rori = NaN(Nneurons, Noris);
for iori = 1:Noris
    Rori(:,iori) = mean(Rall.(Gexptidn).dFF(:,trialoriind==iori),2);
end

[Rpref, prefiori] = max(Rori,[],2);
Rorth = NaN(Nneurons,1);
for iori = 1:Noris
    neuoi = prefiori==iori;
    iorth = find(vis.(Gexptidn).orientations==mod(vis.(Gexptidn).orientations(iori)+90,180));
    Rorth(neuoi) = Rori(neuoi, iorth);
end


OSI = (Rpref-Rorth)./(Rpref+Rorth);
RI = (Rpref-Rblank); %./(Rpref+Rblank);

% figure; plot(OSI, RI, 'o')
%%
tic
SP = NaN(Nneurons,1);
Pmww_SP = NaN(Nneurons, 1);
for ci = 1:Nneurons
    preforitrials = trialoriind==prefiori(ci);
    scores = [Rall.(Gexptidn).dFF(ci, blanktrials) Rall.(Gexptidn).dFF(ci, preforitrials)];
    labels = [zeros(1,nnz(blanktrials)) ones(1,nnz(preforitrials))];

    [X,Y,T,AUC,OPTROCPT] = perfcurve(labels,scores,'1');% , 'NBoot',Nshuf);
    SP(ci) = AUC;

    Pmww_SP(ci) = signrank(Rall.(Gexptidn).dFF(ci, blanktrials), Rall.(Gexptidn).dFF(ci, preforitrials));
end
toc

tic
OP = NaN(Nneurons,1);
Pmww_OP = NaN(Nneurons, 1);
for ci = 1:Nneurons
    preforitrials = trialoriind==prefiori(ci);
    iori = prefiori(ci);
    iorth = find(vis.(Gexptidn).orientations==mod(vis.(Gexptidn).orientations(iori)+90,180));
    orthoritrials = trialoriind==iorth;

    scores = [Rall.(Gexptidn).dFF(ci, orthoritrials) Rall.(Gexptidn).dFF(ci, preforitrials)];
    labels = [zeros(1,nnz(orthoritrials)) ones(1,nnz(preforitrials))];

    [X,Y,T,AUC,OPTROCPT] = perfcurve(labels,scores,'1');% , 'NBoot',Nshuf);
    OP(ci) = AUC;

    Pmww_OP(ci) = signrank(Rall.(Gexptidn).dFF(ci, orthoritrials), Rall.(Gexptidn).dFF(ci, preforitrials));
end
toc
figure; plot(SP, OP, 'o')

%%
Ntargsperholo = 30;
threshAUC = 0.5;
holos = false(Nneurons,Noris);
for iori = 1:Noris
    neuoind = find(prefiori==iori & SP>=threshAUC & Pmww_SP<0.05 & Pmww_OP<0.05); % & OP>=threshAUC;
    [sv,si]=sort(OP(neuoind), 'descend');

    neuoind = neuoind(si(1:min([Ntargsperholo length(si)])));
    holos(neuoind,iori) = true;
    if ~isequal(unique(prefiori(neuoind)), iori)
        error('check here')
    end
    fprintf('%d %ddeg %d %.4f\n', iori, vis.(Gexptidn).orientations(iori), nnz(holos(:,iori)), mean(OP(neuoind)))
end

% neuronXYcoords(:,1) is vertical, neuronXYcoords(:,2) is horizontal
% xynew(:,1) is the horizontal axis, xynew(:,2) is the vertical axis
xynew = zeros(nnz(holos), 2);
holoGroups = NaN(1, nnz(holos));
cnt = 0;
for ih = 1:size(holos,2)
    tempinds = cnt+1:cnt+nnz(holos(:,ih));
    holoGroups(tempinds) = ih;
    xynew(tempinds,1) = neuronXYcoords(holos(:,ih), 2);    
    xynew(tempinds,2) = neuronXYcoords(holos(:,ih), 1);    
    cnt = cnt+nnz(holos(:,ih));
end
if ~( cnt==nnz(holos) && all(all(~isnan(xynew))) && all(all(~isnan(holoGroups))) )
    error('not all targets were accounted for')
end


holoRequest = s2ptoholoRequest(xynew, hSI, fullnpix_orig, fullxsize_orig, fullysize_orig, fullxcenter_orig, fullycenter_orig);
holoRequest.holoGroups = holoGroups;
holoRequest.labels = vis.(Gexptidn).orientations';

clearprev = true;
integROIs = updateSIrois_meso(hSI,holoRequest,clearprev, fullnpix_orig, fullxsize_orig, fullysize_orig, fullxcenter_orig, fullycenter_orig);

% SAVE HOLOREQUEST
loc=MesoLocFile_SI();
save([loc.HoloRequest_SI 'holoRequest.mat'],'holoRequest');
save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');
disp('Sent holoRequest to the cloud')

%% 
%{
mergeops = cat(1, merge.ops);
meanImg = cat(2,mergeops.meanImg);
figure; hold all
imagesc(meanImg)
plot(xynew(:,1), xynew(:,2), 'r*')
colormap gray
set(gca, 'YDir', 'reverse')
caxis([0 100])

meanVcorr = zeros(size(meanImg));
for istrip = 1:Nstrips
    tempVcorr = zeros(size(merge(istrip).ops.meanImg));
    tempVcorr(merge(istrip).ops.yrange(1)+1:merge(istrip).ops.yrange(2), merge(istrip).ops.xrange(1)+1:merge(istrip).ops.xrange(2)) = merge(istrip).ops.Vcorr;
    meanVcorr(:,xoffsets(istrip)+1:xoffsets(istrip+1))=tempVcorr;
end
figure; hold all
imagesc(meanVcorr)
plot(xynew(:,1), xynew(:,2), 'r*')
set(gca, 'YDir', 'reverse')
colormap gray
colorbar
%}
