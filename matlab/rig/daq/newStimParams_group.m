%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/daq/newStimParams_group.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [holoStimParams] = newStimParams_group(holoRequest)
hSP.vispulsedelay = 100;
hSP.isipre = 2000;
hSP.startTime = hSP.isipre+hSP.vispulsedelay; %ms; was 3000
hSP.isipost = 2000;
hSP.trigDuration = 3; %ms SLM flip command

nCells = size(holoRequest.targets,1);
hSP.nCells = nCells;
hSP.cellsToUse = 1:hSP.nCells;
hSP.groupID = holoRequest.groupID;
hSP.groupIDVec = unique(holoRequest.groupID);
hSP.groupIDVec(hSP.groupIDVec==0) = []; % Remove group label "0" from rest
hSP.nGroups = length(hSP.groupIDVec);
hSP.nCellsVec = [];
for i=1:hSP.nGroups
    hSP.nCellsVec = [hSP.nCellsVec,...
        length(find(hSP.groupID==hSP.groupIDVec(i)))];
end

powers           = [0 0.1 0.2]; %%%% Unordered LIST of Powers To Use in UNdivided mode (aka divided mode 1)
                                      %%%% If you want a no power condition, include 0 here,
                                      %%%
                                      % 0.4 (0.025 multi, 0.3 multi9) for holeBurn @50 div, 0 0.02 0.04 0.08 0.12 for expt
pulseDurs        = [ 15 ]; %%%% LIST of pulse durations, 10 (5 multi) for holeBurn, 5 10 15 for expt
ipis             = [ 30 ]; % LIST of ipi in ms, compute from 1000/Hz, 20 (20 multi) for holeBurn, 15 30 45 for expt
nPulses          = [ 5 ]; % LIST of #pulses, 10 (100 for multi basler) for holeBurn, 2 5 for expt
cellsPerHolo     = [ hSP.nCellsVec ]; % LIST 1 (36 multi) for holeBurn, 1 15 for expt
% 1 for stim test, hSP.nCellsVec for groups (even 1 cell per trial groups)
hSP.nGroupsPerTrial  =  Inf; % 1 or Inf (Inf for stim test)
hSP.maxHoloFlag = 0; % Irrelevant if nGroupsPerTrial == 1, OR nGroupsPerTrial ==1 && cellsPerHolo ==1
hSP.randHoloBlocks = 0;

hSP.multiplexFlag = 0; % SCALAR flag to set whether holograms are temporally multiplexed, 1 for long expts
hSP.multiplexIPI = 0; % SCALAR Used only if multiplexFlag==1, sets delay from END of one pulse to START of next
                                  % corresponding to different holo. Set to 0 for minimum time delay (==slmWait)
                                  % between multiplexed pulses

hSP.maxslmWait = 5; % SCALAR min time after slm flip before next flip

if(isfield(holoRequest,'roiWeights'))
    hSP.roiWeights = holoRequest.roiWeights;
    hSP.oroiWeights = holoRequest.oroiWeights;
else
    hSP.roiWeights = ones(1,nCells); % set weighting here *****************
    hSP.DEcorrection = 1; % 1 is default, set to 0 if using laser eom channel for other analog control
    if(~hSP.DEcorrection)
        hSP.roiWeights = (1/nCells)*hSP.roiWeights;
    end
    hSP.oroiWeights = hSP.roiWeights;
    
end
nWeightConds = size(hSP.oroiWeights,1);
weightIDs = 1:nWeightConds;

