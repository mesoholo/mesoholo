%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/visual_stim/run_cmnoise_uday_notrigger.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function run_cmnoise_uday_notrigger(varargin)
%%% I am a full-screen noise stimulus to generate lots of activity hopefully.
%%% DEFAULT BEHAVIOR -> no tiggers, just play a cmn movie, 10 times, 10
%%% secs each, with 3 sec between trials)
%%% Common use to trigger scan image...
%%% run_contrast_modulated_noise('trigger_SI',1)
% Screen('Preference', 'SkipSyncTests', 1)
p = inputParser;
p.addParameter('animalid','MU76_2');
p.addParameter('depth','180');
p.addParameter('repetitions',10); % how many times the stimulus appears
p.addParameter('stimduration',54); % duration of each stimulus, 100 seconds
p.addParameter('isipre',3); % 10 is OK for 100 s duration for ffts (takes ~8)
p.addParameter('isipost',3); % 10 is OK for 100 s duration for ffts (takes ~8)
DScreen = 9; %%%% IMP SET THIS
p.addParameter('DScreen',DScreen);
ssc = load('sizeScaleCalib.mat');
sscfit = polyfitn([ssc.dscreen,ssc.actdeg],ssc.askdeg,2);
szfull = floor(2*atan2(15/2,DScreen)*180/pi)-1;
p.addParameter('sscfit',sscfit);
p.addParameter('VertScreenSize',15);
p.addParameter('HorzScreenSize',20);
szfull = 2*atan2(15/2,DScreen)*180/pi;
p.addParameter('fullscreen',1);
p.addParameter('sFreqs',0.03); % cyc/vis deg
p.addParameter('tFreqs',3);
p.addParameter('contrast_list',[1]); % contrast sigma, default is 0.5
p.addParameter('position',[0,0]);
p.addParameter('save_remote',0);
p.addParameter('do_triggered',0); % have me triggered by DAQ, default behavior is to run w/o trigger or being triggered
p.addParameter('trigger_SI',1); % use me to trigger scan image (set to 1)
p.addParameter('interleave',0); % used to interleave trials with no visual stimulus, defaults to 0, current pretty hacky as it still generates the stimulus
p.addParameter('random_mov',1); % TRUE = play a random movie every time (dont repeat) this generates movies on the fly, consider FALSE for performance
p.addParameter('movtype',3.5); %movtype = 0 does not modulate over time
p.addParameter('oscbarwidth0',10); %width of oscillating moving bar
p.addParameter('contrast_period',9); % for cmod noise, contrast cycles through every this seconds
p.addParameter('rcontrast_window',120); % for random cmod noise, the window in # frames for which one random contrast is used. Must divide into total # frames, so nice round #.
p.parse(varargin{:});

result = p.Results;
result.oscbarwidth = round(polyvaln(result.sscfit,...
    [result.DScreen,result.oscbarwidth0]));

mesoholo_setup();
visPath = getenv("MESOHOLO_VIS_PATH");
if strlength(visPath) > 0
    addpath(genpath(char(visPath)));
end
d = configure_mcc_daq;

if result.repetitions < numel(result.contrast_list)
    warning('The trial number (repetitions) is set to less than the number of contrasts requested. Are you sure you want to continue?')
    warn = input('Press q to quit or any other key to continue...','s');
    if warn == 'q'
        return
    end
end               

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
Screen('Preference', 'SkipSyncTests', 1)
wininfo = gen_wininfo_uday(result);
assignin('base','wininfo',wininfo)

result.image_mag = 10;
result.dispInfo.xRes  =  wininfo.xRes;
result.dispInfo.yRes  =  wininfo.yRes;
result.dispInfo.DScreen  =  result.DScreen;
result.dispInfo.VertScreenSize  =  result.VertScreenSize;

% set some stim parameters, including whether the stim is gonna fit
result.movieDurationFrames = ...
    round(result.stimduration * wininfo.frameRate); %stim duration is in seconds

