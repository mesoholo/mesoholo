function run_gratings_uday_notrigger(varargin)
p = inputParser;
p.addParameter('animalid','MU');
p.addParameter('depth','100');
p.addParameter('repetitions',2); %240
p.addParameter('gratingduration',0.5);
p.addParameter('stimduration',NaN);
p.addParameter('isipre',2.5);
p.addParameter('isipost',2);
DScreen = 8; %%%% IMP SET THIS
p.addParameter('DScreen',DScreen);
ssc = load('sizeScaleCalib.mat');
sscfit = polyfitn([ssc.dscreen,ssc.actdeg],ssc.askdeg,2);
szfull = floor(2*atan2(15/2,DScreen)*180/pi)-1;
p.addParameter('sscfit',sscfit);
p.addParameter('VertScreenSize',15);
p.addParameter('HorzScreenSize',20);
szfull = 2*atan2(15/2,DScreen)*180/pi;
p.addParameter('sizes0',[szfull]); %actual deg*9/5 = size (dia) [27,54,81]
p.addParameter('contrast',[1]);
p.addParameter('orientations',0:45:315);%[0,45,90,135,180,225,270,315]
p.addParameter('sFreqs',0.04); % cyc/vis deg %actual cpd/2 = sFreqs
p.addParameter('tFreqs',2); % cyc/sec
p.addParameter('position',[0,0]); % actual pos 32.5mm = 30 [0,0] or [0,-30]
% [10,55;60,-10;-30,-35]
p.addParameter('circular',0);
p.addParameter('save_remote',0);
p.addParameter('do_triggered',0);
p.addParameter('trigger_SI',1);
p.addParameter('ntrials',200);
p.addParameter('sequenceexpt',0);
p.addParameter('nRandSeq',20);
p.parse(varargin{:});

