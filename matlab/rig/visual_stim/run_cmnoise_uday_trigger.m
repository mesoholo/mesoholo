function run_cmnoise_uday_trigger(varargin)
%%% I am a full-screen noise stimulus to generate lots of activity hopefully.
%%% DEFAULT BEHAVIOR -> no tiggers, just play a cmn movie, 10 times, 10
%%% secs each, with 3 sec between trials)
%%% Common use to trigger scan image...
%%% run_contrast_modulated_noise('trigger_SI',1)
p = inputParser;
p.addParameter('animalid','MU76_2');
p.addParameter('depth','180');
p.addParameter('repetitions',50); % how many times the stimulus appears
p.addParameter('stimduration',0.5); % duration of each stimulus, 100 seconds
p.addParameter('isipre',2.5); % 10 is OK for 100 s duration for ffts (takes ~8)
p.addParameter('isipost',2); % 10 is OK for 100 s duration for ffts (takes ~8)
DScreen = 8; %%%% IMP SET THIS
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
p.addParameter('contrast_list',[0.001 0.05 0.1 0.25 1]); % [0 0.1 0.2 0.4 1]
%[0 0.05 0.1 0.15 0.25 0.4 0.6 1]
p.addParameter('position',[0,0]);
p.addParameter('save_remote',0);
p.addParameter('do_triggered',0); % have me triggered by DAQ, default behavior is to run w/o trigger or being triggered
p.addParameter('trigger_SI',1); % use me to trigger scan image (set to 1)
p.addParameter('interleave',0); % used to interleave trials with no visual stimulus, defaults to 0, current pretty hacky as it still generates the stimulus
p.addParameter('random_mov',0); % TRUE = play a random movie every time (dont repeat) this generates movies on the fly, consider FALSE for performance
p.addParameter('movtype',0); %movtype = 0 does not modulate over time
p.addParameter('oscbarwidth',10); %width of oscillating moving bar
p.addParameter('contrast_period',9); % for cmod noise, contrast cycles through every this seconds
p.addParameter('rcontrast_window',120); % for random cmod noise, the window in # frames for which one random contrast is used. Must divide into total # frames, so nice round #.
p.parse(varargin{:});

result = p.Results;

addpath(genpath('C:/Users/scanimage/Documents/MATLAB/FrankenRigVisCode/GitHub/msocket/'))
d = configure_mcc_daq;

% ydayResult = load('E:\Uday\StimData\231115\MU46_1\MU46_1_200_002.mat');
% global ydaym1
% ydaym1 = ydayResult.result.moviedata{1};

% if result.repetitions < numel(result.contrast_list)
%     warning('The trial number (repetitions) is set to less than the number of contrasts requested. Are you sure you want to continue?')
%     warn = input('Press q to quit or any other key to continue...','s');
%     if warn == 'q'
%         return
%     end
% end               

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
% Screen('Preference', 'SkipSyncTests', 1)
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

if(result.movtype==3.5)
    dirflags = ones(result.repetitions,1);
    dirflags(1:floor(result.repetitions/2))= 0;
    dirflags = dirflags(randperm(result.repetitions));
else
    % create all stimulus conditions from the single parameter vectors
    nConds  =  [length(result.tFreqs) length(result.sFreqs) length(result.contrast_list)];
    result.allConds  =  prod(nConds);
    result.conds  =  makeAllCombos(result.tFreqs,result.sFreqs,result.contrast_list);
    [noiseInfo.Contrast,noiseInfo.spFreq,noiseInfo.tFreq] = ...
        deal(zeros(1,result.allConds*result.repetitions));
    stimParams = [];
    temp = repmat([1:result.allConds],1,result.repetitions);
    theseinds = temp(randperm(result.allConds*result.repetitions)); %randperm(result.allConds);
    result.theseconds = result.conds(:,theseinds);
    %%%% Hacky buffer 5 extra trials so code doesn't crash if
    %%%% missing/miscalculating condition received
    result.padbuffer = 10; % number of buffer trials per holo condition
    result.theseconds = [result.theseconds,repmat(result.conds(:,1),[1,result.padbuffer])];
    %%%%
    result.ntrials = size(result.theseconds,2)-result.padbuffer;
    stimParams = [stimParams result.theseconds];
end

%begin!
result.starttime  =  datestr(now);
t0  =  GetSecs;

ops.channel = 8;
ops.range = [1];
ops.verbose = 0;
holowait = 100;
temp = 0;
vcalib = load('condVcalib.mat');
firstflag = 1;
disp('Started waiting for daq input ...')
while true
    d = configure_mcc_daq;
    tic;
    v=[0;0];
    temp(temp~=0) = 0;
    if(toc>=holowait)
        disp('Done, no input for a while.')
        cleanup_and_quit();
    end
    while (toc<holowait)
        v = DaqAIn(d,ops.channel,ops.range);
        if(~isempty(v))
            temp = [temp;v(:,1)];
            if(~all(abs((temp))<0.05) & abs(temp(end)-temp(1))<0.05)
                break;
            end 
        end
    end
    pulseval = mean(temp(find(abs(temp)>0.05)));
    [~,pulseind] = min(abs(pulseval-vcalib.ainV));
    condval = vcalib.condvals(pulseind);
    if(condval==0)
        disp('Done, received null condition')
        break;
    end
    if(condval>=1 & firstflag)
        result.nholoconds = condval;
        result.alltheseconds = repmat(result.theseconds,[1,1,result.nholoconds]);
        result.tr_num = zeros(result.nholoconds,1);
        disp(['Received nholoconds = ',num2str(result.nholoconds)])
    end