%start by displaying time number of stims, wait for user input 
Screen('DrawTexture',wininfo.w, wininfo.BG);
Screen('TextFont',wininfo.w, 'Courier New');
Screen('TextSize',wininfo.w, 14);
Screen('TextStyle', wininfo.w, 1+2);
Screen('DrawText', wininfo.w, strcat(...
    num2str(result.repetitions),' Repeats__',...
    num2str(result.repetitions*(result.isipre+result.stimduration+result.isipost)/60),...
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

if(result.movtype==3.5 || result.movtype==3.25)
    dirflags = ones(result.repetitions,1);
    dirflags(1:floor(result.repetitions/2))= 0;
    dirflags = dirflags(randperm(result.repetitions)); %%%% TEMP set to one dir 0!!!!
end

%begin!
result.starttime  =  datestr(now);
t0  =  GetSecs;

% DaqDOut(d,0,0);
% DaqDOut(d,0,1);
% DaqDOut(d,0,0);

%%start either the triggered loop or non-triggered loop
result.tr_num = 0; 
if ~result.do_triggered % if trigger SI
    for istimNT=1:result.repetitions % don't name it istim bc that's used by the triggered
        if ~did_you_quit()
             if result.trigger_SI %send do pulse to only SI
%                 sendTTLFn(dq, 1, result.trigger_SI,1);
%                 sendTTLFn(dq, 0, result.trigger_SI,1);
                DaqDOut(d,0,0);
                DaqDOut(d,0,1);
                tic
                disp(['Sent FileStart Marker for trial ',...
                    num2str(istimNT)])

             end
             trialstart = GetSecs-t0;
             result.tr_num = result.tr_num+1;

                 if result.random_mov || result.tr_num > 1 % possible bug... should this be &&, or rather?
                     if(result.movtype == 3.5 || result.movtype==3.25)
                         result.dirflag = dirflags(istimNT);
                     end
                     result = get_movie_stim(result);
                 end
                 
                 result = deliver_stim(result,wininfo,trialstart);
                
%                 DaqDOut(d,0,0);
%                 toc
%                 disp('Sent FileStop Marker')
%                 DaqDOut(d,0,4);
%                 disp('Sent NextFile Marker')
        else
            break
        end
    end
    DaqDOut(d,0,0);
%     DaqDOut(d,0,1);
else
    % generate the first stim
    result.tr_num = 1;
    result = get_movie_stim(result);
    % now setup daq stuff
    s0 = daq.createSession('ni');
    %s0.addAnalogOutputChannel('Dev2',1,'Voltage');    
    [~,~] = s0.addAnalogInputChannel('Dev2',2,'Voltage');
    addTriggerConnection(s0,'external','Dev2/PFI1','StartTrigger');
    s0.TriggersPerRun = 1000; 
    s0.ExternalTriggerTimeout = 50;
    s0.NumberOfScans=2;
    lh = addlistener(s0,'DataAvailable',@(src,event) trigger_callback());
    try
        s0.startForeground();
    catch
        disp('Timed Out!');
    end
end


stopFn();
    
%%%%% ALL THE INNER FXNS %%%%%
    
    function trigger_callback()
        user_quit = did_you_quit();
        if ~user_quit
            result.timestamp(result.tr_num) = GetSecs-t0; %not as precise as the flip
            %time used in non-triggered version, but hopefully good enough
            display_grating(wininfo,result);
            
            sendPulseTrain(4,result.contrast_idx,.01);%recently added 10/3/19

            result.tr_num = result.tr_num + 1;
            
% %             save(fnameLocal, 'result')
% 
            if result.random_mov   
                result = get_movie_stim(result);
            end
        else
            cleanup_and_quit()
        end
    end

% function sendPulseTrain(pulseLine, nPulses, pauseTime)
%         %%tells the daq what was displayed
%         blank = zeros(1, size(pulseDQ.Channels,2));
%         on = blank;
%         on(pulseLine) = 1;
%         for pulseI = 1:nPulses
% %             outputSingleScan(pulseDQ, blank);
%             pause(pauseTime)
% %             outputSingleScan(pulseDQ, on);
%         end
% %         outputSingleScan(pulseDQ, blank);
%     end

    function display_grating(wininfo, thisstim)
        
        if ~result.interleave || rem(result.tr_num,2)==0
            % default function
            % so if interleave is false or the trial number is even
            
%             sendTTLfn(1, result.trigger_SI, 0) %put stim on indicators high

            %WRITE THE THING THAT DISPLAYS IMAGES
            for itex = 1:thisstim.movieDurationFrames
                Screen('DrawTexture', wininfo.w, thisstim.tex(itex), [0 0 128 128], [0 0 1280 1280]);
%                 Screen('DrawTexture', wininfo.w, thisstim.tex(itex));
                Screen('Flip', wininfo.w);
            end

%             sendTTLfn(0, result.trigger_SI, 0) %put stim on indicators low

            Screen('DrawTexture',wininfo.w,wininfo.BG); Screen('Flip', wininfo.w);
            Screen('Close',thisstim.tex(:));
            
        else
            % if interleave is true and trial number is odd
            % sendTTLfn(dq, 1, result.trigger_SI, 0) %removed stim
            % indicators for blank trials
            for itex = 1:thisstim.movieDurationFrames
                Screen('DrawTexture', wininfo.w, wininfo.BG);
                Screen('Flip', wininfo.w);
            end
            % sendTTLfn(dq, 0, result.trigger_SI, 0) % removed stim
            % indicators for blank trials, ask hayley if this is the
            % appropriate way
            
            % this occurs after the stim is over
            Screen('DrawTexture',wininfo.w,wininfo.BG); Screen('Flip', wininfo.w);
            Screen('Close',thisstim.tex(:));
 
        end     
    end

    function result = deliver_stim(result,wininfo,trialstart)        
        WaitSecs(max(0, result.isipre-((GetSecs-t0)-trialstart)));
        
        % last flip before movie starts
        Screen('DrawTexture',wininfo.w,wininfo.BG);
        fliptime  =  Screen('Flip', wininfo.w);
        result.timestamp(result.tr_num)  =  fliptime - t0;
        
        stimstart  =  GetSecs-t0;

        display_grating(wininfo, result);
        WaitSecs(result.isipost);
    end

    function sendTTLfn(sign,trigSI,trig)
        %%either triggers SI before the beginning of a stim on time
        %%or indicates to daq/SI that stim went on 
        if trigSI
            if trig
%                 outputSingleScan([0 0 0 0 sign]);
            else
%                 outputSingleScan([sign sign sign 0 0]);
            end
        else
%             outputSingleScan([sign sign sign 0]);
        end
    end
    
    function cleanup_and_quit()
        ShowCursor; Screen('CloseAll');
        if result.do_msock
            msclose(sock);
        end
        %TODO: remove this
        assignin('base', 'noiseResult', result)
        assignin('base','wininfo',wininfo)
        
        save(fnameLocal, 'result', '-v7.3');
        if result.save_remote
            save(fnameRemote, 'result');
        end
        if result.do_triggered
            stop(s0); release(s0)
        end
%         stop(dq); release(dq);
        %clear % added this to clear out ffts and other vars/arrays, might be clogging up presentation
    end


    function dq = setup_daq_fn(triggerSI)
%         dq = daq.createSession('ni');
%         addDigitalChannel(dq,'Dev2', 'Port0/Line1', 'OutputOnly'); %stim on indicator to master
%         addDigitalChannel(dq,'Dev2', 'Port0/Line4', 'OutputOnly'); %stim on indicator to SI
%         addDigitalChannel(dq,'Dev2', 'Port0/Line5', 'OutputOnly'); %unused trig line to master
%         addDigitalChannel(dq,'Dev2', 'Port0/Line3', 'OutputOnly'); % pulsing info to master
%         if triggerSI
%             addDigitalChannel(dq,'Dev2', 'Port0/Line2', 'OutputOnly'); %trig to SI
%         end
    end

    function result = get_movie_stim(result)
%         tic
        result.contrast = result.contrast_list(randperm(numel(result.contrast_list),1));
        result.contrast_idx = find(result.contrast_list == result.contrast,1);
       % disp(['contrast requested: ', num2str(result.contrast)])
        result.moviedata{result.tr_num} = generateNoise_xyt_uday(result.sFreqs, result.tFreqs, result.stimduration, wininfo, result, result.movtype);
%        toc
       result.contrasts_by_trial(result.tr_num) = result.contrast;
        
                   % result.contrast_used(end+1) = result.contrast;

        
        for f = 1:size(result.moviedata{result.tr_num},3)
            result.tex(f) = Screen('MakeTexture',wininfo.w, result.moviedata{result.tr_num}(:,:,f));
        end
    end

end