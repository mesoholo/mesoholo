clear;
addpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\'));
rmpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\lamiaesuite\'))
rmpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\udaysuite\'))
rmpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\udaysuite_group_dev\'))
mesoholo_setup();
ntargs = 40;
holoRequest.targets = rand(ntargs,3);

%%%% Arbitrary groups
holoRequest.groupID = [1*ones(5,1);0*ones(10,1);3*ones(15,1);2*ones(10,1)];
% holoRequest.groupID = [1*ones(10,1);2*ones(20,1)];
% holoRequest.groupID = [1*ones(10,1)];

%%%% 1 cell per trial with cellsPerHolo==hSP.nCellsVec,nGroupsPerTrial==1
%%%% Each cell has its own groupID
%%%% Stim test with cellsPerHolo==1,nGroupsPerTrial==Inf,maxHoloFlag==0
% holoRequest.groupID = 1:ntargs;

%%%% All cells per trial with cellsPerHolo==hSP.nCellsVec, nGroupsPerTrial==1 or Inf
%%%% All cells have same groupID
%%%% Stim test with cellsPerHolo==1,nGroupsPerTrial==Inf,maxHoloFlag==1
% holoRequest.groupID = ones(1,ntargs);

%%%% Weight condition experiment
%%%% 1 group per trial (based on weights for same target set) with 
%%%% cellsPerHolo==hSP.nCellsVec, nGroupsPerTrial = 1
% holoRequest.roiWeights = rand(2,ntargs);
% holoRequest.groupID = ones(1,ntargs);

%%
expParams.onlyvisflag = 0; %%%% SET THIS IMP!!!!
expParams.visflag = 0; % Set to 1 if running in conjunction with vis stim
if(~expParams.visflag)
    expParams.repeats = 5; % Set this to a specific number for holo only
else
    % If vis stim yes, then set these based on number of conditions and
    % repetitions on vis stim PC
    nvisconds = 2;
    nvisreps = 4;
    expParams.repeats = nvisconds*nvisreps; % This is the repeats per Holo
end

