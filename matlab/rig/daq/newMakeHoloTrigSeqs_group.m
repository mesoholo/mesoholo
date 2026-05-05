function holoRequest = newMakeHoloTrigSeqs_group(holoRequest)

hSP = holoRequest.holoStimParams;
daqParams = holoRequest.daqParams;

allCells = hSP.cellsToUse;
uniqCellsPerHolo = unique(hSP.cellsPerHolo,'stable'); %[0 2 3]
cellsPerHoloVec = hSP.cellsPerHoloVec; %[0 2 2 3 3]
multiIDVec = hSP.multiIDVec; %[0 1 2 3 4]
nMultiConds = length(multiIDVec); %5
nHolosVec = hSP.nHolosVec; %[0 10 10 7 7]
nHolosByGroupVec = hSP.nHolosByGroupVec;
nHolos = sum(nHolosVec);
holos = cell(nHolos,1);
nconds = length(hSP.nHolos); %9
condHolos = cell(nconds,3);

holoCount = 0;
holoGroupIDs = [];
for i=1:nMultiConds
    for k=1:hSP.nGroups
        currGroup = hSP.groupIDVec(k);
        groupCells = find(hSP.groupID==currGroup);
        
        currnCellsPerHolo = cellsPerHoloVec(multiIDVec(i));
        if(currnCellsPerHolo>length(groupCells))
            currnCellsPerHolo = length(groupCells);
        end
        currnHolos = nHolosByGroupVec(k,i);
        
        if(nMultiConds>length(uniqCellsPerHolo) | hSP.randHoloBlocks)
            groupCells = groupCells(randperm(length(groupCells)));
        end
        for j=1:currnHolos
            holoCount = holoCount+1;
            if(j<currnHolos | j==1)
                holos{holoCount} = groupCells((j-1)*currnCellsPerHolo +...
                    (1:currnCellsPerHolo));
            else
                holos{holoCount} = groupCells((j-1)*...
                    currnCellsPerHolo+1:end);
            end
            holoGroupIDs(holoCount) = currGroup;
        end
        
    end
end
holoRequest.holos = holos;
holoRequest.rois = holoRequest.holos;

for i=1:nconds
    currnHolos = hSP.nHolos(i);
    cumnHolos = [0,cumsum(nHolosVec)];
    currind = hSP.multiID(i);
    
    condHolos{i,1} = holos(cumnHolos(currind)+(1:currnHolos));
    condHolos{i,2} = cumnHolos(currind)+(1:currnHolos);
    condHolos{i,3} = holoGroupIDs(cumnHolos(currind)+(1:currnHolos));
end
holoRequest.condHolos = condHolos;
holoRequest.condRois = holoRequest.condHolos;

