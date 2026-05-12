%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/SIcalibration.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function SIcalibration
%%
mesoholo_setup();

disp('establishing socket connection with Holo Comp')
holoIP = '128.32.177.162';% '128.32.173.99';
HoloSocket = msconnect(holoIP,3044);

invar=[];
while ~strcmp(invar,'A');
    invar = msrecv(HoloSocket,0.1);
    disp('Not Recieved')
end
disp('Recieved')

sendVar ='B';
mssend(HoloSocket,sendVar);
disp('Input from Holo Computer confirmed');

%%%
hSI = evalin('base','hSI');
global autoCalibPlaneToUse

autoCalibPlaneToUse = 0; % Changed this to 0 from 5 on 3/8/2020

hSI.hBeams.pzAdjust = 1; % Changed this 0 on 3/3/20 because nothing showed up on frames
% hSI.hBeams.pzCustom= {@autoCalibSIPowerFun} ;

hSI.hFastZ.userZs = [autoCalibPlaneToUse]; % Changed from [0 acpts] on 3/3/20 because that was a weird thing to do
hSI.hFastZ.numVolumes = 10000;
hSI.hFastZ.enable =1;

hSI.extTrigEnable =0;


% hSI.startGrab();
%
% hSI.abort();
%% skip this section when doing holeburn step of the calibration
disp('Waiting for cue from HoloComp')
go =1;
while go;
    pause(0.1);
    invar =msrecv(HoloSocket,0.1);
    if ~isempty(invar) && ~ischar(invar)
        fprintf(['Update Z Plane ' num2str(invar(1)) ' ']);
        autoCalibPlaneToUse = invar(1);
        
        
        %         disp('Grab')
        %         hSI.acqState
        %
        %         hSI.startGrab();
        %         hSI.acqState
        if invar(2)==0
            hSI.abort();
            disp('Aborted')
        elseif invar(2)==1
            
            
            if strcmpi(hSI.acqState,'idle')
%                 hSI.hBeams.pzCustom= {@autoCalibSIPowerFun} ;
                
                if invar(1)==0
                    hSI.hFastZ.userZs = [0]; % See note above, also changed from 5 to 0 on 3/8/2020
                else
                    hSI.hFastZ.userZs = [autoCalibPlaneToUse]; % See note above
                end
                hSI.startGrab();
                disp('Started')
            else
                hSI.abort();
                hSI.hBeams.pzAdjust = 1; % Changed this 0 on 3/3/20 because nothing showed up on frames
%                 hSI.hBeams.pzCustom= {@autoCalibSIPowerFun} ;
                
                if invar(1)==0
                    hSI.hFastZ.userZs = [0]; % See note above, also changed from 50 to 0 on 3/8/2020
                else
                    hSI.hFastZ.userZs = [autoCalibPlaneToUse]; % See note above
                end
                hSI.startGrab();
                disp('restarted')
            end
        else
            disp('Unrecognized Command')
        end
        
        
        mssend(HoloSocket,'gotit');

        % pause(1)
        %         if invar(2)
        %             hSI.startGrab();
        %         else
        %            hSI.abort();
        %         end
    end
    
    if strcmp(invar,'end')
        disp('end kthx');
        go=0;
        mssend(HoloSocket,'kthx');
        hSI.abort();
    end
end

%% Holeburns
disp('Waiting for Auto Command from HoloComp')
go =1;

invar =msrecv(HoloSocket,0.1);
while ~isempty(invar)
    invar =msrecv(HoloSocket,0.1);
end

while go;
     pause(0.1);
    invar =msrecv(HoloSocket,0.1);
 if ~isempty(invar) 
     if strcmp(invar,'end')
        disp('end kthx');
        go=0;
        mssend(HoloSocket,'kthx');
        hSI.abort();
     else
         disp('Eval Command Received')
         try
         out = eval(invar);
         catch
             out='No Output';
             try
                 eval(invar);
             catch
                 out='Eval Error';
             end
         end
         if isempty(out)
             out='-';
         end
         disp(out)
         mssend(HoloSocket,out);
     end
 end
end


