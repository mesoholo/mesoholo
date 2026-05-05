%% Pathing 
clear all;
close all;
savePath = 'C:\Data\';

formatOut = 'yymmdd';
date=num2str(datestr(now,formatOut));

addpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\'));
rmpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\lamiaesuite\'));
rmpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\udaysuite\'));
rmpath(genpath('C:\Users\MesoHolo\Documents\MATLAB\MesoDAQCode\udaysuite_group_dev\'));
mesoholo_setup();

disp('run msocket holorequest on holo computer before continuing!')
ExpStruct.mouseID = input('please enter mouse ID: ','s');
ExpStruct.notes = input('please enter relevant info: ' ,'s');
savePath = [savePath date '\' ExpStruct.mouseID '\'];
if ~exist(savePath, 'dir')
    mkdir(savePath);
end
[ ExperimentName ] = autoExptname1(savePath, ExpStruct.mouseID);

%% Load HoloRequest
locations = MesoLocFile_DAQ();
load([locations.HoloRequest_DAQ 'holoRequest.mat']);
holoRequest = mesoRequest;

%%
sendSI = 0;
shutterFlag = 0;%Flag to specify if you want the shutter to close during stim (200ms before and 200ms post) to control cross-talk
                %0: shutter open at the beginning of experiment and stays
                %open until the end.
expParams.onlyvisflag = 0; %%%% SET THIS IMP!!!!no holography
expParams.visflag = 0; % Set to 1 if running in conjunction with vis stim
if(~expParams.visflag)
    expParams.repeats = 20; % Set this to a specific number for holo only
else
    % If vis stim yes, then set these based on number of conditions and
    % repetitions on vis stim PC
    nvisconds = 2;
    nvisreps = 30;
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
    [holoStimParams] = newStimParams_group_LA_HoloOnly_GALVOS_FAST(holoRequest);
else
    [holoStimParams] = newStimParams_group_LA_HoloOnly_GALVOS_FAST(holoRequest);
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
if holoStimParams.multiplexFlag
disp(['Holograms interleaved at ' num2str(holoStimParams.maxrate) 'Hz']);
end
[holoRequest] = newMakeHoloTrigSeqs_group(holoRequest); % main function that computes sequences and also creates pulse and trigger patterns
outParams = holoRequest.outParams;
outParams.eomOffset = -0.15;
holoRequest = rmfield(holoRequest,'outParams');

%% pair to msocket holo computer (run MSocketHoloRequest2019_2 on holo comp first
holoSocket = Holo_msocketPrep;
holoRequest = transferHRNoDAQ(holoRequest, holoSocket);
ExpStruct.holoSocket = holoSocket;
%holoRequest.DE_list(1,1) = holoRequest.DE_list(1,1)*1000; 
holoRequest.DE_list
%%
nconds = length(outParams.sequence);
nmax = 100;
for n=1:nconds
    outParams.triggerSI{n} = makepulseoutputs(1,1,25,1,1,daqParams.Fs,...
        daqParams.sweepLengthSec(n));
    outParams.triggerPT{n} = makepulseoutputs(1,1,25,1,1,daqParams.Fs,...
        daqParams.sweepLengthSec(n));
    outParams.analogPT{n} = 1*makepulseoutputs(1,1,holoStimParams.vispulsedelay,(n-50.5)*2*9/nmax,...
        1,daqParams.Fs,daqParams.sweepLengthSec(n));
    outParams.triggershutter{n} = makepulseoutputs(1,1,25,1,1,daqParams.Fs,...
        daqParams.sweepLengthSec(n));

end


%% create sessions for the two DAQs: the main session and the follower session
s = daq.createSession('ni'); %ni is company name
followerSession = daq.createSession('ni'); 
% addAnalogInputChannel(s,'Dev3',0,'Voltage'); %slm flip though

%%outputs Card 1
addAnalogOutputChannel(s,'Dev1',0,'Voltage'); %LASER EOM
addAnalogOutputChannel(s,'Dev1',1,'Voltage'); %Vis AI condition
addDigitalChannel(s,'Dev1','port0/Line2', 'OutputOnly'); %si trig
addDigitalChannel(s,'Dev1','port0/Line1', 'OutputOnly'); %slm trig
addDigitalChannel(s,'Dev1','port0/Line3', 'OutputOnly'); %pmt gate trig
addDigitalChannel(s,'Dev1','port0/Line4', 'OutputOnly'); %shutter trigger (cross-talk)


%%inputs Card 1
% addDigitalChannel(s, 'Dev3','port0/line15','InputOnly'); %pt vis stim on/off
% addDigitalChannel(s, 'Dev3','port0/line13','InputOnly'); %pt stim id signal
addDigitalChannel(s,'Dev1','port0/line5:7','InputOnly'); %running

% addAnalogInputChannel(s,'Dev1',1,'Voltage'); %running
%addAnalogInputChannel(s,'Dev3',0,'Voltage'); %SLM flip

%%outputs Card 2(galvos)
addAnalogOutputChannel(followerSession,'Dev2',0,'Voltage'); %AO0 galvo 
addAnalogOutputChannel(followerSession,'Dev2',1,'Voltage'); %AO1 galvo

%Configure the master session to export its clock and trigger
cc=addClockConnection(s,'Dev1/PFI8','external','ScanClock');%Export sample clock at PFI8
addTriggerConnection(s,'Dev1/PFI9','external','StartTrigger');%Export StartTrigger to PFI9

% Configure follower session to export the clock and trigger from the
% master session
ccfollow = addClockConnection(followerSession,'external','Dev2/PFI2','ScanClock');%Import sample clock 
addTriggerConnection(followerSession,'external','Dev2/PFI1','StartTrigger');%Import StartTrigger 

s.Rate=daqParams.Fs;
followerSession.Rate=daqParams.Fs;
%followerSession.IsContinuous = true;

%Structure to follow for signals. ,
%queueOutputData(masterSession,masterdata)
%queueOutputData(followerSession,followerdata)
%startBackground(followerSession)
%startForeground(masterSession)

%% Prep trials/ Add all data to struct, create repeats for each trial, shuffle, and run
input('press enter when everything is ready to go: ','s');

locations = MesoLocFile_DAQ();
load(locations.PowerCalib,'LaserPower');
% load('C:\Users\adesniklab\Documents\MATLAB\udaysuite\LEDVoltage.mat','LEDVoltage');
% LaserPower = LEDVoltage;


%Generate galvo signal for each condition
outParams.VoltageX = cell(1,nconds);
outParams.VoltageY = cell(1,nconds);

for iCond = 1:nconds
    if all(outParams.nextHoloStims{1,iCond}==0) %Condition Power zero 
        outParams.VoltageX{1,iCond} = zeros(size(outParams.nextHoloStims{1, 1},1),1);
        outParams.VoltageY{1,iCond} = zeros(size(outParams.nextHoloStims{1, 1},1),1);
    else
        %Find all desceding fronts (end of pulses
        basevector = outParams.nextHoloStims{1, iCond};
        shifted_vector = [NaN;basevector(1:end-1)];
        descending_fronts = (basevector==0)&(shifted_vector==1);
        indices_fronts = find(descending_fronts);
        voltage0 = zeros(size(outParams.nextHoloStims{1, 1},1),1);
        voltage1 = zeros(size(outParams.nextHoloStims{1, 1},1),1);
        if max(holoRequest.groupID)== 2 %Works only when interleaving 2 holos
            voltage0(1:indices_fronts(1))=holoRequest.AO0(1,1);
            voltage1(1:indices_fronts(1))=holoRequest.AO1(1,1);
            for idx = 1:length(indices_fronts)-1
                if mod(idx,2)==1 %even indexes so end of Holo1 pulses
                    voltage0(indices_fronts(idx):indices_fronts(idx+1))= holoRequest.AO0(1,2);%voltageHolo2
                    voltage1(indices_fronts(idx):indices_fronts(idx+1))= holoRequest.AO1(1,2);
                else
                    voltage0(indices_fronts(idx):indices_fronts(idx+1))= holoRequest.AO0(1,1);%voltageHolo1
                    voltage1(indices_fronts(idx):indices_fronts(idx+1))= holoRequest.AO1(1,1);
                end                  
            end
        end
              
        outParams.VoltageX{1,iCond} = voltage0;
        outParams.VoltageY{1,iCond} = voltage1;
    end 
    
end

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
outParams.pmtGate = cell(nconds,1);

% Send dummy sequence and triggers to SLM to prime and avoid first timeouts
msocketSendHolo([1 1 1], ExpStruct);
dummytrigger = zeros(daqParams.Fs,1);
dummytrigger(round(linspace(daqParams.Fs/1.5,daqParams.Fs/10,10))) = 1;
dummytrigger(round(linspace(daqParams.Fs/1.5,daqParams.Fs/10,10)+daqParams.Fs/500)) = -1;
dummytrigger = cumsum(dummytrigger);
dummyshutter = vertcat(zeros(length(dummytrigger)/2,1),ones(length(dummytrigger)/2,1));
queueOutputData(s, [zeros(length(dummytrigger),1)-outParams.eomOffset,zeros(length(dummytrigger),2),...
dummytrigger,zeros(length(dummytrigger),1),dummyshutter]);


% Send # holoConditions to PT
% nconds HAS TO BE < nmax=100
if(expParams.visflag)%To do Needs to be adjusted to shutter upgrade & master/follower code
    out = [0*zeros(length(dummytrigger),1),...
        outParams.analogPT{nconds}(1:length(dummytrigger)), ...
        0*zeros(length(dummytrigger),3),dummyshutter]; %just duplicate SI for PT
    queueOutputData(s, out);
    %dataIn = s.startForeground;
end

% Prime galvos to (0,0)
outputVoltageX = 0;
outputVoltageY = 0;
safetyLock = @(voltage) max(min(voltage,5),-5);
firstCond = trialConditions(1);
outputVoltageX = safetyLock(0);
outputVoltageY = safetyLock(0);
fprintf(['Update GalvoX:' num2str(outputVoltageX) 'V, Update GalvoY:' num2str(outputVoltageY) 'V  ']);
duration = 0.1;
rate = daqParams.Fs;
time = linspace(0,duration,duration*rate);
voltageSignalX = outputVoltageX * ones(size(time));
voltageSignalY = outputVoltageY * ones(size(time));

queueOutputData(followerSession,[voltageSignalX',voltageSignalY']);

 followerSession.startBackground;
 s.startForeground;
%% Trial loops

for iTrial = 1:length(trialConditions)
    ttrial = tic;
    
    %deal with actually running the trial
    iCond = trialConditions(iTrial);
    
    currsequence = outParams.sequence{iCond};
    [currsequence,outParams] = randomizeAndPowerScale_group(currsequence,iCond,randflag,holoRequest,outParams,LaserPower); % randomize and reassign appropriate voltages for new sequence
    outParams.sequenceThisTrial{iTrial} = currsequence; % Actual sequence of hologram rois on this trial, for later analysis
    sendThis = outParams.sequenceThisTrial{iTrial};
    
    if(sendSI)
    sendThisSI.power = outParams.power(iCond);
    if(sendThisSI.power==0)
        sendThisSI.times = outParams.firstStimTimes{iCond+1};
        sendThisSI.sequence = outParams.sequence{iCond+1};
        sendThisSI.condRois = holoRequest.condRois{iCond+1,1};
    else
        sendThisSI.times = outParams.firstStimTimes{iCond};
        sendThisSI.sequence = outParams.sequenceThisTrial{iTrial};
        sendThisSI.condRois = holoRequest.condRois{iCond,1};
    end
    end
            
    tic
    msocketSendHolo(sendThis, ExpStruct);

    display(['Stimulating at condition ',num2str(iCond),', power ',num2str(outParams.power(iCond)),', pulseDur ',num2str(outParams.pulseDur(iCond)),...
        ', ipi ',num2str(outParams.ipi(iCond)),', Hz ',num2str(outParams.Hz(iCond)),', nPulses ',num2str(outParams.nPulses(iCond)),...
        ', cellsPerHolo ',num2str(outParams.cellsPerHolo(iCond)),', nHolos ',num2str(outParams.nHolos(iCond)),...
        ', TrialDur ',num2str(length(outParams.nextHoloTrigger{iCond})/daqParams.Fs),'s']);
    
  %Add condition for power zero trials
    
    %Find start of trial and start of stim
   first_trialstart = find(outParams.triggerSI{iCond}>0,1,'first');
   first_stimstart = find(outParams.stimLaserEOM{iCond}(:,end)>0,1,'first'); 
   shutterstart = first_stimstart-daqParams.Fs/5; %start200msbeforestimstarts
   shutterstop = first_stimstart+daqParams.Fs/5; %stop200msbeforestimstarts
   if shutterFlag
       if max(max(outParams.stimLaserEOM{iCond}(:,end)))> outParams.eomOffset
           %Non-zero power trials: shutter on from trial start up until 200ms
           %before stim, stays shut 200ms post-stim and then stays open until
           %200ms before the end of the trial
        outParams.triggershutter{iCond}(1:shutterstart-1)=1;
        outParams.triggershutter{iCond}(shutterstart:shutterstop-1)=0;
        outParams.triggershutter{iCond}(shutterstop:end)=1;
       else
           %Power zero condition:shutter opens at trial starts and closes 200ms
           %before trial ends
           outParams.triggershutter{iCond}(1:end)=1;             
       end
   else
       outParams.triggershutter{iCond}(1:end)=1;    
   end
    
    out = [outParams.stimLaserEOM{iCond}(:,end), outParams.analogPT{iCond}, outParams.triggerSI{iCond},...
        outParams.nextHoloTrigger{iCond},outParams.stimLaserEOM{iCond}(:,end),outParams.triggershutter{iCond}];
    out(out(:,5)<0,5) = 0;%%%%%%%%
    out(out(:,5)>0,5) = 0;%%%%%%%%SET TO 1 WHEN GATING
    outParams.pmtGate{iCond} = [outParams.pmtGate{iCond},out(:,5)];
    queueOutputData(s, out);
    
    %Make galvo data output and queuGalvoOutput
    outgalvos = [outParams.VoltageX{iCond},outParams.VoltageY{iCond}];
    queueOutputData(followerSession,outgalvos);
    toc;
    followerSession.startBackground;
    dataIn = s.startForeground;
    
    % the scan image code doesn't get called until a new acq is started, so
    % this should be run just before a new trial starts
    if(sendSI)
        msocketSendSI(sendThisSI, ExpStruct);
    end
    
    temp = [zeros(1,3);diff(dataIn,1)];
    temp(temp<0) = 0;
    temp = temp.*(dataIn(:,1)-dataIn(:,2));
    tempsum = cumsum(temp,1);
    runpos = movmean(tempsum(:,1)+tempsum(:,2),s.Rate/10);

    ExpStruct.inputs{iTrial} = [runpos,[0;diff(runpos)]];
    ExpStruct.trialCond(iTrial) = iCond;
    ExpStruct.outParams = outParams;
    
    display(['Trial ' num2str(iTrial) ' finished!'])
    disp(['Trial took ',num2str(toc(ttrial)),'s'])
    
%     figure(111)
%     subplot(2,1,1)
%     plot(outParams.nextHoloTrigger{iCond},'r')
%     subplot(2,1,2)
%     plot(dataIn,'k')
    
%     input('Press enter to do one more')
    %fprintf('\n')
end
temp = makepulseoutputs(1,1,holoStimParams.vispulsedelay,(0-50.5)*2*9/nmax,...
    1,daqParams.Fs,daqParams.sweepLengthSec(1));
out = [0*outParams.stimLaserEOM{1}(:,end), temp, 0*outParams.triggerSI{1},...
    0*outParams.nextHoloTrigger{1},0*outParams.stimLaserEOM{1}(:,end),zeros(size(outParams.triggershutter{iCond},1),1)]; %just duplicate SI for PT
queueOutputData(s, out);
s.startForeground;


save([savePath ExperimentName], 'ExpStruct','-v7.3')