if(isfield(holoRequest,'roiWeights') & ~isfield(holoRequest,'oroiWeights'))
    nWeightConds = size(holoRequest.roiWeights,1);
    nWeights = size(holoRequest.roiWeights,2);
    holoRequest.otargets = holoRequest.targets;
    holoRequest.oroiWeights = holoRequest.roiWeights;
    if(nWeightConds>1)
        holoRequest.targets = repmat(holoRequest.targets,[nWeightConds,1]);
        holoRequest.roiWeights = reshape(holoRequest.roiWeights',[nWeightConds*nWeights,1]);
    end
end
if(~isfield(holoRequest,'groupID'))
    holoRequest.groupID = ones(size(holoRequest.targets,1),1);
end
if(size(holoRequest.groupID,1) < size(holoRequest.groupID,2))
    holoRequest.groupID = holoRequest.groupID';
end
if(isfield(holoRequest,'oroiWeights') & size(holoRequest.groupID,1)~=...
        size(holoRequest.targets,1))
    for i=2:size(holoRequest.oroiWeights,1)
        holoRequest.groupID = [holoRequest.groupID;holoRequest.groupID+(i-1)*1000];
    end
end

if(~expParams.onlyvisflag)
    [holoStimParams] = newStimParams_group(holoRequest);
else
    [holoStimParams] = newStimParams_group_null(holoRequest);
    holoRequest = holoStimParams.holoRequest;
end
holoRequest.holoStimParams = holoStimParams;
if(~isfield(holoRequest,'roiWeights'))
    holoRequest.roiWeights = holoStimParams.roiWeights;
end

daqParams.Fs = 20000;
isipost = (holoStimParams.isipost/1000);
daqParams.sweepLengthSec = ceil(holoStimParams.SeqDurs+isipost);
daqParams.sweepLengthSec(daqParams.sweepLengthSec<3) = 3;
daqParams.maxSweepLengthSec = max(daqParams.sweepLengthSec);
holoRequest.daqParams = daqParams;
disp(['The Longest Trial is ' num2str(daqParams.maxSweepLengthSec ,4) 's']);
disp(['Total experiment time is roughly ',num2str(sum(daqParams.sweepLengthSec)*expParams.repeats),'s'])

[holoRequest] = newMakeHoloTrigSeqs_group(holoRequest); % main function that computes sequences and also creates pulse and trigger patterns
outParams = holoRequest.outParams;
outParams.eomOffset = -0.15;
holoRequest = rmfield(holoRequest,'outParams');
%%
nconds = length(outParams.sequence);
for n=1:nconds
    outParams.triggerSI{n} = makepulseoutputs(1,1,25,1,1,daqParams.Fs,...
        daqParams.sweepLengthSec(n));
    outParams.triggerPT{n} = makepulseoutputs(1,1,25,1,1,daqParams.Fs,...
        daqParams.sweepLengthSec(n));
end

%% add all data to struct, create repeats for each trial, shuffle, and run
input('press enter when everything is ready to go: ','s');

locations = MesoLocFile_DAQ();
load(locations.PowerCalib,'LaserPower');
holoRequest.DE_list = ones(1,holoStimParams.nCells);

ExpStruct.expParams = expParams;
ExpStruct.holoRequest = holoRequest;
ExpStruct.holoStimParams = holoStimParams;
ExpStruct.daqParams = daqParams;
ExpStruct.outParams = outParams;

trialConditions = [];
nconds = length(outParams.sequence);
for iCond = 1:nconds
    trialConditions = [trialConditions; repmat(iCond,expParams.repeats,1)];
end

trialConditions = trialConditions(randperm(length(trialConditions)));
outparams.sequenceThisTrial = cell(1,length(trialConditions));
randflag = 0; % set to 1 if you want to randomize sequence on every trial
outParams.trialHoloSeqIds = cell(nconds,1);
outParams.stimLaserEOM = cell(nconds,1); % this is now a cell because each trial/randomized sequence will have a different pattern
outParams.stimLaserPowerOut = cell(nconds,1);
for iTrial = 1:length(trialConditions)
    t1=tic;
    %deal with actually running the trial
    iCond = trialConditions(iTrial);
    
    currsequence = outParams.sequence{iCond};
    [currsequence,outParams] = randomizeAndPowerScale_group(currsequence,iCond,randflag,holoRequest,outParams,LaserPower); % randomize and reassign appropriate voltages for new sequence
    outParams.sequenceThisTrial{iTrial} = currsequence; % Actual sequence of hologram rois on this trial, for later analysis

    display(['Stimulating at condition ',num2str(iCond),', power ',num2str(outParams.power(iCond)),', pulseDur ',num2str(outParams.pulseDur(iCond)),...
        ', ipi ',num2str(outParams.ipi(iCond)),', Hz ',num2str(outParams.Hz(iCond)),', nPulses ',num2str(outParams.nPulses(iCond)),...
        ', cellsPerHolo ',num2str(outParams.cellsPerHolo(iCond)),', nHolos ',num2str(outParams.nHolos(iCond)),...
        ', TrialDur ',num2str(length(outParams.nextHoloTrigger{iCond})/daqParams.Fs),'s']);
    
    % the scan image code doesn't get called until a new acq is started, so
    % this should be run just before a new trial starts
    
    dataIn = outParams.trialHoloSeqIds{iCond}(:,end);

    %provide the key to
    ExpStruct.inputs{iTrial} = dataIn;
    ExpStruct.trialCond(iTrial) = iCond;
    ExpStruct.outParams = outParams;    
    
    plottype = 2;% 1 plots scatter balls 2 plots 3D voxels
    datamode = 'peak'; % 'mean' or 'peak'
    datawin = 0:10; %(window in ms after onset of laser pulse start for a particular hologram)
%     onlineresults = plotDataOnline_ephys(ExpStruct,dataIn,plottype,datamode,datawin);
    
    display(['Trial ' num2str(iTrial) ' finished!'])
%     input('Press enter to do one more')
toc(t1)
end

%%
% %% Count cells/spikes per second for each condition
% 
% nconds = size(outParams.nextHoloSeqIds,2);
% npulses = zeros(1,nconds);
% nholos = zeros(1,nconds);
% ncellsperholo = holoStimParams.cellsPerHolo(1);
% twin = round(0.5*daqParams.Fs)-300:round(1.5*daqParams.Fs);
% figure
% for i=1:nconds
%     currholoseqids = outParams.nextHoloSeqIds(twin,i);
%     pulsets = find(diff(currholoseqids)>0)+1;
%     npulses(i) = length(pulsets);
%     nholos(i) = length(unique(currholoseqids(pulsets)));
%     plot(-300:daqParams.Fs,outParams.nextHoloSeqIds(twin,i),'r')
%     hold on
%     plot(-300:daqParams.Fs,outParams.nextHoloTrigger(twin,i)*max(outParams.nextHoloSeqIds(twin,i))/2,'k')
%     hold off
%     set(gca,'xlim',[-1000 22000],'ylim',[-1 max(get(gca,'ylim'))])
%     title(['IPI = ',num2str(outParams.ipi(i)),', # pulses = ',num2str(outParams.nPulses(i)),...
%         ', pulse duration = ',num2str(outParams.pulseDur(i))])
%     pause
% end
% ncells = nholos*ncellsperholo;
% nspikes = ncells.*(npulses./nholos);
% 
% figure
% sgtitle(['Hologram size = ',num2str(ncellsperholo),' cells'],'FontWeight','bold',...
%     'FontSize',12)
% 
% subplot(1,2,1)
% scatter3(holoStimParams.ipis,holoStimParams.nPulses,holoStimParams.pulseDurs,1000,ncells,'filled')
% axis square
% xlabel('Inter-pulse interval (ms)')
% ylabel('# pulses')
% zlabel('Pulse Width (ms)')
% hc = colorbar;
% set(get(hc,'label'),'string','Total # cells per second')
% ht = title('Max #cells per second','FontWeight','normal');
% view(60,30)
% 
% subplot(1,2,2)
% scatter3(holoStimParams.ipis,holoStimParams.nPulses,holoStimParams.pulseDurs,1000,nspikes,'filled')
% axis square
% xlabel('Inter-pulse interval (ms)')
% ylabel('# pulses')
% zlabel('Pulse Width (ms)')
% hc = colorbar;
% set(get(hc,'label'),'string','Total # spikes per second')
% ht = title('Max spikes (pulses) per second','FontWeight','normal');
% view(60,30)
% 
