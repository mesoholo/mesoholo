%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/daq/newExpRunner_group_Uday_HoloOnly_GALVOS_daq_shutter_SLOW.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

%%
clear all;
close all;
mesoholo_setup();
savePath = getenv('MESOHOLO_LOCAL_SAVE_ROOT');
if isempty(savePath)
    savePath = fullfile(mesoholo_repo_root(), 'data', 'sessions', '_daq_output');
end
if ~endsWith(savePath, filesep)
    savePath = [savePath filesep];
end

formatOut = 'yymmdd';
date=num2str(datestr(now,formatOut));

daqRoot = getenv('MESOHOLO_DAQ_MATLAB');
if ~isempty(daqRoot)
    addpath(genpath(daqRoot));
    for sub = {'lamiaesuite', 'udaysuite', 'udaysuite_group_dev'}
        p = fullfile(daqRoot, sub{1});
        if exist(p, 'dir')
            rmpath(genpath(p));
        end
    end
end

disp('run msocket holorequest on holo computer before continuing!')
ExpStruct.mouseID = input('please enter mouse ID: ','s');
ExpStruct.notes = input('please enter relevant info: ' ,'s');
savePath = [savePath date '\' ExpStruct.mouseID '\'];
if ~exist(savePath, 'dir')
    mkdir(savePath);
end
[ ExperimentName ] = autoExptname1(savePath, ExpStruct.mouseID);


%% pair to SI computer (run this first, then run DAQmSocketPrep 
% RESTART HERE IF YOU NEED TO TRY TO CONNECT TO SI COMPUTER ONLY AGAIN
sendSI = 1;
if(sendSI)
    disp('going to connect to SI');
    SISocket = SImsocketPrep;
    ExpStruct.SISocket = SISocket;
end
%pair to SI computer (run this first, then run DAQmSocketPrep 
% RESTART HERE IF YOU NEED TO TRY TO CONNECT TO SI COMPUTER ONLY AGAIN
%sendgalvo = 1;
%if(sendgalvo)
    %disp('going to connect to SI to send galvo info');
    %SISocket = SImsocketPrep;
    %ExpStruct.SISocket = SISocket;
%end
%% load hr
locations = MesoLocFile_DAQ();
load([locations.HoloRequest_DAQ 'holoRequest.mat']);
load('dummyMesoRequest0.mat'); %%%% If onlyvisflag
holoRequest = mesoRequest;
% holoRequest.targets = rand(5,3);
% holoRequest.targets = flipud(holoRequest.targets);
% holoRequest.actualtargets = flipud(holoRequest.actualtargets);
%%%% For single targ stim test
% holoRequest.groupID = (1:size(holoRequest.targets,1))'; % single targ
% ngroups = size(holoRequest.targets,1);
% holoRequest.AO0 = repmat(holoRequest.AO0,[1,ngroups]);
% holoRequest.AO1 = repmat(holoRequest.AO1,[1,ngroups]);
% holoRequest.powerfactors = repmat(holoRequest.powerfactors,[1,ngroups]);
% holoRequest.xoffset = repmat(holoRequest.xoffset,[1,ngroups]);
% holoRequest.yoffset = repmat(holoRequest.yoffset,[1,ngroups]);
%%%%
holoRequest.groupID = ones(size(holoRequest.targets,1),1); % all at once
% holoRequest.groupID = [ones(5,1),2*ones(5,1),3*ones(5,1),4*ones(5,1)];
% holoRequest.groupID = holoRequest.groupID(randperm(20));
%%%%
%  targets = holoRequest.targets;
%  holoRequest.targets = [];
%  holoRequest.groupID = [];
%  ntargspergroup = [10,10,10,50];
%  for i=1:4
%      currinds = randperm(size(targets,1));
%      currinds = currinds(1:ntargspergroup(i));
%      holoRequest.targets = [holoRequest.targets;targets(currinds,:)]; 
%      holoRequest.groupID = [holoRequest.groupID;i*ones(ntargspergroup(i),1)];
%  end
%%%%

% stimmableinds = [2;4;6;9;11;12;16;17;25;26];
% allinds = (1:length(holoRequest.groupID))';
% notinds = allinds(~ismember(allinds,stimmableinds));
% holoRequest.groupID(stimmableinds)=1;
% holoRequest.groupID(notinds) = 2;

%%
expParams.onlyvisflag = 1; %%%% SET THIS IMP!!!!
expParams.visflag = 1; % Set to 1 if running in conjunction with vis stim
if(~expParams.visflag)
    expParams.repeats = 10; % Set this to a specific number for holo only
else
    % If vis stim yes, then set these based on number of conditions and
    % repetitions on vis stim PC
    nvisconds = 6;
    nvisreps = 25;
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

doppsf = 0;
if(doppsf)
%%%% PPSF
count = 0;
xtargets = []; ytargets = []; ztargets = []; groupID = [];
ntargs = size(holoRequest.targets,1);

% xrange = -40:5:40;
% % xrange = -37.5:7.5:37.5;
% for xppsf = xrange
%     count = count+1;
%     xtargets = [xtargets;holoRequest.targets(:,1)+1*xppsf];
%     ytargets = [ytargets;holoRequest.targets(:,2)+0*xppsf];
%     ztargets = [ztargets;holoRequest.targets(:,3)];
%     groupID = [groupID;count*ones(ntargs,1)];
% end
zrange = -80:10:80;
% zrange = -75:7.5:75;
for zppsf = zrange
    count = count+1;
    xtargets = [xtargets;holoRequest.targets(:,1)];
    ytargets = [ytargets;holoRequest.targets(:,2)];
    ztargets = [ztargets;holoRequest.targets(:,3)+zppsf];
    groupID = [groupID;count*ones(ntargs,1)];
end

holoRequest.targets = [xtargets,ytargets,ztargets];
holoRequest.groupID = groupID;
holoRequest.AO0 = repmat(holoRequest.AO0,[1,count]);
holoRequest.AO1 = repmat(holoRequest.AO1,[1,count]);
holoRequest.powerfactors = repmat(holoRequest.powerfactors,[1,count]);
holoRequest.xoffset = repmat(holoRequest.xoffset,[1,count]);
holoRequest.yoffset = repmat(holoRequest.yoffset,[1,count]);
%%%%
end

if(~expParams.onlyvisflag)
    [holoStimParams] = newStimParams_group_Uday_HoloOnly_GALVOS(holoRequest);
else
    [holoStimParams] = newStimParams_group_Uday_NULL_GALVOS(holoRequest);
    %holoRequest = holoStimParams.holoRequest;
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

%% pair to msocket holo computer (run MSocketHoloRequest2019_2 on holo comp first
holoSocket = Holo_msocketPrep;
holoRequest = transferHRNoDAQ(holoRequest, holoSocket);
ExpStruct.holoSocket = holoSocket;
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


%% create a daq session dev1 original dev2 new 
s = daq.createSession('ni'); %ni is company name
s2 = daq.createSession('ni'); 
% addAnalogInputChannel(s,'Dev3',0,'Voltage'); %slm flip though

%%outputs
addAnalogOutputChannel(s,'Dev1',0,'Voltage'); %LASER EOM
addAnalogOutputChannel(s,'Dev1',1,'Voltage'); %Vis AI condition
addDigitalChannel(s,'Dev1','port0/Line2', 'OutputOnly'); %si trig
addDigitalChannel(s,'Dev1','port0/Line1', 'OutputOnly'); %slm trig
addDigitalChannel(s,'Dev1','port0/Line3', 'OutputOnly'); %pmt gate trig
addDigitalChannel(s,'Dev1','port0/Line4', 'OutputOnly'); %shutter trigger (cross-talk)


%%inputs
% addDigitalChannel(s, 'Dev3','port0/line15','InputOnly'); %pt vis stim on/off
% addDigitalChannel(s, 'Dev3','port0/line13','InputOnly'); %pt stim id signal
addDigitalChannel(s,'Dev1','port0/line5:7','InputOnly'); %running

% addAnalogInputChannel(s,'Dev1',1,'Voltage'); %running
%addAnalogInputChannel(s,'Dev3',0,'Voltage'); %SLM flip

%%outputs econd card (galvos)
addAnalogOutputChannel(s2,'Dev2',0,'Voltage'); %AO0 galvo 
addAnalogOutputChannel(s2,'Dev2',1,'Voltage'); %AO1 galvo

s.Rate=daqParams.Fs;
s2.Rate=daqParams.Fs;
%% add all data to struct, create repeats for each trial, shuffle, and run
input('press enter when everything is ready to go: ','s');

locations = MesoLocFile_DAQ();
load(locations.PowerCalib,'LaserPower');
% load('C:\Users\adesniklab\Documents\MATLAB\udaysuite\LEDVoltage.mat','LEDVoltage');
% LaserPower = LEDVoltage;

ExpStruct.expParams = expParams;
ExpStruct.holoRequest = holoRequest;
ExpStruct.holoStimParams = holoStimParams;
ExpStruct.daqParams = daqParams;
ExpStruct.outParams = outParams;

%%%% Send dummy sequence and triggers to SLM to prime and avoid first timeouts
msocketSendHolo([1 1 1], ExpStruct);
dummytrigger = zeros(daqParams.Fs,1);
dummytrigger(round(linspace(daqParams.Fs/1.5,daqParams.Fs/10,10))) = 1;
dummytrigger(round(linspace(daqParams.Fs/1.5,daqParams.Fs/10,10)+daqParams.Fs/500)) = -1;
dummytrigger = cumsum(dummytrigger);
dummyshutter = vertcat(zeros(length(dummytrigger)/2,1),ones(length(dummytrigger)/2,1));
%dummyshutter = zeros(length(dummytrigger),1);
queueOutputData(s, [zeros(length(dummytrigger),1)-outParams.eomOffset,zeros(length(dummytrigger),2),...
    dummytrigger,zeros(length(dummytrigger),1),dummyshutter]);
%out = [outParams.stimLaserEOM{iCond}(:,end), outParams.analogPT{iCond}, outParams.triggerSI{iCond},...
        %outParams.nextHoloTrigger{iCond},outParams.stimLaserEOM{iCond}(:,end),outParams.triggershutter{iCond}];
s.startForeground;
%%%%%%%%%%%%%%%%%%

trialConditions = [];
nconds = length(outParams.sequence);
for iCond = 1:nconds
    trialConditions = [trialConditions; repmat(iCond,expParams.repeats,1)];
end
%%%% Send # holoConditions to PT
%%%% nconds HAS TO BE < nmax=100
if(expParams.visflag)
    out = [0*zeros(length(dummytrigger),1),...
        outParams.analogPT{nconds}(1:length(dummytrigger)), ...
        0*zeros(length(dummytrigger),3),dummyshutter]; %just duplicate SI for PT
    queueOutputData(s, out);
    dataIn = s.startForeground;
end
%%%%

trialConditions = trialConditions(randperm(length(trialConditions)));
outparams.sequenceThisTrial = cell(1,length(trialConditions));
randflag = 0; % set to 1 if you want to randomize sequence on every trial
outParams.trialHoloSeqIds = cell(nconds,1);
outParams.stimLaserEOM = cell(nconds,1); % this is now a cell because each trial/randomized sequence will have a different pattern
outParams.stimLaserPowerOut = cell(nconds,1);
outParams.pmtGate = cell(nconds,1);
%  Send first Galvo voltages (first trial) through Socket

%% Galvo Socket send (same values here for all trials since only one trial)
outputVoltageX = 0;
outputVoltageY = 0;
safetyLock = @(voltage) max(min(voltage,5),-5);
firstCond = trialConditions(1);
outputVoltageX = safetyLock(holoStimParams.voltage0(firstCond));
outputVoltageY = safetyLock(holoStimParams.voltage1(firstCond));
fprintf(['Update GalvoX:' num2str(outputVoltageX) 'V, Update GalvoY:' num2str(outputVoltageY) 'V  ']);
fprintf('\n')
duration = 0.1;
rate = daqParams.Fs;
time = linspace(0,duration,duration*rate);
voltageSignalX = outputVoltageX * ones(size(time));
voltageSignalY = outputVoltageY * ones(size(time));
queueOutputData(s2,[voltageSignalX',voltageSignalY']);
s2.startForeground;
%Galvo SI socket code - deprecated
%sendgalvo = [holoStimParams.voltage0(firstCond),holoStimParams.voltage1(firstCond)];
%if ~isempty(sendgalvo)
        %invar=[]; t= tic;
        %while ~strcmp(invar,'C') && toc(t)<0.1;
            %invar = msrecv(ExpStruct.SISocket,.5);
        %end
        %if toc(t)>0.1
            %disp('SI computer handshake error')
        %else
            %disp('received handshake from SI computer ');
        %end
        %mssend(ExpStruct.SISocket, sendgalvo) ;
        %disp('Sent Galvo voltages for trial 1')
%end

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
   %Edit outParams.triggershutter accordingly 
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
    
    out = [outParams.stimLaserEOM{iCond}(:,end), outParams.analogPT{iCond}, outParams.triggerSI{iCond},...
        outParams.nextHoloTrigger{iCond},outParams.stimLaserEOM{iCond}(:,end),outParams.triggershutter{iCond}];
    out(out(:,5)<0,5) = 0;%%%%%%%%
    out(out(:,5)>0,5) = 0;%%%%%%%%SET TO 1 WHEN GATING
    outParams.pmtGate{iCond} = [outParams.pmtGate{iCond},out(:,5)];
    queueOutputData(s, out);
    toc
    dataIn = s.startForeground;
    
    if(doppsf)
        sendThisSI.cond = iCond;
    end
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
    
    ExpStruct.trialCond(iTrial) = iCond;
    ExpStruct.outParams = outParams;
    ExpStruct.inputs{iTrial} = [runpos,[0;diff(runpos)],dataIn];
    
    display(['Trial ' num2str(iTrial) ' finished!'])
    disp(['Trial took ',num2str(toc(ttrial)),'s'])
    
    %If not last trial, update galvos with upcoming trial voltage
    
    if iTrial<length(trialConditions)
        
        % Galvo Socket send (same values here for all trials since only one trial)
        nextCond = trialConditions(iTrial+1);
        outputVoltageX = safetyLock(holoStimParams.voltage0(nextCond));
        outputVoltageY = safetyLock(holoStimParams.voltage1(nextCond));
        fprintf(['Update GalvoX:' num2str(outputVoltageX) 'V, Update GalvoY:' num2str(outputVoltageY) 'V  ']);
        duration = 0.1;
        rate = daqParams.Fs;
        time = linspace(0,duration,duration*rate);
        voltageSignalX = outputVoltageX * ones(size(time));
        voltageSignalY = outputVoltageY * ones(size(time));
        queueOutputData(s2,[voltageSignalX',voltageSignalY']);
        s2.startForeground;
        %sendgalvo = [holoStimParams.voltage0(nextCond),holoStimParams.voltage1(nextCond)];
        %if ~isempty(sendgalvo)
                %invar=[]; t= tic;
                %while ~strcmp(invar,'C') && toc(t)<0.1;
                    %invar = msrecv(ExpStruct.SISocket,.5);
                %end
                %if toc(t)>0.1
                    %disp('SI computer handshake error')
                %else
                    %disp('received handshake from SI computer ');
                %end
                %mssend(ExpStruct.SISocket, sendgalvo) ;
                %disp(['Sent Galvo voltages for trial ' num2str(iTrial+1)])
        %end     
      
    else
        
        outputVoltageX = 0;
        outputVoltageY = 0;
        fprintf(['Update GalvoX:' num2str(outputVoltageX) 'V, Update GalvoY:' num2str(outputVoltageY) 'V  ']);
        duration = 0.1;
        rate = daqParams.Fs;
        time = linspace(0,duration,duration*rate);
        voltageSignalX = outputVoltageX * ones(size(time));
        voltageSignalY = outputVoltageY * ones(size(time));
        queueOutputData(s2,[voltageSignalX',voltageSignalY']);
        s2.startForeground;
        
        
        
        
        
        
        
        %sendgalvo = [0,0];
        %if ~isempty(sendgalvo)
                %invar=[]; t= tic;
                %while ~strcmp(invar,'C') && toc(t)<0.1;
                    %invar = msrecv(ExpStruct.SISocket,.5);
                %end
                %if toc(t)>0.1
                    %disp('SI computer handshake error')
                %else
                    %disp('received handshake from SI computer ');
                %end
                %mssend(ExpStruct.SISocket, sendgalvo) ;
                %disp('Last trial Galvos set back to 0')
        %end     
        
    end
    
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