temppowers = powers; temppowers(temppowers==0) = [];
allParams = {temppowers,pulseDurs,ipis,nPulses,cellsPerHolo};
nparams = length(allParams);
combos = cell(1,nparams);
[combos{:}] = ndgrid(allParams{:});
combos = cellfun(@(x) x(:), combos,'uniformoutput',false);
allParamCombos = [combos{:}]';
allParamCombos(:,(allParamCombos(3,:)<=allParamCombos(2,:))) = [];
%%% Your own condition filter here
% allParamCombos(:,(allParamCombos(3,:)<=allParamCombos(2,:)) | (allParamCombos(3,:)>2*allParamCombos(2,:))) = [];
% allParamCombos(:,(allParamCombos(3,:)~=(allParamCombos(2,:)+5)*20)) = [];
%%%
% if(any(nPulses==1))
%     params1Pind = (allParamCombos(4,:) == 1);
%     params1P = allParamCombos(:,params1Pind);
%     allParamCombos(:,params1Pind) = [];
%     [~,inds126,~] = unique(params1P([1:2,6],:)','rows','stable');
%     params1P = params1P(:,inds126);
%     allParamCombos = [params1P,allParamCombos];
% end
if(any(powers==0))
    zeroParams = zeros(nparams,1);
    allParamCombos = [zeroParams,allParamCombos];
end
nConds = size(allParamCombos,2)
disp([num2str(nConds),' unique conditions'])

hSP.powersVec = powers;
hSP.pulseDursVec = pulseDurs;
hSP.ipisVec = ipis;
hSP.nPulsesVec = nPulses;
hSP.cellsPerHoloVec = cellsPerHolo;

hSP.powers = allParamCombos(1,:);
hSP.pulseDurs = allParamCombos(2,:);
hSP.ipis = allParamCombos(3,:);
hSP.nPulses = allParamCombos(4,:);
hSP.cellsPerHolo = allParamCombos(5,:);

multiID = 1:length(hSP.cellsPerHoloVec); %[1,2,3,4]
if(any(powers==0))
    multiID = 1+multiID; %[2,3,4,5]
end
hSP.multiID = ones(1,nConds); %[1,1,1,1,1,1,1,1,1]
uniqCellsPerHoloVec = unique(hSP.cellsPerHoloVec,'stable'); %[2,3]
for i=1:length(uniqCellsPerHoloVec) %1:2
    allreps = find(hSP.cellsPerHolo==uniqCellsPerHoloVec(i)); %[2,3,4,5] for i=1
    actreps = find(hSP.cellsPerHoloVec==uniqCellsPerHoloVec(i)); %[1,2] for i=1
    nreps = length(allreps)/length(actreps); %2 for i=1
    currIDs = multiID(actreps); %[2,3] for i=1
    hSP.multiID(allreps) = reshape(repmat(currIDs,[nreps,1]),[1,length(actreps)*nreps]); % [2,2,3,3] for i=1
end
hSP.multiIDVec = unique(hSP.multiID,'stable'); %[1,2,3,4,5]
if(any(powers==0))
    hSP.cellsPerHoloVec = [0,hSP.cellsPerHoloVec];
end
hSP.weightIDVec = weightIDs;
if(any(powers==0))
    hSP.weightID = hSP.multiID-1;
else
    hSP.weightID = hSP.multiID;
end

hSP.nHolosByGroup = zeros(hSP.nGroups,length(hSP.cellsPerHolo));
hSP.nHolosByGroupVec = zeros(hSP.nGroups,length(hSP.cellsPerHoloVec));
for i=1:hSP.nGroups
    if(isinf(hSP.nGroupsPerTrial))
        if(hSP.maxHoloFlag)
            hSP.nHolosByGroup(i,:) = ...
                ceil(hSP.nCellsVec(i)./hSP.cellsPerHolo);
            hSP.nHolosByGroupVec(i,:) = ...
                ceil(hSP.nCellsVec(i)./hSP.cellsPerHoloVec);
        else
            hSP.nHolosByGroup(i,:) = ones(1,length(hSP.cellsPerHolo));
            hSP.nHolosByGroupVec(i,:) = ones(1,length(hSP.cellsPerHoloVec));
        end
    elseif(hSP.nGroupsPerTrial == 1)
        hSP.nHolosByGroup(i,:) = (hSP.multiID - 1*any(powers==0) == i);
        hSP.nHolosByGroupVec(i,:) = (hSP.multiIDVec - 1*any(powers==0) == i);
    end
end
hSP.nHolosByGroup(:,hSP.cellsPerHolo == 0) = 0;
hSP.nHolosByGroupVec(:,hSP.cellsPerHoloVec == 0) = 0;
% hSP.nHolos = sum(hSP.nHolosByGroup(1:nGroupsPerTrial,:),1);
% hSP.nHolosVec = sum(hSP.nHolosByGroupVec(1:nGroupsPerTrial,:),1);
hSP.nHolos = sum(hSP.nHolosByGroup,1);
hSP.nHolosVec = sum(hSP.nHolosByGroupVec,1);


hSP.slmWaits = max([5*ones(1,length(hSP.pulseDurs));...
    hSP.maxslmWait-hSP.pulseDurs],[],1); %time after slm flip before shooting laser ms

if(~hSP.multiplexFlag)
    SequenceDurations = (hSP.nHolos.*(hSP.nPulses.*hSP.ipis))/1000 + ...
        (hSP.startTime)/1000; % in s
else
    SequenceDurations = (hSP.nHolos.*(hSP.nPulses.*hSP.ipis))/1000;
%     nInterMax = floor(hSP.ipis./(hSP.pulseDurs+hSP.slmWaits));
    nInterMax = floor(hSP.ipis./(hSP.pulseDurs+...
        max([hSP.slmWaits;hSP.multiplexIPI*ones(1,nConds)],[],1)));
    nInterMax(nInterMax == 0) = 1;
    SequenceDurations = SequenceDurations./nInterMax + hSP.startTime/1000;
end

maxSeqDur = max(ceil(SequenceDurations));
SequenceDurations(hSP.powers==0) = maxSeqDur;
hSP.SeqDurs = SequenceDurations;

holoStimParams = hSP;