%%start either the triggered loop or non-triggered loop
if ~result.do_triggered & condval>=1 & ~firstflag% if trigger SI
    istimNT = result.tr_num(condval)+1;
    if(istimNT > result.ntrials)
        if(condval>1)
            condval = condval-1;
        else
            condval = condval+1;
        end
    end
    disp(['Running trial ',num2str(istimNT),' for holo condition ',num2str(condval),...
        ', ',num2str(sum(result.tr_num)+1),'th trial overall'])
    if(~mod(sum(result.tr_num)+1,100))
        assignin('base','runningResult', result)
        pause(0.01)
    end
        if ~did_you_quit()
             if result.trigger_SI %send do pulse to only SI
%                 sendTTLFn(dq, 1, result.trigger_SI,1);
%                 sendTTLFn(dq, 0, result.trigger_SI,1);
                DaqDOut(d,0,0);
                DaqDOut(d,0,1);
                tic
                disp('Sent FileStart Marker')

             end
             trialstart = GetSecs-t0;
             result.tr_num(condval) = result.tr_num(condval)+1;
             result.cond_val = condval;

%                  if result.random_mov | result.tr_num > 1 % possible bug... should this be &&, or rather?
                     if(result.movtype == 3.5) result.dirflag = dirflags(istimNT); 
                     else
                         result.tFreq = result.alltheseconds(1,istimNT,condval);
                         result.sFreq = result.alltheseconds(2,istimNT,condval);
                         result.contrast = result.alltheseconds(3,istimNT,condval);
                     end
                     result = get_movie_stim(result);
%                  end
                 
                 result = deliver_stim(result,wininfo,trialstart);
                
%                 DaqDOut(d,0,0);
%                 toc
%                 disp('Sent FileStop Marker')
%                 DaqDOut(d,0,4);
%                 disp('Sent NextFile Marker')
        else
            break
        end
    DaqDOut(d,0,0);
%     DaqDOut(d,0,1);
end
firstflag = 0;
end

stopFn();
    
%%%%% ALL THE INNER FXNS %%%%%
    
    function trigger_callback()
        user_quit = did_you_quit();
        if ~user_quit
            result.timestamp(result.tr_num(result.cond_val),result.cond_val) = GetSecs-t0; %not as precise as the flip
            %time used in non-triggered version, but hopefully good enough
            display_grating(wininfo,result);
            
            sendPulseTrain(4,result.contrast_idx,.01);%recently added 10/3/19

            result.tr_num(result.cond_val) = result.tr_num(result.cond_val) + 1;
            
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
        
        if ~result.interleave || rem(result.tr_num(result.cond_val),2)==0
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
        result.timestamp(result.tr_num(result.cond_val),result.cond_val)  =  fliptime - t0;
        
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
%         result.contrast = result.contrast_list(randperm(numel(result.contrast_list),1));
        result.contrast_idx = find(result.contrast_list == result.contrast,1);
       % disp(['contrast requested: ', num2str(result.contrast)])
       if(isfield(result,'contrasts_by_trial') & ~result.random_mov)
           %%%% Same frozen stim for all contrasts
           imraw = double(result.firstmovie);
           imraw = (imraw-1)/255;
           imraw = imraw*result.firstcontrast;
           immean = mean(imraw(:));
           immax = std(imraw(:))/result.contrast;
           immin = -1*immax;
           imscaled = (imraw - immin-immean) / (immax - immin);
           result.moviedata{result.tr_num(result.cond_val),result.cond_val} = ...
               uint8(floor(imscaled*255)+1);
%            %%%% Different frozen stim per contrast
%            contrasts_shown = result.contrasts_by_trial(:);
%            times_shown = result.timestamp(:);
%            [~,trialorder] = sort(times_shown,'ascend');
%            contrasts_shown = contrasts_shown(trialorder);
%            tempinds = find(contrasts_shown==result.contrast);
%            if(~isempty(tempinds))
%                tempind = tempinds(1);
%                result.moviedata{result.tr_num(result.cond_val),result.cond_val} = ...
%                    result.moviedata{result.contrasts_by_trial==contrasts_shown(tempind)};
%            else
%                result.moviedata{result.tr_num(result.cond_val),result.cond_val} = ...
%                    generateNoise_xyt_uday(result.sFreq, result.tFreq, result.stimduration, wininfo, result, result.movtype,0);
%            end
       else
%            result.moviedata{result.tr_num(result.cond_val),result.cond_val} = ydaym1;
           result.moviedata{result.tr_num(result.cond_val),result.cond_val} = ...
               generateNoise_xyt_uday(result.sFreq, result.tFreq, result.stimduration, wininfo, result, result.movtype,0);
           result.firstmovie = result.moviedata{result.tr_num(result.cond_val),result.cond_val};
           result.firstcontrast = result.contrast;
       end
%        toc
       result.contrasts_by_trial(result.tr_num(result.cond_val),result.cond_val) = result.contrast;
        
                   % result.contrast_used(end+1) = result.contrast;

        
        for f = 1:size(result.moviedata{result.tr_num(result.cond_val),result.cond_val},3)
            result.tex(f) = Screen('MakeTexture',wininfo.w, ...
                result.moviedata{result.tr_num(result.cond_val),result.cond_val}(:,:,f));
        end
        
    end

end