%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/daq/TESTER_newExpRunner_group_LA_HoloOnly_GALVOS_daq_shutter_FAST.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

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
sendSI = 0;
%if(sendSI)
    %disp('going to connect to SI');
    %SISocket = SImsocketPrep;
    %ExpStruct.SISocket = SISocket;
%end
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
holoRequest = mesoRequest;
% holoRequest.targets = rand(5,3);
% holoRequest.groupID = (1:size(holoRequest.targets,1))'; % single targ
%holoRequest.groupID = ones(size(holoRequest.targets,1),1); % all at once
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
expParams.onlyvisflag = 0; %%%% SET THIS IMP!!!!
expParams.visflag = 0; % Set to 1 if running in conjunction with vis stim
if(~expParams.visflag)
    expParams.repeats = 30; % Set this to a specific number for holo only
else
    % If vis stim yes, then set these based on number of conditions and
    % repetitions on vis stim PC
    nvisconds = 2;
    nvisreps = 2;
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

%%%% PPSF
% xrange = -40:10:40;
% % xrange = -37.5:7.5:37.5;
% xtargets = []; ytargets = []; ztargets = []; groupID = [];
% ntargs = size(holoRequest.targets,1);
% count = 0;
% for xppsf = xrange
%     count = count+1;
%     xtargets = [xtargets;holoRequest.targets(:,1)+xppsf];
%     ytargets = [ytargets;holoRequest.targets(:,2)];
%     ztargets = [ztargets;holoRequest.targets(:,3)];
%     groupID = [groupID;count*ones(ntargs,1)];
% end
% zrange = -80:10:80;
% % zrange = -75:7.5:75;
% for zppsf = zrange
%     count = count+1;
%     xtargets = [xtargets;holoRequest.targets(:,1)];
%     ytargets = [ytargets;holoRequest.targets(:,2)];
%     ztargets = [ztargets;holoRequest.targets(:,3)+zppsf];
%     groupID = [groupID;count*ones(ntargs,1)];
% end
% holoRequest.targets = [xtargets,ytargets,ztargets];
% holoRequest.groupID = groupID;
%%%%

if(~expParams.onlyvisflag)
    [holoStimParams] = newStimParams_group_LA_HoloOnly_GALVOS_FAST(holoRequest);
else
    [holoStimParams] = newStimParams_group_LA_HoloOnly_GALVOS_FAST(holoRequest);
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

[holoRequest] = newMakeHoloTrigSeqs_group(holoRequest); 