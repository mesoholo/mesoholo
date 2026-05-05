function [sequence,outParams] = randomizeAndPowerScale_group(sequence,iCond,randflag,holoRequest,outParams,LaserPower)

%%%% Randomize sequence on this trial
currSeq = sequence;
useq = unique(currSeq,'stable');
newseq = currSeq;
if(randflag)
    unewseq = useq(randperm(length(useq)));
    seqlength = 0;
    for i=1:length(unewseq)
        [~,ucurrinds] = find(currSeq==unewseq(i));
        newseq(ucurrinds) = useq(i);
%         ucurrlength = length(ucurrinds); %Commented out 8/2020
%         newseq(seqlength+(1:ucurrlength)) = currSeq(ucurrinds); %Commented out 8/2020
%         seqlength = seqlength + ucurrlength; %Commented out 8/2020
    end
end
sequence = newseq;

%%%% Randomize sequence in daq output
trialHoloSeqIds = outParams.nextHoloSeqIds{iCond};
unewseq = unique(newseq,'stable');
if(randflag)
    currHoloInds = cell(length(useq),1);
%     tic
    for i=1:length(useq)
        currHoloInds{i} = find(trialHoloSeqIds == useq(i)); %Bottleneck for large seqs
    end
%     toc
%     tic
    for i=1:length(unewseq)
        trialHoloSeqIds(currHoloInds{i}) = unewseq(i);
    end
%     toc
end
outParams.trialHoloSeqIds{iCond} = [outParams.trialHoloSeqIds{iCond},trialHoloSeqIds];


%%%% Scale Laser EOM output signal based on randomized sequence (even if no
%%%% randomization)

currPow = outParams.power(iCond);

if(currPow==0)
    outParams.stimLaserEOM{iCond} = [outParams.stimLaserEOM{iCond},...
        outParams.nextHoloStims{iCond}+outParams.eomOffset];
    outParams.stimLaserPowerOut{iCond} = [outParams.stimLaserPowerOut{iCond},...
        0.001*outParams.nextHoloStims{iCond}];
else
    currSeq = sequence;
    seqlength = length(currSeq);
    voltList = zeros(1,seqlength);
    stimLaserEOM = outParams.nextHoloStims{iCond}*0;
    stimLaserPowerOut = outParams.nextHoloStims{iCond}*0;
%     tic
    for i=1:length(unewseq)
        currRois = holoRequest.holos{unewseq(i)};
        
        currWeights = holoRequest.roiWeights(currRois);
        currWeights(isnan(currWeights)) = 1;
        
        powerAsk = currPow*sum(currWeights);
        if(isfield(holoRequest.holoStimParams,'DEcorrection') & ~holoRequest.holoStimParams.DEcorrection)
            PowerRequest = powerAsk;
        else
            PowerRequest = powerAsk/holoRequest.DE_list(unewseq(i));
            disp('DE correcting');
        end
        
        Volt = function_EOMVoltage(LaserPower.EOMVoltage,...
            LaserPower.PowerOutputTF,PowerRequest);
        if isnan(Volt)
            disp('Could not set voltage picked 0 Volts')
            Volt = 0;
        end
        voltList(i)=Volt;
        
        currHoloInds = find(trialHoloSeqIds == unewseq(i)); %Bottleneck for large seqs
        stimLaserEOM(currHoloInds) = Volt;
        stimLaserPowerOut(currHoloInds) = PowerRequest;
    end
%     toc
    stimLaserEOM(stimLaserEOM==0) = outParams.eomOffset;
    outParams.stimLaserEOM{iCond} = [outParams.stimLaserEOM{iCond},...
        stimLaserEOM+0*outParams.eomOffset];
    outParams.stimLaserPowerOut{iCond} = [outParams.stimLaserPowerOut{iCond},...
        stimLaserPowerOut];
end
