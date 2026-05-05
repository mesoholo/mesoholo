function powerCurveAcqCallback_uday(src,evt,varargin)
    %global file_ends
    global DAQSocket
    persistent PSTHs powers
    gfrate = round(3); %%%% IMP SET THIS!!!!
    tic;
    hSI = src.hSI; % get the handle to the ScanImage model

    savePath = hSI.hScan2D.logFilePath;
    saveName = [hSI.hScan2D.logFileStem '_PSTHs.mat'];
    
    HzPerVol = hSI.hRoiManager.scanVolumeRate;
    trialVals = msrecv(DAQSocket, .5);
    flushMSocket(DAQSocket);
    %should I do a handshake either way?
    mssend(DAQSocket, 'received');
    if isempty(trialVals)
        disp('no vals, you jerk')
        total_frames = hSI.hDisplay.stripeDataBuffer{hSI.hDisplay.stripeDataBufferPointer}.frameNumberAcqMode;
        frames_this_acq = hSI.hDisplay.stripeDataBuffer{hSI.hDisplay.stripeDataBufferPointer}.frameNumberAcq;
        if total_frames == frames_this_acq
            disp('this is first acq, clear persistent');
            powers = [];
            PSTHs = [];
         end
        return
    else
        disp('recieved info')
        disp(trialVals.power)
%         ExpStruct = trialVals.ExpStruct;
    end
    [hRois,vals,~,framenumbers] = hSI.hIntegrationRoiManager.getIntegrationHistory;
    %group all rois by z location?
    %planes = hSI.hFastZ.userZs;
    %find an roi in the first plane for frame tracking purposes
    %ref_roi = find([hRois.zs]==0,1);
    %disp('hello')
    %it appears that if any frame is dropped, so are all at all vols
    total_frames = hSI.hDisplay.stripeDataBuffer{hSI.hDisplay.stripeDataBufferPointer}.frameNumberAcqMode;
    if ~isempty(total_frames)
        frames_this_acq = hSI.hDisplay.stripeDataBuffer{hSI.hDisplay.stripeDataBufferPointer}.frameNumberAcq;
        planes = hSI.hFastZ.userZs;  %no longer persistent bc it was doing weird shit
%         planes = hSI.hStackManager.arbitraryZs; % modded to this by uday 1/8/20
        ref_roi = find([hRois.zs]==0,1); 
        if total_frames == frames_this_acq
            disp('this is first acq, clear persistent');
            powers = [];
            PSTHs = [];
         end
         vols_this_acq = frames_this_acq/length(planes);
         %disp('planes are'); disp(planes);disp(frames_this_acq); disp('total frames '); disp(total_frames)
        %file_ends = [file_ends, vols_this_acq];
        %find the start of this acquisition
        %start = find(framenumbers(:, ref_roi)==total_frames - frames_this_acq+1,1);
        %disp('start is');disp(start);disp(['which is, in frames ' num2str(framenumbers(start,ref_roi))])
        start = []; 
        if isempty(start) % always do this, because the other doesn't work
            %disp('did not find a start :(')
            start = find(vals(:,1)~=0,1);
            vals = vals(start:end,:); 
            framenumbers = framenumbers(start:end,:);
      
            vals = fix_frame_drops(vals, framenumbers, length(planes), ref_roi);
            %disp(vols_this_acq)
            %and then crop down to just the relevant ones
            thisAcqVals = vals(end-vols_this_acq+1:end,:);
        else
            disp('found a start')
            %if not, just fix the frames for this acq
            thisAcqVals = vals(start:end,:);
%             disp(size(thisAcqVals));
            framenumbers = framenumbers(start:end,:);
%             disp(size(framenumbers));
            thisAcqVals = fix_frame_drops(thisAcqVals, framenumbers, length(planes), ref_roi);

        end
        
        %TODO: make this a catch that fills nans if errors
        holostimTimes = trialVals.times;
        currseq = unique(trialVals.sequence,'stable');
        condrois = trialVals.condRois;
        nrois = size(thisAcqVals,2);
        roistimTimes = zeros(1,nrois);
        for i = 1:nrois
            parentseq = find(cellfun(@(x) ismember(i,x), condrois));
            roistimTimes(i) = holostimTimes(currseq==parentseq);
            %%%% For PPSF
%             roistimTimes(i) = holostimTimes;
            %%%%
        end
        PSTHs(size(PSTHs,1)+1,:,:) = getTrialPSTH_uday(thisAcqVals,...
            roistimTimes*HzPerVol+1, 2*gfrate, 5*gfrate); % 15,45 for 1 plane, 4,12
        powers = [powers, trialVals.power];

        assignin('base','powers', powers)
        assignin('base','PSTHs', PSTHs)
        plotOnlinePSTHs_uday(PSTHs,powers,savePath,saveName,...
            1:2*gfrate,2*gfrate+1:5*gfrate); % 1:15 25:40 for 1 plane 1:4 5:12
        
        
        %now you've gotten the values for all rois with missing data filled in
        %for this acquisition. What should we do next?

        %toc;
    end