result = p.Results;
result.sizes = round(polyvaln(result.sscfit,...
    [result.DScreen*ones(length(result.sizes0),1),result.sizes0'])');

mesoholo_setup();
visPath = getenv("MESOHOLO_VIS_PATH");
if strlength(visPath) > 0
    addpath(genpath(char(visPath)));
end
d = configure_mcc_daq;

% currently  no msocketed version, may exist in the future
result.do_msock=0;

%%% FilePaths and possibly alterable callbacks
result.stimFolderRemote = 'E:/Uday/StimData/';
result.stimFolderLocal = 'E:/Uday/StimData/';
%runFolder = 'Z:/mossing/running/';
stopFn = @cleanup_and_quit;
sendTTLFn = @sendTTLfn;
setupDaqFn = @setup_daq_fn;
  

% do housekeeping
if result.do_msock
     sock = msPrep();
end
% dq = setupDaqFn(result.trigger_SI);
[result, fnameLocal, fnameRemote] = saveFilePrep(result);

%get wininfo, and add info to result
wininfo = gen_wininfo_uday(result);
assignin('base','wininfo',wininfo)

result.dispInfo.xRes  =  wininfo.xRes;
result.dispInfo.yRes  =  wininfo.yRes;
result.dispInfo.DScreen  =  result.DScreen;
result.dispInfo.VertScreenSize  =  result.VertScreenSize;

% create all stimulus conditions from the single parameter vectors
result.positionind = 1:size(result.position,1);
nConds  =  [length(result.orientations) length(result.sizes) ...
    length(result.tFreqs) length(result.sFreqs) ...
    length(result.contrast) length(result.positionind)];
result.allConds  =  prod(nConds);
% result.ngratings = floor(result.stimduration/result.gratingduration);
result.ngratings = 1;
result.conds  =  makeAllCombos(result.orientations,result.sizes,...
    result.tFreqs,result.sFreqs,result.contrast,result.positionind);

% set some stim parameters, including whether the stim is gonna fit
% result.movieDurationFrames = ...
%     round(result.stimduration * wininfo.frameRate); %stim duration is in seconds
result.movieDurationFrames = ...
    round(result.gratingduration * wininfo.frameRate); %stim duration is in seconds
PatchRadiusPix = ceil(result.sizes.*wininfo.PixperDeg/2); % radius!!
x0 = floor(wininfo.xRes/2 + (wininfo.xposStim - result.sizes/2)*wininfo.PixperDeg);
y0 = floor(wininfo.yRes/2 + (-wininfo.yposStim - result.sizes/2)*wininfo.PixperDeg);
if ~isempty(find(x0<1, 1)) || ~isempty(find(y0<1, 1))
    disp('too big for the monitor, dude! try other parameters');
    sca; %you should do this right?
    return;
end

[gratingInfo.Orientation,gratingInfo.Contrast,gratingInfo.spFreq,...
    gratingInfo.tFreq, gratingInfo.Size, gratingInfo.PositionInd] = ...
    deal(zeros(1,result.allConds*result.repetitions));
gratingInfo.gf = 5; %.Gaussian width factor 5: reveal all .5 normal fall off
gratingInfo.Bcol = 128; % Background 0 black, 255 white
gratingInfo.method = 'symmetric';
gratingInfo.gtype = 'box';
gratingInfo.circular = result.circular;
width  =  PatchRadiusPix;
gratingInfo.widthLUT = [result.sizes(:) width(:)];
result.gratingInfo = gratingInfo;

%%TODO: return to pregenning stims by removing the close from display 

%start by displaying time number of stims, wait for user input 
Screen('DrawTexture',wininfo.w, wininfo.BG);
Screen('TextFont',wininfo.w, 'Courier New');
Screen('TextSize',wininfo.w, 14);
Screen('TextStyle', wininfo.w, 1+2);
Screen('DrawText', wininfo.w, strcat(num2str(result.allConds),' Conditions__',...
    num2str(result.repetitions),' Repeats__',...
    num2str(result.allConds*result.ntrials*(result.isipre+result.isipost+result.gratingduration)/60),...
    ' min estimated Duration.'), 60, 50, [255 128 0]);
Screen('DrawText', wininfo.w, strcat('Filename:',fnameLocal,...
    '    Hit any key to continue / q to abort.'), 60, 70, [255 128 0]);
Screen('Flip',wininfo.w);


FlushEvents;
disp('Hit any key to continue / q to abort.')
[kinp,~] = GetChar;
if kinp == 'q'|kinp == 'Q'
    Screen('CloseAll');
    return
end
FlushEvents;

% set priority level to max so that psychtoolbox is the main thing
% according to the docs its fine to just do this once, bc it won't slow us
% down that much, but if we have problems with stim rendering we should
% revisit that assumption
topPriorityLevel = MaxPriority(wininfo.w);
Priority(topPriorityLevel);

Screen('DrawTexture',wininfo.w, wininfo.BG); Screen('Flip', wininfo.w);

%begin!
result.starttime  =  datestr(now);
result.tr_num = 0;
t0  =  GetSecs;
stimParams = [];
temp = repmat([1:result.allConds],1,result.repetitions);
theseinds = temp(randperm(result.allConds*result.repetitions)); %randperm(result.allConds);
if(result.sequenceexpt)
    theseinds = temp(1:result.allConds*result.repetitions); %%%% SEQUENCE EXPTS
    randblocks = randperm(result.repetitions); randblocks = randblocks(1:result.nRandSeq) %%%% SEQUENCE EXPTS
    result.randblocks = randblocks; %%%% SEQUENCE EXPTS
    for i=1:length(randblocks) %%%% SEQUENCE EXPTS
        randblock = randblocks(i);
        randblockinds = (randblock-1)*result.allConds+(1:result.allConds);
        theseinds(randblockinds) = randperm(result.allConds);
    end %%%% SEQUENCE EXPTS
end
result.theseconds = result.conds(:,theseinds);
result.ntrials = size(result.theseconds,2);
stimParams = [stimParams result.theseconds];

%%start either the triggered loop or non-triggered loop
if ~result.do_triggered
    for itrial=1:result.ntrials % don't name it istim bc that's used by the triggered
        if ~did_you_quit()
             if result.trigger_SI %send do pulse to only SI
%                 sendTTLFn(dq, 1, result.trigger_SI,1);
%                 sendTTLFn(dq, 0, result.trigger_SI,1);
                DaqDOut(d,0,0);
                DaqDOut(d,0,1);
                tic
                disp(['Sent FileStart Marker for trial ',...
                    num2str(itrial)])

             end
             trialstart = GetSecs-t0;
             result.tr_num = result.tr_num+1;
             
             [thisstim, result] = setup_next(result, itrial, wininfo);
%              assignin('base',['thisstim',num2str(istimNT)],thisstim)
%              assignin('base',['result',num2str(istimNT)],result)
             result = deliver_stim(result,wininfo,thisstim,trialstart);
%              if(istimNT==2)
%              break
%              end
        else
            break
        end
    end
else
    istim=1;
    [firststim, result] = setup_next(result, istim, wininfo);
    result.thisstim = firststim;

    % now setup daq stuff
    s0 = daq.createSession('ni');
    %s0.addAnalogOutputChannel('Dev2',1,'Voltage');    
    [~,~] = s0.addAnalogInputChannel('Dev2',2,'Voltage');
    addTriggerConnection(s0,'external','Dev2/PFI1','StartTrigger');
    s0.TriggersPerRun = 2*result.ntrials; 
    s0.ExternalTriggerTimeout = 50;
    s0.NumberOfScans=2;
    lh = addlistener(s0,'DataAvailable',@(src,event) trigger_callback());
    try
        s0.startForeground();
    catch
        disp('Timed Out!');
    end
end

result.stimParams = stimParams; %conds(:,Condnum);

stopFn();
    
%%%%% ALL THE INNER FXNS %%%%%
    function [thisstim, result] = setup_next(result, itrial, wininfo)
        thisstim = result.theseconds(:,itrial);
        result = pickNext(result,itrial,thisstim);
        thisstim = getStim(result.gratingInfo,itrial);
        thisstim.itrial = itrial;
        thisstim.movieDurationFrames = result.movieDurationFrames;
        thisstim = gen_gratings_uday(wininfo,result.gratingInfo,thisstim);
    end
    
    function trigger_callback()
        user_quit = did_you_quit();
        if ~user_quit
            display_grating(wininfo,result.thisstim, dq);
            sendPulseTrain(dq,4,theseinds(istim),.01);
            istim = istim+1;
            [nextstim, result] = setup_next(result,istim,wininfo);
            result.thisstim = nextstim;
        else
            cleanup_and_quit()
        end
    end

    function display_grating(wininfo, thisstim)
%         sendTTLfn(dq, 1, result.trigger_SI, 0) %put stim on indicators high
        
        %WRITE THE THING THAT DISPLAYS IMAGES
        show_tex(wininfo,thisstim)
        
%         sendTTLfn(dq, 0, result.trigger_SI, 0) %put stim on indicators low
        
        Screen('DrawTexture',wininfo.w,wininfo.BG); Screen('Flip', wininfo.w);
        Screen('Close',thisstim.tex(:));
    end

    function result = deliver_stim(result,wininfo,thisstim,trialstart)        
        WaitSecs(max(0, result.isipre-((GetSecs-t0)-trialstart)));
        
        % last flip before movie starts
        Screen('DrawTexture',wininfo.w,wininfo.BG);
        fliptime  =  Screen('Flip', wininfo.w);
        result.timestamp(thisstim.trnum)  =  fliptime - t0;
        
        stimstart  =  GetSecs-t0;

        display_grating(wininfo, thisstim);
        
%         stimt = GetSecs-t0-stimstart;
        WaitSecs(result.isipost);
    end

    function sendTTLfn(dq,sign,trigSI,trig)
        %%either triggers SI before the beginning of a stim on time
        %%or indicates to daq/SI that stim went on 
        if trigSI
            if trig
                outputSingleScan(dq,[0 0 0 0 sign]);
            else
                outputSingleScan(dq,[sign sign sign 0 0]);
            end
        else
            outputSingleScan(dq,[sign sign sign 0]);
        end
    end

    function result = pickNext(result,trnum,thiscond)
        result.gratingInfo.Orientation(trnum) = thiscond(1);
        result.gratingInfo.Size(trnum) = thiscond(2);
        result.gratingInfo.tFreq(trnum) = thiscond(3);
        result.gratingInfo.spFreq(trnum) = thiscond(4);
        result.gratingInfo.Contrast(trnum) = thiscond(5);
        result.gratingInfo.PositionInd(trnum) = thiscond(6);
        result.gratingInfo.PositionX(trnum) = result.position(thiscond(6),1);
        result.gratingInfo.PositionY(trnum) = result.position(thiscond(6),2);
    end

    function thisstim = getStim(gratingInfo,trnum)
        bin = (gratingInfo.widthLUT(:,1) == gratingInfo.Size(trnum));
        thisstim.thiswidth = gratingInfo.widthLUT(bin,2);
        thisstim.thisdeg = gratingInfo.Orientation(trnum);
        thisstim.thissize = gratingInfo.Size(trnum);
        thisstim.thisspeed = gratingInfo.tFreq(trnum);
        thisstim.thisfreq = gratingInfo.spFreq(trnum);
        thisstim.thiscontrast = gratingInfo.Contrast(trnum);
        thisstim.thispositionind = gratingInfo.PositionInd(trnum);
        thisstim.thisx = gratingInfo.PositionX(trnum);
        thisstim.thisy = gratingInfo.PositionY(trnum);
        thisstim.trnum = trnum;
    end
    
%     function sendPulseTrain(pulseDQ, pulseLine, nPulses, pauseTime)
%         %%tells the daq what was displayed
%         blank = zeros(1, size(pulseDQ.Channels,2));
%         on = blank;
%         on(pulseLine) = 1;
%         for pulseI = 1:nPulses
%             outputSingleScan(pulseDQ, blank);
%             pause(pauseTime)
%             outputSingleScan(pulseDQ, on);
%         end
%         outputSingleScan(pulseDQ, blank);
%     end
    
    function cleanup_and_quit()
        ShowCursor; Screen('CloseAll');
        if result.do_msock
            msclose(sock);
        end
        
        assignin('base', 'gratingResult', result)
        assignin('base','wininfo',wininfo)
        
        save(fnameLocal, 'result','-v7.3');
        if result.save_remote
            save(fnameRemote, 'result');
        end
        if result.do_triggered
            stop(s0); release(s0)
        end
%         stop(dq); release(dq);
    end


%     function dq = setup_daq_fn(triggerSI)
%         dq = daq.createSession('ni');
%         addDigitalChannel(dq,'Dev2', 'Port0/Line1', 'OutputOnly'); %stim on indicator to master
%         addDigitalChannel(dq,'Dev2', 'Port0/Line4', 'OutputOnly'); %stim on indicator to SI
%         addDigitalChannel(dq,'Dev2', 'Port0/Line5', 'OutputOnly'); %unused trig line to master
%         addDigitalChannel(dq,'Dev2', 'Port0/Line3', 'OutputOnly'); % pulsing info to master
%         if triggerSI
%             addDigitalChannel(dq,'Dev2', 'Port0/Line2', 'OutputOnly'); %trig to SI
%         end
%     end

end