outParams = struct();
multiplexIPI = hSP.multiplexIPI;
for n = 1:nconds
    currPow = hSP.powers(n);
    currPulseDur = hSP.pulseDurs(n);
    currIpi = hSP.ipis(n);
    currnPulses = hSP.nPulses(n);
    currCellsPerHolo = hSP.cellsPerHolo(n);
    currMultiID = hSP.multiID(n);
    currnHolos = hSP.nHolos(n);
    currSeqDur = hSP.SeqDurs(n);
    currslmWait = hSP.slmWaits(n);
    
    outParams.power(n) = currPow;
    outParams.pulseDur(n) = currPulseDur;
    outParams.ipi(n) = currIpi;
    outParams.Hz(n) = 1000/currIpi;
    outParams.nPulses(n) = currnPulses;
    outParams.cellsPerHolo(n) = currCellsPerHolo;
    outParams.multiID(n) = currMultiID;
    outParams.nHolos(n) = currnHolos;
    outParams.SeqDurs(n) = currSeqDur;
    
    blankOutput = zeros(daqParams.sweepLengthSec(n)*daqParams.Fs,1);
    
    if(currPow == 0)
        blankOutput = zeros(daqParams.maxSweepLengthSec*daqParams.Fs,1);
        outParams.sequence{n} = [];
        outParams.nextHoloTrigger{n} = blankOutput;
        outParams.nextHoloStims{n} = blankOutput;
        outParams.nextHoloSeqIds{n} = blankOutput;
    else
        stimOutput = zeros(length(blankOutput),1);
        trigOutput = zeros(length(blankOutput),1);
        holoSeqVector = zeros(length(blankOutput),1);
        
        tstart = hSP.startTime;
        pulseStart = tstart;
        Fs = daqParams.Fs;
        
        if(~hSP.multiplexFlag)
            currSeq = reshape(repmat(condHolos{n,2},[currnPulses,1]),1,length(condHolos{n,2})*currnPulses);
            outParams.sequence{n} = currSeq;
            
            for k = 1:currnHolos % just for iteration, index not used
                pulseStarts = pulseStart+((1:currnPulses)-1)*currIpi;
                pulseEnds = pulseStart+(1:currnPulses)*(currPulseDur)+((1:currnPulses)-1)*(currIpi-currPulseDur);
                stimOutput(round(pulseStarts*Fs/1000)) = 1;
                stimOutput(round(pulseEnds*Fs/1000)) = -1;
                pulseStart = pulseEnds(end) + (currIpi-currPulseDur);
            end
            
        else
            nInterMax = floor(currIpi/(currPulseDur+max([currslmWait,multiplexIPI])));
            nInterMax(nInterMax == 0) = 1;
            currCondHolos = condHolos{n,2};
            assignin('base','temp',condHolos);
            length(currCondHolos);
            nRem = nInterMax-mod(length(currCondHolos),nInterMax);
            if(mod(length(currCondHolos),nInterMax)~=0)
                currCondHolos = [currCondHolos,NaN(1,nRem)];
            end
            nSets = length(currCondHolos)/nInterMax;
            multiSets = reshape(currCondHolos,nInterMax,nSets)';
            
            currSeq = reshape(shiftdim(repmat(multiSets,[1,1,currnPulses]),1),1,length(currCondHolos)*currnPulses);
            outParams.sequence{n} = currSeq;
            outParams.sequence{n}(isnan(outParams.sequence{n})) = [];
            
            for j = 1:nInterMax
                pulseStart = tstart+(j-1)*(currPulseDur+max([currslmWait,multiplexIPI]));
                for k = 1:nSets % just for iteration, index not used
                    pulseStarts = pulseStart+((1:currnPulses)-1)*currIpi;
                    pulseEnds = pulseStart+(1:currnPulses)*(currPulseDur)+((1:currnPulses)-1)*(currIpi-currPulseDur);
                    stimOutput(round(pulseStarts*Fs/1000)) = 1;
                    stimOutput(round(pulseEnds*Fs/1000)) = -1;
                    pulseStart = pulseEnds(end) + (currIpi-currPulseDur);
                end
            end
        end
        
        pulseStarts = find(stimOutput == 1);
        pulseEnds = find(stimOutput == -1);
        holoSeqVector(pulseStarts) = currSeq;
        holoSeqVector(pulseEnds) = -currSeq;
        
        pulseInds = find(holoSeqVector);
        nanInds = isnan(holoSeqVector(pulseInds));
        holoSeqVector(pulseInds(nanInds)) = 0;
        stimOutput(pulseInds(nanInds)) = 0;
        
        [uholoSeqVector,firstStimTimes,~] = unique(holoSeqVector,'first');
        firstStimTimes = firstStimTimes(uholoSeqVector>0);
        firstStimTimes = firstStimTimes/Fs;
        
        pulseStarts = find(stimOutput == 1);
        trigStarts = pulseStarts - round((hSP.trigDuration+currslmWait)*Fs/1000);
        trigEnds = pulseStarts - round(currslmWait*Fs/1000);
        trigOutput(trigStarts) = 1;
        trigOutput(trigEnds) = -1;
        if(any(trigEnds<pulseStarts-(currslmWait*Fs/1000)))
            disp('Potential error in timing, probably something is wrong')
        end

        stimOutput = cumsum(stimOutput);
        trigOutput = cumsum(trigOutput);
        holoSeqVector = cumsum(holoSeqVector);
        
        outParams.nextHoloTrigger{n} = trigOutput;
        outParams.nextHoloStims{n} = stimOutput;
        outParams.nextHoloSeqIds{n} = holoSeqVector;
        outParams.firstStimTimes{n} = firstStimTimes;
        
    end
    
end

holoRequest.outParams = outParams;
