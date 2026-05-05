function alignSLMtoCamMultiTargNew_Meso_uday_v1
%alignSLMtoCamMultiTargNew_Meso_uday_v1  Full 3D calibration: ScanImage ↔ SLM ↔ Camera.
%
% Purpose
% - This is the main “calibration day” script used on the hologram computer.
% - It collects correspondences between:
%   - ScanImage / optotune coordinates (where targets should be in the imaging FOV)
%   - SLM coordinates (where the hologram is addressed)
%   - camera coordinates (Basler/ThorCam images of spots / burn patterns)
% - It then fits a calibration model (`CoC`) used by `function_SItoSLM` and
%   `function_SLMtoSI` to map between spaces for online targeting.
%
% Expected environment
% - MATLAB with required toolboxes + hardware SDKs installed (SLM, camera).
% - Access to `MESOHOLO_CALIB_PATH` containing `ActiveCalib.mat` (variable `CoC`).
% - A MATLAB msocket implementation on the path (`mslisten`, `msaccept`, `msrecv`, `mssend`).
% - This script assumes you are on the *hologram computer* and that DAQ/SI
%   machines run their companion “prep/handshake” scripts.
%
% Outputs
% - Saves a timestamped `*_Calib.mat` and updates `ActiveCalib.mat` in
%   `MESOHOLO_CALIB_PATH`. Also saves a workspace snapshot for debugging.
%
% Notes on style / provenance
% - This script evolved over years of in-rig iteration. The goal of the
%   comments/sections below is to make the intent of each stage obvious,
%   even if you don’t run this end-to-end on a different rig.

%% Close stuff
try
    function_close_sutter( Sutter );
catch
end
try
    function_stopBasCam(Setup);
catch
end
try
    [Setup.SLM ] = Function_Stop_SLM( Setup.SLM );
catch
end

% clear;close all;clc
imaqreset

%% Configuration (set these instead of editing scattered constants)
cfg = struct();

% - **Hardware selection**
cfg.useGPU = true;
cfg.useThorCam = false;          % false -> Basler path (default)
cfg.sutterPort = 'COM6';

% - **Camera acquisition defaults**
cfg.maxFramesPerAcquire = 10;    % 0 for unlimited
cfg.camExposureTime = 50000;
cfg.camGain = 1;
cfg.thorRoiX = 650:1250;
cfg.thorRoiY = 250:850;

% - **SLM sampling range (must lie inside imaging FOV)**
cfg.slmXrange = [0.33 0.67];
cfg.slmYrange = [0.33 0.67];
cfg.slmZrange = [-0.05 0.05];

% - **mSocket**
cfg.msocketListenPort = 3054;
cfg.msocketAcceptTimeoutSec = 30;

%% Pathing / repo setup
tBegin = tic;
rmpath(genpath('C:\Users\MesoSI\Desktop\FromHoloComp'))
mesoholo_setup();
% addpath(genpath('C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\'));
savepath

calibPath = getenv("MESOHOLO_CALIB_PATH");
if strlength(calibPath) == 0
    error(['MESOHOLO_CALIB_PATH is not set. ' ...
        'Point it to a folder containing ActiveCalib.mat (with variable CoC).']);
end
calibpath = fullfile(char(calibPath), 'ActiveCalib.mat');
pathToUse = [char(calibPath) filesep];

disp('done pathing')

%% Define SLM coordinate sampling range for this calibration run

% First, make sure your slm ranges are in the imaging fov.
% Use imaging zoom level that you want to use for calibration and turn focus on SI
% Run QuickSLMHolo at close to boundary coords to map out the 4 corners of
% imaging square/rectangle

slmXrange = cfg.slmXrange;
slmYrange = cfg.slmYrange;
slmZrange = cfg.slmZrange;
%slmz0 = img 0 (<10um offset), slmz+0.1=-150 above, slmz-0.1=+125 below
%20221213

%% Setup hardware interfaces (SLM, camera, sutter) and runtime parameters
disp('Setting up stuff...');

[Setup ] = function_loadparameters2();
Setup.CGHMethod=2;
Setup.GSoffset=0;
Setup.verbose =0;
Setup.useGPU = double(cfg.useGPU);

Setup.useThorCam = double(cfg.useThorCam);
Setup.maxFramesPerAcquire = cfg.maxFramesPerAcquire; % 0 for unlimited
Setup.camExposureTime = cfg.camExposureTime;
Setup.camGain = cfg.camGain;

if Setup.useGPU
    disp('Getting gpu...'); %this can sometimes take a while at initialization
    g= gpuDevice;
end

[Setup.SLM ] = Function_Stop_SLM( Setup.SLM );
[ Setup.SLM ] = Function_Start_SLM( Setup.SLM );

Setup.Sutterport ='COM6';
Setup.Sutterport = cfg.sutterPort;
if ~isempty(instrfind)
    fclose(instrfind);
    delete(instrfind);
end
try; function_close_sutter( Sutter ); end
[ Sutter ] = function_Sutter_Start( Setup );
sutterposmult = 1; %%%% Weird multiplier for our sutter, found empirically, seems linear

try Setup = function_stopBasCam(Setup); end
[Setup] = function_startBasCam(Setup);
disp('Ready')

if Setup.useThorCam
    castImg = @uint16;
    castAs = 'uint16';
    camMax = 65535;
%     Setup.xroi = 1:1920;
%     Setup.yroi = 1:1080;
    Setup.xroi = cfg.thorRoiX;
    Setup.yroi = cfg.thorRoiY;
else
    castImg = @uint8;
    castAs = 'uint8';
    camMax = 255;
end

%% look for objective in 1p or you know... have it already set up

function_BasPreview(Setup); % Exposure time is internally set here, see thorPreview


%% Make mSocket connections with DAQ/SI computers (handshake)
%initialize this section and then start the msocket on DAQ comp -
%DAQcalibration script

disp('Waiting for msocket communication From DAQ')
%then wait for a handshake
srvsock = mslisten(cfg.msocketListenPort);
masterSocket = msaccept(srvsock,cfg.msocketAcceptTimeoutSec);
msclose(srvsock);
sendVar = 'A';
mssend(masterSocket, sendVar);
%MasterIP = '128.32.177.217';
%masterSocket = msconnect(MasterIP,3002);

invar = [];

while ~strcmp(invar,'B')
    invar = msrecv(masterSocket,.5);
end
disp('communication from Master To Holo Established');


%% MSOCKET WITH SI COMPUTER
%initialize this and go to scanimage computer anr run SIcalibration script 
disp('Waiting for msocket communication to ScanImage Computer')
%then wait for a handshake
srvsock2 = mslisten(3044);
SISocket = msaccept(srvsock2,15);
msclose(srvsock2);
sendVar = 'A';
mssend(SISocket, sendVar);
%MasterIP = '128.32.177.217';
%masterSocket = msconnect(MasterIP,3002);

invar = [];

while ~strcmp(invar,'B');
    invar = msrecv(SISocket,.1);
end;
disp('communication from Master To SI Established');

%% Put all Manual Steps First so that it can be automated

%% Set Power Levels
% Exposure1P = -2; %[59 1000000] defines frame rate of Bassler [-14 0]
% BasGain = 450; % [0 12] [136 542]
% try Setup = function_stopBasCam(Setup); end
pwr = 10; %60 at 50 divided mode 3/8/2020 (150+ burns, 60 looks crisp)
%6 at 30 divided mode w/gate on 9/16/2023 (300+ burns)
burnPowerMultiplier = 50;
disp(['individual hologram power set to ' num2str(pwr) 'mW']);
%% Check Power Levels
% [Setup] = function_startBasCam(Setup,Exposure1P,BasGain);

disp('Find the spot and check if this is the right amount of power')
zslm = 0.0;
slmCoords = [0.5 0.5 zslm 1];
slmCoords = [0.45 0.45 zslm 1;...
                 0.55 0.55 zslm 1;...
                 0.45 0.55 zslm 1;...
                 0.55 0.45 zslm 1;...
                 0.5 0.5 zslm 1];
slmCoords0 = [0.5 0.5 0 1];
xyoff = 0.175;
slmCoords = [slmCoords;slmCoords0+[xyoff xyoff zslm 1;
                                    xyoff -xyoff zslm 1;
                                     -xyoff xyoff zslm 1;
                                     -xyoff -xyoff zslm 1]];
% xyoff = 0.35;
% slmCoords = [slmCoords;slmCoords0+[xyoff xyoff zslm 1;
%                                     xyoff -xyoff zslm 1;
%                                     -xyoff xyoff zslm 1;
%                                     -xyoff -xyoff zslm 1]];
% 0.9 0.1 is towards the center of the imaging plane. top left on the camera
% 0.9 0.9 is bottom left on the camera
% when scanimage fov was moved to the right, the imaging square also moved to the right on the camera
% when scanimage fov was moved to the bottom, the imaging square moved up on the camera

DEestimate = DEfromSLMCoords(slmCoords,calibpath); %
disp(['Diffraction Estimate for this spot is: ' num2str(DEestimate)])

[ Holo,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoords );

blankHolo = zeros([1920 1152]);
% Function_Feed_SLM( Setup.SLM, blankHolo);

Function_Feed_SLM( Setup.SLM, Holo);

% frame = function_BasGetFrame(Setup,10);
% BGD = uint8(mean(frame,3));
mssend(masterSocket,[pwr*size(slmCoords,1)/1000 1 1]);
function_BasPreview(Setup);
% frame = function_BasGetFrame(Setup,10);
%         frame = uint8(mean(frame,3));
%         frame =  max(frame-0*BGD,0);
%         frame = imgaussfilt(frame,2);

mssend(masterSocket,[0 1 1]);%turning off the laserpower

%% Set Power Levels(LA to remove)
% Exposure1P = -2; %[59 1000000] defines frame rate of Bassler [-14 0]
% BasGain = 450; % [0 12] [136 542]
% try Setup = function_stopBasCam(Setup); end
pwr = 5;
%60 at 50 divided mode 3/8/2020 (150+ burns, 60 looks crisp)
disp(['individual hologram power set to ' num2str(pwr) 'mW']);
%
disp('Find the spot and check if this is the right amount of power');
% slmCoordsTemp = [0.01+rand(nholos,1)*0.25 0.05+rand(nholos,1)*0.9,...
%     0.05+rand(nholos,1)*0.15 1*ones(nholos,1)];
slmCoordsTemp = [0.55 0.55 0 1];
                  
slmCoordsTemp = [0.33 0.33 0 1;...
                 0.3 0.67 0 1;...
                 0.67 0.33 0 1;...
                 0.67 0.67 0 1;...
                 0.5 0.5 0 1]; %%%% Center square to REALLY center 0-order block
%slmCoordsTemp = [0.33 0.33 0 1;...
                 %0.33 0.67 0 1;...
                 %0.67 0.33 0 1;...
                 %0.67 0.67 0 1;...
                %0.5 0.5 0 1]; %%%% Corner square to find bounds
 %slmCoordsTemp = [0.2 0.2 0 1;...
                 %0.2 0.8 0 1;...
                 %0.8 0.2 0 1;...
                 %0.8 0.8 0 1;...
                %0.5 0.5 0 1]; %%%% Custom LA
% slmCoordsTemp = [0.4,0.7,0,1;...
%                  0.6,0.7,0,1;...
%                  0.3,0.45,0,1;...
%                  0.35,0.36,0,1;...
%                  0.65,0.36,0,1;...
%                  0.7,0.45,0,1;...
%                  0.5,0.3,0,1]; %%%% SMILEY
slmCoordsTempC = [0.5, 0.4, 0,1;...
                0.525, 0.4, 0,1;...
                0.55, 0.4, 0,1;...
                0.575, 0.4, 0,1;...
                0.6, 0.4, 0,1;...
                0.625,0.4, 0,1;...
                0.65,0.4, 0,1;...
                0.475,0.4, 0,1;...
                0.45,0.4, 0,1;...
                0.425,0.4, 0,1;...
                0.4,0.4, 0,1;...
                0.375,0.4, 0,1;...
                0.35,0.4, 0,1;...
                0.65,0.425, 0,1;...
                0.65,0.45, 0,1;...
                0.65,0.475, 0,1;...
                0.65,0.5, 0,1;...
                0.65,0.525, 0,1;...
                0.65,0.55, 0,1;...
                0.65,0.575, 0,1;...
                0.65,0.6, 0,1;
                0.35,0.425, 0,1;...
                0.35,0.45, 0,1;...
                0.35,0.475, 0,1;...
                0.35,0.5, 0,1;...
                0.35,0.525, 0,1;...
                0.35,0.55, 0,1;...
                0.35,0.575, 0,1;...
                0.35,0.6, 0,1];
                % 0.5,0.3,0,1]; %%%% Letter C
                
                
                
                
slmCoordsTempM = [0.5, 0.4, 0,1;...
                0.525, 0.4, 0,1;...
                0.55, 0.4, 0,1;...
                0.575, 0.4, 0,1;...
                0.6, 0.4, 0,1;...
                0.625,0.4, 0,1;...
                0.65,0.4, 0,1;...
                0.475,0.4, 0,1;...
                0.45,0.4, 0,1;...
                0.425,0.4, 0,1;...
                0.4,0.4, 0,1;...
                0.375,0.4, 0,1;...
                0.35,0.4, 0,1;...
                0.5, 0.6, 0,1;...
                0.525, 0.6, 0,1;...
                0.55, 0.6, 0,1;...
                0.575, 0.6, 0,1;...
                0.6, 0.6, 0,1;...
                0.625,0.6, 0,1;...
                0.65,0.6, 0,1;...
                0.475,0.6, 0,1;...
                0.45,0.6, 0,1;...
                0.425,0.6, 0,1;...
                0.4,0.6 0,1;...
                0.375,0.6, 0,1;...
                0.35,0.6, 0,1;...
                0.35,0.4, 0,1;...
                0.375,0.425,0,1;...
                0.4,0.45, 0,1;...
                0.425,0.475, 0,1;...
                0.45,0.5, 0,1;...
                0.425,0.525, 0,1;...
                0.4,0.55,0,1;...
                0.375,0.575, 0,1;...
                0.35,0.6, 0,1];
                % 0.5,0.3,0,1]; %%%% Letter M
                
                slmCoordsTempE = [0.5, 0.4, 0,1;...
                0.525, 0.4, 0,1;...
                0.55, 0.4, 0,1;...
                0.575, 0.4, 0,1;...
                0.6, 0.4, 0,1;...
                0.625,0.4, 0,1;...
                0.65,0.4, 0,1;...
                0.475,0.4, 0,1;...
                0.45,0.4, 0,1;...
                0.425,0.4, 0,1;...
                0.4,0.4, 0,1;...
                0.375,0.4, 0,1;...
                0.35,0.4, 0,1;...
                0.65,0.425, 0,1;...
                0.65,0.45, 0,1;...
                0.65,0.475, 0,1;...
                0.65,0.5, 0,1;...
                0.65,0.525, 0,1;...
                0.65,0.55, 0,1;...
                0.65,0.575, 0,1;...
                0.65,0.6, 0,1;
                0.5,0.425, 0,1;...
                0.5,0.45, 0,1;...
                0.5,0.475, 0,1;...
                0.5,0.5, 0,1;...
                0.5,0.525, 0,1;...
                0.5,0.55, 0,1;...
                0.5,0.575, 0,1;...
                0.5,0.6, 0,1;
                0.35,0.425, 0,1;...
                0.35,0.45, 0,1;...
                0.35,0.475, 0,1;...
                0.35,0.5, 0,1;...
                0.35,0.525, 0,1;...
                0.35,0.55, 0,1;...
                0.35,0.575, 0,1;...
                0.35,0.6, 0,1];
                % 0.5,0.3,0,1]; %%%% Letter E
                
                slmCoordsTempS = [0.5, 0.4, 0,1;...
                0.525, 0.6, 0,1;...
                0.55, 0.6, 0,1;...
                0.575, 0.6, 0,1;...
                0.6, 0.6, 0,1;...
                0.625,0.6, 0,1;...
                0.65,0.6, 0,1;...
                0.65,0.4, 0,1;...
                0.475,0.4, 0,1;...
                0.45,0.4, 0,1;...
                0.425,0.4, 0,1;...
                0.4,0.4, 0,1;...
                0.375,0.4, 0,1;...
                0.35,0.4, 0,1;...
                0.65,0.425, 0,1;...
                0.65,0.45, 0,1;...
                0.65,0.475, 0,1;...
                0.65,0.5, 0,1;...
                0.65,0.525, 0,1;...
                0.65,0.55, 0,1;...
                0.65,0.575, 0,1;...
                0.65,0.6, 0,1;
                0.5,0.425, 0,1;...
                0.5,0.45, 0,1;...
                0.5,0.475, 0,1;...
                0.5,0.5, 0,1;...
                0.5,0.525, 0,1;...
                0.5,0.55, 0,1;...
                0.5,0.575, 0,1;...
                0.5,0.6, 0,1;
                0.35,0.425, 0,1;...
                0.35,0.45, 0,1;...
                0.35,0.475, 0,1;...
                0.35,0.5, 0,1;...
                0.35,0.525, 0,1;...
                0.35,0.55, 0,1;...
                0.35,0.575, 0,1;...
                0.35,0.6, 0,1];
                % 0.5,0.3,0,1]; %%%% Letter S
                
 slmCoordsTempO = [0.5, 0.4, 0,1;...
                0.525, 0.4, 0,1;...
                0.55, 0.4, 0,1;...
                0.575, 0.4, 0,1;...
                0.6, 0.4, 0,1;...
                0.625,0.4, 0,1;...
                0.65,0.4, 0,1;...
                0.475,0.4, 0,1;...
                0.45,0.4, 0,1;...
                0.425,0.4, 0,1;...
                0.4,0.4, 0,1;...
                0.375,0.4, 0,1;...
                0.35,0.4, 0,1;...
                0.5, 0.6, 0,1;...
                0.525, 0.6, 0,1;...
                0.55, 0.6, 0,1;...
                0.575, 0.6, 0,1;...
                0.6, 0.6, 0,1;...
                0.625,0.6, 0,1;...
                0.65,0.6, 0,1;...
                0.475,0.6, 0,1;...
                0.45,0.6, 0,1;...
                0.425,0.6, 0,1;...
                0.4,0.6, 0,1;...
                0.375,0.6, 0,1;...
                0.35,0.6, 0,1;...
                0.65,0.425, 0,1;...
                0.65,0.45, 0,1;...
                0.65,0.475, 0,1;...
                0.65,0.5, 0,1;...
                0.65,0.525, 0,1;...
                0.65,0.55, 0,1;...
                0.65,0.575, 0,1;...
                0.65,0.6, 0,1;
                0.35,0.425, 0,1;...
                0.35,0.45, 0,1;...
                0.35,0.475, 0,1;...
                0.35,0.5, 0,1;...
                0.35,0.525, 0,1;...
                0.35,0.55, 0,1;...
                0.35,0.575, 0,1;...
                0.35,0.6, 0,1];
                % 0.5,0.3,0,1]; %%%% Letter O
                
                
                slmCoordsTempP = [0.5, 0.4, 0,1;...
                0.525, 0.4, 0,1;...
                0.55, 0.4, 0,1;...
                0.575, 0.4, 0,1;...
                0.6, 0.4, 0,1;...
                0.625,0.4, 0,1;...
                0.65,0.4, 0,1;...
                0.475,0.4, 0,1;...
                0.45,0.4, 0,1;...
                0.425,0.4, 0,1;...
                0.4,0.4, 0,1;...
                0.375,0.4, 0,1;...
                0.35,0.4, 0,1;...
                
                0.5,0.425, 0,1;...
                0.5,0.45, 0,1;...
                0.5,0.475, 0,1;...
                0.5,0.5, 0,1;...
                0.5,0.525, 0,1;...
                0.5,0.55, 0,1;...
                0.5,0.575, 0,1;...
                0.5,0.6, 0,1;
                0.35,0.425, 0,1;...
                0.35,0.45, 0,1;...
                0.35,0.475, 0,1;...
                0.35,0.5, 0,1;...
                0.35,0.525, 0,1;...
                0.35,0.55, 0,1;...
                0.35,0.575, 0,1;...
                
                0.475,0.6, 0,1;...
                0.45,0.6, 0,1;...
                0.425,0.6, 0,1;...
                0.4,0.6, 0,1;...
                0.375,0.6, 0,1;...
                0.35,0.6, 0,1;...
                0.35,0.6, 0,1];
                % 0.5,0.3,0,1]; %%%% Letter P
                
                
%% Lamiae letters 
%slmCoordsTemp =slmCoordsTempM;
%slmCoordsTemp = slmCoordsTemp + [0.075,0,0,0];
% slmCoordsTemp = [0.5 0.5 0.0 1];%Y 0.05 to 0.95 X0.05 to 0.9
pwr = 6;
slmCoordsTemp = [0.55 0.55 0 1];
slmCoordsTemp = [0.33 0.33 0 1;...
                 0.33 0.67 0 1;...
                 0.67 0.33 0 1;...
                 0.67 0.67 0 1;...
                 0.5 0.5 0 1]; %%%%
  slmCoordsTemp = slmCoordsTempM;
nholos = size(slmCoordsTemp,1);

% for i=1:10
%     for j=0:10
%         for k=1:5
%             slmCoordsTemp = [0.025*i 0.1*j 0.04*k 1];
%             nholos = size(slmCoordsTemp,1);
%             [ HoloTemp,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoordsTemp );
%             
%             Function_Feed_SLM( Setup.SLM, HoloTemp);
%             
%             mssend(masterSocket,[nholos*pwr/1000 1 1]);
%             pause(0.5)
%             mssend(masterSocket,[0 1 1]);
%         end
%     end
% end
% nholos = size(slmCoordsTemp,1);

% DEestimateTemp = DEfromSLMCoords(slmCoordsTemp,calibpath); %
% disp(['Diffraction Estimate for this spot is: ' num2str(DEestimateTemp)])

[ HoloTemp,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoordsTemp );

blankHolo = zeros([1920 1152]);
%Function_Feed_SLM( Setup.SLM, blankHolo);

Function_Feed_SLM( Setup.SLM, HoloTemp);

mssend(masterSocket,[nholos*pwr/1000 1 1]);

function_BasPreview(Setup);
mssend(masterSocket,[0 1 1]); 

%%LA quick save 
%% Collect background frames for signal to noise testing


[ HoloTemp,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoordsTemp );

blankHolo = zeros([1920 1152]);
%Function_Feed_SLM( Setup.SLM, blankHolo);

Function_Feed_SLM( Setup.SLM, HoloTemp);

mssend(masterSocket,[nholos*pwr/1000 1 1]);
ttemp = tic;
disp('Collecting Letter Frames');

nLetter = 10; %10 with new bas, 5 with old

letterframe = function_BasGetFrame(Setup,nLetter); %10 with new bas, 5 with old
% function_Basler_get_frames(Setup, nBackgroundFrames );

LET= mean(letterframe ,3);
meanLET = mean(single(letterframe( :)));

figure;
imagesc(LET);
%save('D:/20240913_CalibGalvoPaper/LET_S_01.mat',LET);
%save('D:/20240913_CalibGalvoPaper/LET_S_01_frame.mat',letterframe);

%% Lamiae letters 
slmCoordsTemp =slmCoordsTempM;
%slmCoordsTemp = slmCoordsTemp + [0.075,0,0,0];
% slmCoordsTemp = [0.5 0.5 0.0 1];%Y 0.05 to 0.95 X0.05 to 0.9
nholos = size(slmCoordsTemp,1);

% for i=1:10
%     for j=0:10
%         for k=1:5
%             slmCoordsTemp = [0.025*i 0.1*j 0.04*k 1];
%             nholos = size(slmCoordsTemp,1);
%             [ HoloTemp,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoordsTemp );
%             
%             Function_Feed_SLM( Setup.SLM, HoloTemp);
%             
%             mssend(masterSocket,[nholos*pwr/1000 1 1]);
%             pause(0.5)
%             mssend(masterSocket,[0 1 1]);
%         end
%     end
% end
% nholos = size(slmCoordsTemp,1);

% DEestimateTemp = DEfromSLMCoords(slmCoordsTemp,calibpath); %
% disp(['Diffraction Estimate for this spot is: ' num2str(DEestimateTemp)])

[ HoloTemp,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoordsTemp );

blankHolo = zeros([1920 1152]);
%Function_Feed_SLM( Setup.SLM, blankHolo);

Function_Feed_SLM( Setup.SLM, HoloTemp);



disp('Collecting Background Frames');

nFrames = 10;

frame = function_BasGetFrame(Setup,nFrames);% 
sutterX = -39;
sutterY = -1453;
sutterZ = -25;
ao0 = 2;
ao1 = 0;
power = 10;

Bgd = uint8(mean(frame,3));
meanBgd = mean(single(frame(:)));
save(['C:\Users\MesoSI\Desktop\Lamiae_20240429_MesoHologalvo_characterisations\letters\RighttoLeft\M_1.mat'], 'frame','sutterX','sutterY','ao0','ao1','sutterZ','power');
%% Check distribution of peak intensities

frame = function_BasGetFrame(Setup,10);% numFramesCoarseHolo added to be used elsewhere 7/16/2020 -Ian
BGD = uint8(mean(frame,3));

xslm = [linspace(0.15,0.85,4),0.5];xslm = unique(xslm);
yslm = [linspace(0.15,0.85,4),0.5];yslm = unique(yslm);
zslm = -0.0; % Set from previous section at test Sutter depth
blankHolo = zeros([1920 1152]);
temppeaks = zeros(length(xslm),length(yslm));
tempframes = zeros(size(frame,1),size(frame,2),length(xslm)*length(yslm));
count = 0;
tic
for i=1:length(xslm)
    for j=1:length(yslm)
        count = count+1;
        
        slmCoords = [ xslm(i) yslm(j) zslm 1 ]; % set
        DEestimate = DEfromSLMCoords(slmCoords,calibpath); %
        [ Holo,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoords );
        Function_Feed_SLM( Setup.SLM, Holo);
        
        mssend(masterSocket,[pwr/1000 1 1]);
        
        frame = function_BasGetFrame(Setup,5);
        frame = uint8(mean(frame,3));
        frame =  max(frame-0*BGD,0);
        frame = imgaussfilt(frame,2);
        tempframes(:,:,count) = frame;
        temppeaks(i,j) = max(frame(:));
        
        mssend(masterSocket,[0 1 1]);%turning off the laserpower
        toc
    end
end
figure;
subplot(1,2,1)
imagesc(mean(tempframes,3))
subplot(1,2,2)
imagesc(temppeaks)
colorbar
        
%% To check good burn power
function_BasPreview(Setup);

slmCoords = [0.55 0.55 0 1];
DEestimate = DEfromSLMCoords(slmCoords,calibpath); %
disp(['Diffraction Estimate for this spot is: ' num2str(DEestimate)])
[ Holo,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoords );
Function_Feed_SLM( Setup.SLM, Holo);

t=tic;
mssend(masterSocket,[burnPowerMultiplier*pwr/1000 1 1]);
while(true)
    t2=toc(t);
    if(t2>0.3)
        mssend(masterSocket,[0 1 1]);%turning off the laserpower
        break;
    end
end
function_BasPreview(Setup);
% 
% 
%% Make Sure you're centered
disp('MAKE SURE BOTH OBJECTIVE AND SUBSTAGE CAMERA ARE LEVEL')
disp('Find Focal Plane, Center and Zero the Sutter')
disp('Leave the focus at Zoom 1. at a power that is less likely to bleach (14% 25mW)') %25% 8/16/19
disp('Don''t forget to use Ultrasound Gel on the objective so it does not evaporate')
disp('Set Flyback Time to 0ms on SI Fast Z Controls') %07/27/21 Because that can ruin your SI/Opto calib step
mssend(masterSocket,[0 1 1]);

% function_Basler_Preview(Setup, 5);
function_BasPreview(Setup);

temp = input('Turn off Focus and press any key to continue');
Sutter.Reference = getPosition(Sutter.obj);


% mssend(SISocket,[0 0]);

disp('Make Sure the DAQ computer is running DAQcalibration and the SI computer running SIcalibration');
disp('Make sure both lasers are on and the shutters open')
disp('Scanimage should be idle, nearly in plane with focus. and with the gain set high enough to see most of the FOV without saturating')


position = Sutter.Reference;
position(3) = position(3) + sutterposmult*100;
moveTime=moveTo(Sutter.obj,position);
disp('testing the sutter double check that it moved to reference +100');
temp = input('Ready to go (Press any key to continue)');

position = Sutter.Reference;
moveTime=moveTo(Sutter.obj,position);

tManual = toc(tBegin);
% this section is the last manual step. can run the following sections overnight
% note, holeburn step needs PMT to be on


%% Create a random set of holograms or use flag to reload
disp('First step Acquire Holograms')
reloadHolos = 0;
tSingleCompile = tic;
 
if ~reloadHolos
    disp('Generating New Holograms...')
    disp('Everything after this should be automated so sitback and enjoy')
    
    npts = 420; %420 previous.You can almost get through 750 with water before it evaporates.
    
    slmCoords=zeros(4,npts);
     for i =1:npts
         slmCoords(:,i) = [...
             rand*(slmXrange(2)-slmXrange(1))+slmXrange(1),...
             rand*(slmYrange(2)-slmYrange(1))+slmYrange(1),...
             rand*(slmZrange(2)-slmZrange(1))+slmZrange(1),...
             1];
     end
        %[slmCoordx,slmCoordy,slmCoordz] = ndgrid(...
            %linspace(slmXrange(2),slmXrange(1),round(npts^0.4)),...
            %linspace(slmYrange(2),slmYrange(1),round(npts^0.4)),...
           % linspace(slmZrange(2),slmZrange(1),round(npts^0.2)));
        %slmCoordx = slmCoordx(:);
        %slmCoordy = slmCoordy(:);
        %slmCoordz = slmCoordz(:);
        %npts = length(slmCoordx);
        %for i =1:npts
            %slmCoords(:,i) = [slmCoordx(i),slmCoordy(i),slmCoordz(i),1];
        %end
    
    figure(1);scatter3(slmCoords(1,:),slmCoords(2,:),slmCoords(3,:),'o')
    drawnow;
    %%compile random holograms
    
    slmCoords(3,:) = round(slmCoords(3,:),3); %Added 3/15/21 by Ian for faster compute times

    
    
    disp('Compiling Holograms...')
    t = tic;
    try
        [ multiHolo,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoords' );
        multiPts = npts;
    catch
        multiPts = 100;%round(npts/2);
        disp('Could not create multi holo, trying with fewer points')
        [ multiHolo,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoords(:,1:multiPts));
    end
    fprintf(['Multi target Holo took ' num2str(toc(t)) 's\n'])
    multiCompileT = toc(t);
    
    % querry = input('do you want to check the range of the holos. turn off blasting then (1 yes, 0 no)');
    %
    % if querry ==1
    %      %%Check Range of multi holo
    %  disp('Starting with shutter closed, will display multiHolo. check that the range is appropriate on the basler');
    %   Function_Feed_SLM( Setup.SLM, multiHolo);
    %   mssend(masterSocket,[pwr/1000 1 multiPts]);
    %   function_BasPreview(Setup); %function_Basler_Preview(Setup, 5);
    % mssend(masterSocket,[0 1 1]);
    % end
    
   disp('Compiling Single Holograms')
%    disp('|------------------------------|')
%    fprintf('|')
%    tikmark = round(npts/30);
    parfor i =1:npts
        t=tic;
        fprintf(['Holo ' num2str(i)]);
        subcoordinates = slmCoords(:,i);
        
        [ Hologram,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates' );
        hololist(:,:,i)=Hologram;
        fprintf([' took ' num2str(toc(t)) 's\n']);
        
%         if mod(i,tikmark)==0
%         fprintf('.')
%         end
    end
%     fprintf('|\n')
    
    out.hololist = hololist;
    out.slmCoords = slmCoords;
    out.multiHolo = multiHolo;
    save('Hololist_meso.mat','out');
else
    disp('Reloading old Holograms...')
    try
        load('Hololist_meso.mat','out');
    catch
        [f, p] =uigetfile;
        load(fullfile(p,f),'out');
    end
    hololist = out.hololist;
    slmCoords = out.slmCoords;
    npts = size(slmCoords,2);
    multiHolo = out.multiHolo;
    figure(1);scatter3(slmCoords(1,:),slmCoords(2,:),slmCoords(3,:),'o')
    
end

disp(['Done compiling holograms. Took ' num2str(toc(tSingleCompile)) 's']);

singleCompileT = toc(tSingleCompile);

out.hololist=[];

%% Collect background frames for signal to noise testing
ttemp = tic;
disp('Collecting Background Frames');

nBackgroundFrames = 10; %10 with new bas, 5 with old

Bgdframe = function_BasGetFrame(Setup,nBackgroundFrames);% function_Basler_get_frames(Setup, nBackgroundFrames );
Bgd = castImg(mean(Bgdframe,3));
BGD = mean(Bgdframe,3);
meanBgd = mean(single(Bgdframe( :)));
stdBgd =  std(single(Bgdframe(:)));

threshHold = meanBgd+3*stdBgd;

fprintf(['3\x03c3 above mean threshold ' num2str(threshHold,4) '\n'])

%% Scan Image Planes Calibration
disp('OPEN IMAGING SHUTTER, INCREASE SI POWER, SET THE MROI TO 3X3')
disp('IN FAST Z CONTROLS, SET SCAN TYPE STEP, THEN CHECK SPECIFY ZS')
disp('UNCHECK SAVE')
disp('Begining SI Depth calibration, we do this first incase spots burn holes with holograms')
tSI=tic;

zsToUse = linspace(-100,100,5); %prev (125,325,5)%previously linspace(-100,100,5)% linspace(0,150,11) % Optotune units applied, calibration happens in this range

SIUZ = -150:10:150;% -30:5:180 linspace(-120,200,SIpts); % The steps taken by Sutter MOM while scanning focusing on slide with different opto units
SIpts = numel(SIUZ);

%generate xy grid
%this is used bc SI depths are not necessarily parallel to camera depths
%but SI just generates a sheet of illumination
%therefore, we want to check a grid of spots that we will get depth info
%for
sz = size(Bgd);
gridpts = 25;
xs = round(linspace(1,sz(1),gridpts+2));
ys = round(linspace(1,sz(2),gridpts+2));

xs([1 end])=[];
ys([1 end])=[];
range =15;

%frames to average for image (orig 6) %added 7/15/2020 -Ian
framesToAcquire = 20;

clear dimx dimy XYSI
c=0;
for i=1:gridpts
    for k=1:gridpts
        c=c+1;
        dimx(:,c) = xs(i)-range:xs(i)+range;
        dimy(:,c) = ys(k)-range:ys(k)+range;
        
        XYSI(:,c) = [xs(i) ys(k)];
    end
end

disp(['We will collect ' num2str(numel(zsToUse)) ' planes.'])

SIVals = zeros([SIpts c numel(zsToUse)]);

for k =1:numel(zsToUse)
    t=tic;
    z = zsToUse(k);
    fprintf(['Testing plane ' num2str(z) ': ']);
    
    
    mssend(SISocket,[z 1]);
    invar=[];
    while ~strcmp(invar,'gotit')
        invar = msrecv(SISocket,0.01);
    end
    
    
    dataUZSI = zeros([sz SIpts]);
    for i = 1:numel(SIUZ)
        fprintf([num2str(round(SIUZ(i))) ' ']);
        
        currentPosition = getPosition(Sutter.obj);
        position = Sutter.Reference;
        position(3) = position(3) + sutterposmult*(SIUZ(i));
        diff1 = currentPosition(3)-position(3);
        moveTime=moveTo(Sutter.obj,position);
        if i==1
            pause(1)
        else
            pause(0.1);
        end
        
        %change this part to change number of frames acquired
        % changed to 10 on 1/28/20 by WH to get better optotune calib
        % now a variable above... 7/15/2020 -Ian
        frame = function_BasGetFrame(Setup,framesToAcquire);%function_Basler_get_frames(Setup, 3 );
        %         frame = castImg(mean(frame,3));
        %         frame =  max(frame-Bgd,0);
        
        frame1 = (mean(frame,3)); %no cast to uint8
        frame2 =  max(frame1-BGD,0);
        
        
        
        frame3 = imgaussfilt(frame2,2); %removed because its binarizing for
%         some reason?
        dataUZSI(:,:,i) =  frame3;
        
%                  figure(1);
%                  subplot(1,2,1);
%                  imagesc(frame1);
%                  subplot(1,2,2);
%                  imagesc(nanmean(dataUZSI,3));
%                  drawnow
    end
    position = Sutter.Reference;
    moveTime=moveTo(Sutter.obj,position);
    pause(0.1)
    
    mssend(SISocket,[z 0]);
    invar=[];
    while ~strcmp(invar,'gotit')
        invar = msrecv(SISocket,0.01);
    end
    
    
    for i =1:c
%         temp = dataUZ(dimx(:,i),dimy(:,i),:);
%         SIVals(:,i,k) = mean(temp(:));
        SIVals(:,i,k) = squeeze(mean(mean(dataUZSI(dimx(:,i),dimy(:,i),:))));
    end
    
    
    disp([' Took ' num2str(toc(t)) 's']);
    
    
end

mssend(SISocket,'end');

disp(['Scanimage calibration done whole thing took ' num2str(toc(tSI)) 's']);
siT=toc(tSI);

%%
disp('No Longer Putting off the actual analysis until later, Just saving for now')
out.SIVals =SIVals;
out.XYSI =XYSI;
out.zsToUse =zsToUse;
out.SIUZ = SIUZ;

save('TempSIAlign.mat','out')

%% First Fits
%Extract data to fit OptotuneZ as a function of camera XYZ

disp('Fitting optotune to Camera... extracting optotune depths')
tFits=tic;

out.SIVals =SIVals;
out.XYSI =XYSI;
out.zsToUse =zsToUse;
out.SIUZ = SIUZ;

nGrids =size(SIVals,2);
nOpt = size(zsToUse,2);
fastWay = 0;

 clear SIpeakVal SIpeakDepth
fprintf('Extracting point: ')
parfor i=1:nGrids
    for k=1:nOpt
        if fastWay
            [a, b] = max(SIVals(:,i,k));
            SIpeakVal(i,k)=a;
            SIpeakDepth(i,k) =SIUZ(b);
        else
            try
                ff = fit(SIUZ', SIVals(:,i,k), 'gauss1');
                SIpeakVal(i,k) =ff.a1;
                SIpeakDepth(i,k) =ff.b1;
            catch
                SIpeakVal(i,k) = nan;
                SIpeakDepth(i,k) = nan;
            end
        end
    end
    fprintf([num2str(i) ' '])
    if mod(i,25)==0
        disp(' ')
    end
end

fprintf('\ndone\n')


b1 = SIpeakVal;
b2 = SIpeakDepth;
%%
SIpeakVal = b1;
SIpeakDepth = b2;

% thresholdModifier = 5; 1.5; %Ian add 9/13/19 orig 1.5
% excl = SIpeakVal<(threshHold/thresholdModifier);

SIThreshHold = 2*stdBgd/sqrt(nBackgroundFrames + framesToAcquire);
% SIThreshHold = 0.3;
excl = SIpeakVal<SIThreshHold | SIpeakVal > 250;%changed to reflect difference better.\
% excl = SIpeakVal<SIThreshHold;

disp([num2str(numel(SIpeakDepth)) ' points total before exclusions'])
disp([num2str(sum(excl(:))) ' points excluded b/c below threshold'])
SIpeakVal(excl)=nan;
SIpeakDepth(excl)=nan;

% excl = SIpeakVal>255;
% SIpeakVal(excl)=nan;
% SIpeakDepth(excl)=nan;

excl = SIpeakDepth<-150 | SIpeakDepth>150; %upper bound added 7/15/2020 -Ian

disp([num2str(sum(excl(:))) ' points excluded b/c too deep'])
SIpeakVal(excl)=nan;
SIpeakDepth(excl)=nan;
disp([num2str(sum(~isnan(SIpeakDepth), 'all')) ' points remaining'])


%% CamToOpt
modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
    1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;...
    2 0 1; 2 1 0; 0 2 1; 0 1 2; 1 2 0; 1 0 2;...
     2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2; ];  %XY spatial calibration model for Power interpolations
% modelterms =[0 0 0; 1 0 0; 0 1 0; ...
%     1 1 0; 2 0 0; 0 2 0];

camXYZ(1:2,:) =  repmat(XYSI,[1 nOpt]);
camXYZ(3,:) =  SIpeakDepth(:);

camPower = SIpeakVal(:);

optZ = repmat(zsToUse,[nGrids 1]);
optZ = optZ(:);

testSet = randperm(numel(optZ),50);

otherSet = ones([numel(optZ) 1]);
otherSet(testSet)=0;
otherSet = logical(otherSet);

refAsk = (camXYZ(1:3,otherSet))';
refGet = optZ(otherSet);

camToOpto =  polyfitn(refAsk,refGet,modelterms);


Ask = camXYZ(1:3,testSet)';
True = optZ(testSet);

Get = polyvaln(camToOpto,Ask);

RMS = sqrt(sum((Get-True).^2,2));
meanRMS = nanmean(RMS);

CoC.camToOpto= camToOpto;
%%fig
f201=figure(201);clf
f201.Units = 'normalized';
f201.Position = [0.05 0.05 0.25 0.45];
scatter3(camXYZ(1,:),camXYZ(2,:),camXYZ(3,:),[],camPower,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis \mum')
title('Measured Fluorescence intensity by space')
c = colorbar;
c.Label.String = 'Fluorescent Intensity';
axis square

f2 = figure(202);clf
f2.Units = 'normalized';
f2.Position = [0.05 0.45 0.5 0.45];
subplot(2,2,1)
scatter3(camXYZ(1,:),camXYZ(2,:),camXYZ(3,:),[],optZ,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis \mum')
title('Measured Optotune Level (A.U.)')
c = colorbar;
c.Label.String = 'Optotune Depth';
axis square

subplot(2,2,2)
scatter3(camXYZ(1,:),camXYZ(2,:),camXYZ(3,:),[],polyvaln(camToOpto,camXYZ(1:3,:)'),'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis \mum')
title('Estimated Optotune Level (A.U.)')
c = colorbar;
c.Label.String = 'Optotune Depth';
axis square

subplot(2,2,3)
scatter3(camXYZ(1,:),camXYZ(2,:),camXYZ(3,:),[],polyvaln(camToOpto,camXYZ(1:3,:)')-optZ,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis \mum')
title('Error (A.U.)')
c = colorbar;
c.Label.String = 'Optotune Depth';
axis square

subplot(2,2,4)
c = sqrt((polyvaln(camToOpto,camXYZ(1:3,:)')-optZ).^2);
scatter3(camXYZ(1,:),camXYZ(2,:),camXYZ(3,:),[],c,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis \mum')
title('Error RMS (A.U.)')
c = colorbar;
c.Label.String = 'Optotune Depth';
axis square

%%optZtoCam
cam2XYZ(1:2,:) =  repmat(XYSI,[1 nOpt]);
cam2XYZ(3,:) =  optZ(:);
obsZ =  SIpeakDepth(:);

testSet = randperm(numel(obsZ),50);
otherSet = ones([numel(obsZ) 1]);
otherSet(testSet)=0;
otherSet = logical(otherSet);

refAsk = (cam2XYZ(1:3,otherSet))';
refGet = obsZ(otherSet);

OptZToCam =  polyfitn(refAsk,refGet,modelterms);


Ask = cam2XYZ(1:3,testSet)';
True = obsZ(testSet);

Get = polyvaln(OptZToCam,Ask);

RMS = sqrt(sum((Get-True).^2,2));
meanRMS = nanmean(RMS);
disp(['The mean error in Optotune depth prediction is : ' num2str(meanRMS) 'um']);
disp(['The Max error is: ' num2str(max(RMS)) 'um'])

CoC.OptZToCam= OptZToCam;

out.CoC=CoC;
out.SIfitModelTerms = modelterms;
%%fig
f3 = figure(203);clf
f3.Units = 'normalized';
f3.Position = [0.5 0.45 0.5 0.45];
subplot(2,2,1)
scatter3(cam2XYZ(1,:),cam2XYZ(2,:),cam2XYZ(3,:),[],obsZ,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis Optotune Units')
title('Measured Optotune Level (A.U.)')
c = colorbar;
c.Label.String = 'Depth \mum';
axis square

subplot(2,2,2)
scatter3(cam2XYZ(1,:),cam2XYZ(2,:),cam2XYZ(3,:),[],polyvaln(OptZToCam,cam2XYZ(1:3,:)'),'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis Optotune Units')
title('Estimated Optotune Level (A.U.)')
c = colorbar;
c.Label.String = 'Depth \mum';
axis square

subplot(2,2,3)
scatter3(cam2XYZ(1,:),cam2XYZ(2,:),cam2XYZ(3,:),[],polyvaln(OptZToCam,cam2XYZ(1:3,:)')-obsZ,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis Optotune Units')
title('Error (A.U.)')
c = colorbar;
c.Label.String = 'Depth \mum';
axis square

subplot(2,2,4)
c = sqrt((polyvaln(OptZToCam,cam2XYZ(1:3,:)')-obsZ).^2);
scatter3(cam2XYZ(1,:),cam2XYZ(2,:),cam2XYZ(3,:),[],c,'filled');
ylabel('Y Axis pixels')
xlabel('X axis pixels')
zlabel('Z axis Optotune Units')
title('Error RMS (A.U.)')
c = colorbar;
c.Label.String = 'Depth \mum';
axis square

disp(['All fits took ' num2str(toc(tFits)) 's']);
fitsT = toc(tFits);

%% Coarse Data
% npts=200;

tstart=tic;%Coarse Data Timer

disp('Begining Coarse Holo spot finding')
coarsePts = 9;% %7 %9 %odd number pleaspe
coarseUZ = linspace(-100,100,coarsePts);% linspace(-100,100,coarsePts)%linspace(-50,150,coarsePts);
mssend(masterSocket,[0 1 1]);

invar='flush';
while ~isempty(invar)
    invar = msrecv(masterSocket,0.01);
end

vals = nan(coarsePts,npts);
xyLoc = nan(2,npts);

sz = size(Bgd);
sizeFactor = 1;% changed bc camera size change 7/16/2020 by Ian %will have to manually test that this is scalable by 4
newSize = sz / sizeFactor;

% dataUZ2 = castImg(zeros([newSize  numel(coarseUZ) npts]));
dataUZ2 = zeros([newSize  numel(coarseUZ) npts], castAs);
maxProjections=castImg(zeros([newSize  npts]));

range = round(16 / sizeFactor);

numFramesCoarseHolo = 5; %number of frames to collect here. added 7/16/2020 -Ian

for i = 1:numel(coarseUZ)
    fprintf(['First Pass Holo, Depth: ' num2str(coarseUZ(i)) '. Holo : '])
    t = tic;
    
    currentPosition = getPosition(Sutter.obj);
    position = Sutter.Reference;
    position(3) = position(3) + sutterposmult*(coarseUZ(i));
    diff1 = currentPosition(3)-position(3);
    moveTime=moveTo(Sutter.obj,position);
    
    if i==1
        pause(1)
    else
        pause(0.1);
    end
    
    for k=1:npts  %DIFFERENT
        fprintf([num2str(k) ' ']);
        
        if mod(k,25)==0
            fprintf('\n')
        end
        
        
        Function_Feed_SLM( Setup.SLM, hololist(:,:,k));
        
        mssend(masterSocket,[pwr/1000 1 1]);
        invar=[];
        while ~strcmp(invar,'gotit')
            invar = msrecv(masterSocket,0.01);
        end
        frame = function_BasGetFrame(Setup,numFramesCoarseHolo);% numFramesCoarseHolo added to be used elsewhere 7/16/2020 -Ian
        frame = castImg(mean(frame,3));
        
        mssend(masterSocket,[0 1 1]);
        invar=[];
        while ~strcmp(invar,'gotit')
            invar = msrecv(masterSocket,0.01);
        end
        frame =  max(frame-Bgd,0);
        frame = imgaussfilt(frame,2);
        frame = imresize(frame,newSize);
        dataUZ2(:,:,i,k) =  frame;
        
        %          figure(1);
        %          subplot(1,2,1);
        %          imagesc(frame);
        %          subplot(1,2,2);
        %          imagesc(nanmean(dataUZ,3));
        %          drawnow
    end
    fprintf(['\nPlane Took ' num2str(toc(t)) ' seconds\n'])
    
end

position = Sutter.Reference;
moveTime=moveTo(Sutter.obj,position);
pause(0.1)

%%
disp('Calculating Depths and Vals')
range=ceil(15/sizeFactor);%Should be scaled by sizeFactor, also shrunk -Ian 7/16/2020 %Range for Hologram analysis window Changed to 5 9/16/19 by Ian
for k=1:npts
    dataUZ = dataUZ2(:,:,:,k);
    mxProj = max(dataUZ,[],3);
    [ x,y ] =function_findcenter(mxProj );
    xyLoc(:,k) = [x,y]*sizeFactor;
    
    maxProjections(:,:,k)=mxProj;
    
    dimx = max((x-range),1):min((x+range),size(mxProj,1));
    dimy =  max((y-range),1):min((y+range),size(mxProj,2));
    
    thisStack = squeeze(mean(mean(dataUZ(dimx,dimy,:))));
    vals(:,k) = thisStack;
    depthIndex = find(thisStack == max(thisStack),1);
    
    fprintf(['Spot ' num2str(k) ' centered at depth ' num2str(round(coarseUZ(depthIndex)))...
        'um. Value: ' num2str(round(vals(depthIndex,k))) '\n']);
end
%     fprintf(['Took ' num2str(toc(t),2) 's\n']);

fprintf(['All Done. Total Took ' num2str(toc(tstart)) 's\n']);
coarseT = toc(tstart);

%% check peak values
figure(301)
subplot(1,2,1)
histogram(max(dataUZ2,[],[1,2,3]))
subplot(1,2,2)
imagesc(squeeze(mean(maxProjections, 3)))
hold on; plot(xyLoc(2,:),xyLoc(1,:), 'w*')
sgtitle('Histogram of coarse search peaks (actual peaks will be higher)')

%% Second pass, multi-target version

% assign search params
finePts = 11; % odd number please
fineRange = 50;

disp('Begin multi-target z search...')
multi_time = tic;

% flush the socket
flushSocket(masterSocket)

% Generate multi-target holos based off coarse search data
targ_time = tic;


[coarseVal, coarseZidx] =max(vals,[],1);
zDepthVal = coarseUZ(coarseZidx);
zdepths = unique(zDepthVal);
n_planes = numel(zdepths);

coarseInclusionThreshold = 3*stdBgd/sqrt(numFramesCoarseHolo + nBackgroundFrames); %inclusion threshold added based on frames acquired; more stringent then SI. Added 7/16/2020 -Ian
zDepthVal(coarseVal<coarseInclusionThreshold)=NaN;

xyzLoc = [xyLoc;zDepthVal]; %fix this later (?)

%slmMultiCoords = nan(4, n_targs, n_holos);
%(4,:,:) = 1;  % 4th position is weight

clear slmMultiCoords basCoords targ_list targListIndiv slmMultiCoordsIndiv tempTargList

for i=1:n_planes % this will be the number of holograms
    % index the z depth
    z = zdepths(i);
    targ_idx = find(xyzLoc(3,:)==z);
    slmMultiCoords{i} = slmCoords(:,targ_idx);
    basCoords{i} = xyzLoc(:,targ_idx);
    targ_list{i} = targ_idx;
end

for i=1:n_planes
    % get real and slm coords from coarse
    dist = pdist2(basCoords{i}',basCoords{i}');
    %             dist(find(diag(diag(dist))))=NaN;
    temp =rand(size(dist,1));
    dist(find(diag(diag(temp))))=nan;  %#ok<FNDSB>
    tempTargList = 1:numel(targ_list{i});
    iterCounter =0;
    multiHoloCounter = 0;
    keepGoing=1;
    iterationsBeforeStop =1000;
    distanceThreshold = 30; %changed from 50 on 7/15/20 bc new cam 
    size_of_holo = 8;%changed from 25 on 7/15/20 bc new cam 
    doThisOnce =0;
    slmMultiCoordsIndiv{i} =[];
    targListIndiv{i}=[];
    
    while keepGoing
        iterCounter=iterCounter+1;
        if numel(tempTargList) <= size_of_holo
            testIdx = tempTargList;
            IdxofTempTargetList = 1:numel(tempTargList);
            keepGoing =0;
            %                 elseif numel(tempTargList)==2
            %                     return
        else
            IdxofTempTargetList = randperm(numel(tempTargList),size_of_holo);
            testIdx = tempTargList(IdxofTempTargetList);
        end
        
        %test if good
        subDist = dist(testIdx,testIdx);
        if any(subDist(:)<distanceThreshold)
            good =0;
        else
            good =1;
        end
        
        %complexish
        %                 a = find(any(subDist<distanceThreshold));
        %                 toBeKilled = a(2:end);
        %                 testIdx(toBeKilled) = [];
        %                 IdxofTempTargetList(toBeKilled) = [];
        
        if good
            multiHoloCounter=multiHoloCounter+1;
            slmMultiCoordsIndiv{i}{multiHoloCounter} = slmMultiCoords{i}(:,testIdx);
            targListIndiv{i}{multiHoloCounter} = targ_list{i}(testIdx) ;
            iterCounter=0;
            tempTargList(IdxofTempTargetList)=[];
        else
            if iterCounter>iterationsBeforeStop && doThisOnce
                keepGoing=0;
            elseif iterCounter>iterationsBeforeStop
                size_of_holo=max(round(size_of_holo/2),3);
                iterCounter=0;
                doThisOnce=1;
            end
        end 
    end
end    

    % save to a struct for reference later
%     mh(i).slm = slmMultiCoords(:,:,i);
%     mh(i).real = basCoords;
%     mh(i).idx = holo_idx;
    
disp('Setting up stuff for multi-targets...');
% [Setup ] = function_loadparameters();
Setup.CGHMethod=2;
Setup.GSoffset=0;
Setup.verbose =0;
Setup.useGPU =1;

cores=2;

if cores > 1
    p =gcp('nocreate');
    if isempty(p) || ~isprop(p,'NumWorkers') || p.NumWorkers ~=cores
        delete(p);
        parpool(cores);
    end
end

% make the holos
clear slmShootCoords
holo_time = tic;
disp('Compiling holograms...')
planes = numel(slmMultiCoordsIndiv);

for i=1:planes
    pt = tic;
    holos_this_plane = numel(slmMultiCoordsIndiv{i});
    
    parfor k=1:holos_this_plane
        ht = tic;
        [ mtholo, Reconstruction, Masksg ] = function_Make_3D_SHOT_Holos(Setup,slmMultiCoordsIndiv{i}{k}');
        
        mtholo_temp(k,:,:) = mtholo;
        %slm_temp(k,:,:) = slmMultiCoordsIndiv{i}{k}
        %disp(['Holo ' num2str(k) ' of ' num2str(holos_this_plane) ' done!  Took ' num2str(toc(ht)) 's'])
    end
    multiHolos{i} = mtholo_temp; % will throw an error if size_of_holo is too large and slmMultiCoordsIndiv is empty, especially if the first plane turns up empty. Circumvent by adjusting size_of_holo according to what the cell sizes are in basCoords
    disp(['Plane ' num2str(i) ' of ' num2str(planes) ' done!  Took ' num2str(toc(pt)) 's'])
end
disp(['Done. Took ' num2str(toc(holo_time)) 's'])

% multiHolos{plane}{holo, pixel, pixel}

disp(['took ' num2str(toc(targ_time)) 's to compile multi target holos']) 

out.hololist = hololist;
out.slmCoords = slmCoords;
out.multiHolo = multiHolo;
%save('Hololist_meso_multi.mat','out');

%%
clear peakValue peakDepth peakFWHM peakFWHMxy
%%
background = function_BasGetFrame(Setup,5); % changed from 3 7/15/20 %change from 20
range = 6;
box_range = 20; % 7/15/20 changed from 50 to 20 distance threshold is set to 50, this must be less to avoid trying to fit 2 holos
disp('shootin!')
% for every  plane

for i = 1:planes %1:planes
    plane_time = tic;
    holos_this_plane = numel(slmMultiCoordsIndiv{i});
   
    disp(['Plane ' num2str(i) ' of ' num2str(planes)])
    
    % for every holo on that plane
    for j = 1:holos_this_plane
        holo_time = tic;
        disp(['Multi-target holo ' num2str(j) ' of ' num2str(holos_this_plane)])
        
        if size(slmMultiCoordsIndiv{i}{j},2) == 0 || size(slmMultiCoordsIndiv{i}{j},2) == 2 % or <3 ??
            continue
        end
        
        multi_pwr = size(slmMultiCoordsIndiv{i}{j},2) * pwr * 0.9;
        Function_Feed_SLM(Setup.SLM, multiHolos{i}(j,:,:));
        
        target_ref = targListIndiv{i}{j}(1);
        expected_z = xyzLoc(3,target_ref);
        %expected_xy = xyzLoc(1:2, target_ref);
        %expected_xyz = xyzLoc(:,target_ref);
        
        fineUZ = linspace(expected_z-fineRange,expected_z+fineRange,finePts);
        dataUZ = castImg(nan([size(Bgdframe(:,:,1))  finePts]));
        
        fprintf('Depth: ')
        
        % for every sutter z plane
        for k = 1:finePts
            fprintf([num2str(round(fineUZ(k))) ' ']);
            % move the sutter
            currentPosition = getPosition(Sutter.obj);
            position = Sutter.Reference;
            position(3) = position(3) + sutterposmult*(fineUZ(k));
            diff1 = currentPosition(3)-position(3);
            moveTime=moveTo(Sutter.obj,position);

            if i==1
                pause(1)
            else
                pause(0.1);
            end
           
            requestPower(multi_pwr,masterSocket)
            
            % grab a frame, convert to uint8
            frame = function_BasGetFrame(Setup,5); %changed from 5 on 7/15/20 %CHECK
             %CHECK  %CHECK  %CHECK
              %CHECK  %CHECK  %CHECK
            frame = castImg(mean(frame,3));
            
            % turn off the laser
            requestPower(0,masterSocket)
            
            % subtract the background and filter
            frame =  max(frame-Bgd,0);
            frame = imgaussfilt(frame,2);
            % store into dataUZ(x,y,z-plane)
            dataUZ(:,:,k) =  frame;
            dataUZ3{i}{j} = dataUZ;
            fineUZ3{i}{j} = fineUZ;
        end
        
        % move sutter back to reference
        position = Sutter.Reference;
        moveTime=moveTo(Sutter.obj,position);
        pause(0.1)
        
        % OK, now parse the basler data in expected holo spots
        %targVals = nan(numel(fineZ),n_targs);
        for targ = 1:size(slmMultiCoordsIndiv{i}{j},2)
           
            target_ref = targListIndiv{i}{j}(targ);
            expected_xyz = xyzLoc(:,target_ref);
            [x, y] = size(Bgd);
            
            targX = expected_xyz(1)-box_range:expected_xyz(1)+box_range;
            targY = expected_xyz(2)-box_range:expected_xyz(2)+box_range;

            if max(targX)>x
                targX = expected_xyz(1)-box_range:x;
            end
            if max(targY)>y
                targY = expected_xyz(2)-box_range:y;
            end
            if min(targX)<1
                targX = 1:expected_xyz(1)+box_range;
            end
            if min(targY)<1
                targY = 1:expected_xyz(2)+box_range;
            end
                  

            % catch for small boxes!!!!
             try
                % method 1 - rely on XY from first step
                targ_stack = double(squeeze(mean(mean(dataUZ(targX,targY,:)))));
                mxProj = max(dataUZ(targX,targY,:),[],3);
                [ holo_x,holo_y ] =function_findcenter(mxProj );
                xyFine{i}{j}(:,targ) = [holo_x,holo_y];
                % method 2 - mean instead of max
                
            catch
                targ_stack = nan(finePts,1);
                xyFine{i}{j}(targ) = nan;
            end
           
%            

            try
                ff = fit(fineUZ', targ_stack-min(targ_stack), 'gauss1');
                peakValue{i}{j}(targ) = ff.a1;
                peakDepth{i}{j}(targ) = ff.b1;
                peakFWHM{i}{j}(targ) = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
            catch
                disp(['Error on fit! Holo: ', num2str(j), ' Target: ', num2str(targ)])
                peakValue{i}{j}(targ) = NaN;
                peakDepth{i}{j}(targ) = NaN;
                peakFWHM{i}{j}(targ) = NaN;
            end
                      
        
        end
        
        fprintf('\n')
        disp(['Holo ' num2str(j) ' took ' num2str(toc(holo_time)) 's'])
    end
    
    disp(['Plane ' num2str(i) ' took ' num2str(toc(plane_time)) 's'])
end

fprintf(['All Done. Total Took ' num2str(toc(multi_time)) 's\n']);
multiT = toc(multi_time);


%%
%% reshape matrix of values into vectors
tIntermediateFine = tic; 

peakValueList = peakValue(:);
peakDepthList = peakDepth(:);
peakFWHMList = peakFWHM(:);

[mx, mxi] = max(vals);
% current implementation does not threshold, should be included but more
% complicated here
c=0;
clear slmXYZ basXYZ1 basVal1
% for a = 1:npts %prob works but not always 750 pts bc of exlcusings
%     c = c+1;
for i=1:planes
    %     holos_this_plane = numel(slmMultiCoordsIndiv{i});
    
    %changed to account for when it skipped asked holos bc they were too small -Ian 7/16/2020
    if numel(peakDepth)<i
        holos_this_plane = 0;
    else
        holos_this_plane = numel(peakDepth{i}); 
    end
    
    for j=1:holos_this_plane
        for targ = 1:size(slmMultiCoordsIndiv{i}{j},2)
            c = c+1;
            slmXYZ(:,c) = slmMultiCoordsIndiv{i}{j}(:,targ);
            target_ref = targListIndiv{i}{j}(targ);
            
            % approach 1
%             basXYZ1_fine(1:2,c) = xyFine{i}{j}(targ);
            basXYZ1(1:2,c) = xyzLoc(1:2,target_ref);
            basXYZ1(3,c) = peakDepth{i}{j}(targ);
            basVal1(c) = peakValue{i}{j}(targ);
            

            FWHMval(c) = peakFWHM{i}{j}(targ); %added 7/10/20 =Ian
         end
    end
end


%% Choose your favorite method of getting XYZ coords
approach = 1;
disp(['you chose approach ' num2str(approach)])
switch approach
    case 1
        basXYZ = basXYZ1;
        basVal = basVal1;
    case 2
        basXYZ = basXYZ2;
        basVal = basVal2;
end


%%

slmXYZBackup2 = slmXYZ;
basXYZBackup2 = basXYZ;
basValBackup2 = basVal;
FWHMBackup2   = FWHMval; %added 7/20/2020 -Ian

%% --- BEGIN INTERMEDIATE FITS ---- %%
%% exclude trials

slmXYZ = slmXYZBackup2;
basXYZ = basXYZBackup2;
basVal = basValBackup2;
FWHMVal = FWHMBackup2;%added 7/20/2020 -Ian

excludeTrials = all(basXYZ(1:2,:)==[1 1]'); %hayley's understanding: if bas x and y are both one, exclude this trial

excludeTrials = excludeTrials | basVal>camMax | basVal<1; %max of this camera is 255  % %CHECK %CHECK %CHECK
 %CHECK %CHECK %CHECK %CHECK %CHECK %CHECK %CHECK %CHECK %CHECK

basDimensions = size(Bgdframe);
excludeTrials = excludeTrials | basXYZ(1,:)>=basDimensions(1)-1;
excludeTrials = excludeTrials | basXYZ(2,:)>=basDimensions(2)-1;
excludeTrials = excludeTrials | basXYZ(3,:)<-200; %9/19/19 Ian Added to remove systematic low fits
excludeTrials = excludeTrials | basXYZ(3,:)>200;


excludeTrials = excludeTrials | any(isnan(basXYZ(:,:)));
excludeTrials = excludeTrials | basVal<1; %8/3 hayley add 5; Ian ammend to 1 9/13
excludeTrials = excludeTrials | basVal>(mean(basVal)+3*std(basVal)); %9/13/19 Ian Add

slmXYZBackup = slmXYZ(:,~excludeTrials);
basXYZBackup = basXYZ(:,~excludeTrials);
basValBackup = basVal(:,~excludeTrials);
FWHMValBackup = FWHMVal(~excludeTrials); % added 7/20/2020 -Ian

%%
f41=figure(41);
clf(41)
f41.Units = 'Normalized';
f41.Position = [0.05 0.4 0.5 0.5];
subplot(1,2,1)
scatter3(basXYZBackup(1,:),basXYZBackup(2,:),basXYZBackup(3,:), 50, 'k', 'Filled', 'MarkerFaceAlpha',0.5)
hold on
scatter3(xyzLoc(1,:), xyzLoc(2,:), xyzLoc(3,:), 70,  'r', 'Filled', 'MarkerFaceAlpha', 0.7)
legend('Fine','Coarse')
title('Detected basXYZs')
subplot(1,2,2)
scatter3(basXYZBackup(1,:),basXYZBackup(2,:),basXYZBackup(3,:), 75, basValBackup, 'Filled')
colorbar
colormap default
title('basXYZ and basVals (fine)')

f42=figure(42);
clf(42)
f42.Units = 'Normalized';
f42.Position = [0.05 0 0.40 0.5];
plot(basValBackup,'o')
title('basVal by trial')
xlabel('time/holo/acq num')
ylabel('pixel intensity')


%% fit SLM to Camera
%use model terms

basXYZ = basXYZBackup;
slmXYZ = slmXYZBackup;
basVal = basValBackup;

disp('Fitting SLM to Camera')
modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
    1 1 0; 1 0 1; 0 1 1 ; 1 1 1 ;...
    2 0 0; 0 2 0; 0 0 2;  ...
    2 0 1; 2 1 0; 0 2 1; 1 2 0; 0 1 2;  1 0 2; ... ];  %XY spatial calibration model for Power interpolations
    2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2;];
% modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
%     1 1 0; 1 0 1; 0 1 1 ;...
%     2 0 0; 0 2 0; 0 0 2];
reOrder = randperm(size(slmXYZ,2));
slmXYZ = slmXYZ(:,reOrder);
basXYZ = basXYZ(:,reOrder);

holdback = 15;

refAsk = (slmXYZ(1:3,1:end-holdback))';
refGet = (basXYZ(1:3,1:end-holdback))';

%  SLMtoCam = function_3DCoC(refAsk,refGet,modelterms);

errScalar = 2; %2.8;%2.5;
fignum = 121;
[SLMtoCam, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,0,fignum);
title('SLM to Cam v1')

Ask = refAsk;
True = refGet;
Get = function_Eval3DCoC(SLMtoCam,Ask);

figure(104);clf
% subplot(1,2,1)
scatter3(True(:,1),True(:,2),True(:,3),'*','k')
hold on
scatter3(Get(:,1), Get(:,2), Get(:,3),'o','r')

ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
% legend('Measured targets', 'Estimated Targets');
title({'Reference Data'; 'SLM to Camera'})

refRMS = sqrt(sum((Get-True).^2,2));
figure(105)
% subplot(1,2,2)
scatter3(True(:,1),True(:,2),True(:,3),[],refRMS,'filled');
colorbar
ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
title({'Reference Data'; 'RMS Error in position'})
caxis([0 30])


Ask = (slmXYZ(1:3,end-holdback:end))';
True = (basXYZ(1:3,end-holdback:end))';
Get = function_Eval3DCoC(SLMtoCam,Ask);

figure(101);clf
% subplot(1,3,1)
scatter3(True(:,1),True(:,2),True(:,3),'*','k')
hold on
scatter3(Get(:,1), Get(:,2), Get(:,3),'o','r')


ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
legend('Measured targets', 'Estimated Targets');
title('SLM to Camera')

RMS = sqrt(sum((Get-True).^2,2));
meanRMS = nanmean(RMS);
disp('Error based on Holdback Data...')
disp(['The RMS error: ' num2str(meanRMS) ' pixels for SLM to Camera']);

% pxPerMu = size(frame,1) / 1000; %really rough approximate of imaging size
pxPerMu = mean([1325/1000,1310/1000]);

disp(['Thats approx ' num2str(meanRMS/pxPerMu) ' um']);

xErr = sqrt(sum((Get(:,1)-True(:,1)).^2,2));
yErr = sqrt(sum((Get(:,2)-True(:,2)).^2,2));
zErr = sqrt(sum((Get(:,3)-True(:,3)).^2,2));

disp('Mean:')
disp(['X: ' num2str(mean(xErr)/pxPerMu) 'um. Y: ' num2str(mean(yErr)/pxPerMu) 'um. Z: ' num2str(mean(zErr)) 'um.']);
disp('Max:')
disp(['X: ' num2str(max(xErr)/pxPerMu) 'um. Y: ' num2str(max(yErr)/pxPerMu) 'um. Z: ' num2str(max(zErr)) 'um.']);

figure(102);
% subplot(1,3,2)
scatter3(True(:,1),True(:,2),True(:,3),[],RMS,'filled');
colorbar
ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
title('RMS Error in position')


refAsk = (basXYZ(1:3,1:end-holdback))';
refGet = (slmXYZ(1:3,1:end-holdback))';

%  camToSLM = function_3DCoC(refAsk,refGet,modelterms);

fignum = 122;
[camToSLM, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,0,fignum);
title('cam to slm v1')

Ask = (basXYZ(1:3,end-holdback:end))';
True = (slmXYZ(1:3,end-holdback:end))';
Get = function_Eval3DCoC(camToSLM,Ask);


figure(103);
% subplot(1,3,3)
scatter3(True(:,1),True(:,2),True(:,3),'*','k')
hold on
scatter3(Get(:,1), Get(:,2), Get(:,3),'o','r')

ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Depth units')
legend('Measured targets', 'Estimated Targets');
title('Camera to SLM')

% RMS = sqrt(sum((Get-True).^2,2));
% meanRMS = nanmean(RMS);
% 
% disp(['The RMS error: ' num2str(meanRMS) ' SLM units for Camera to SLM']);




CoC.camToSLM=camToSLM;
CoC.SLMtoCam = SLMtoCam;

out.CoC=CoC;
out.CoCmodelterms = modelterms;

rtXYZ = function_Eval3DCoC(SLMtoCam,function_Eval3DCoC(camToSLM,basXYZ(1:3,end-holdback:end)'));

err = sqrt(sum((rtXYZ - basXYZ(1:3,end-holdback:end)').^2,2));
meanRTerr = nanmean(err);
disp(['The Mean Round Trip RMS error: ' num2str(meanRTerr) ' pixels (' num2str(meanRTerr/pxPerMu) ' um) camera to SLM to camera']);

%% fit power as a function of SLM
disp('Fitting Power as a function of SLM')
%  modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
%      1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;...
%      2 0 1; 2 1 0; 0 2 1; 0 1 2; 1 2 0; 1 0 2;   ];  %XY spatial calibration model for Power interpolations
slmXYZ = slmXYZBackup;
basVal = basValBackup;


modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
    1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;...
    2 0 1; 2 1 0; 0 2 1; 0 1 2; 1 2 0; 1 0 2;...
    2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2; ];  %XY spatial calibration model for Power interpolations

intVal = basVal;
intVal = sqrt(intVal); %convert fluorescence intensity (2P) to 1P illumination intensity
intVal=intVal./max(intVal(:));

refAsk = (slmXYZ(1:3,1:end-holdback))';
refGet = intVal(1:end-holdback);

SLMtoPower =  polyfitn(refAsk,refGet,modelterms);

Ask = (slmXYZ(1:3,end-holdback:end))';
True = intVal(end-holdback:end)';

Get = polyvaln(SLMtoPower,Ask);

RMS = sqrt(sum((Get-True).^2,2));
meanRMS = nanmean(RMS);

figure(1);clf
subplot(2,3,1)
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],intVal,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Measured Power (converted to 1p)')
colorbar
axis square

subplot(2,3,2)
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],polyvaln(SLMtoPower,slmXYZ(1:3,:)'),'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Estimated Power Norm.')
colorbar
axis square

subplot(2,3,4)
% scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],polyvaln(SLMtoPower,slmXYZ(1:3,:)')-intVal','filled');
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],basVal,'filled');

ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Raw Fluorescence')
colorbar
axis square

subplot(2,3,5)
c = sqrt((polyvaln(SLMtoPower,slmXYZ(1:3,:)')-intVal').^2);
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],c,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Error RMS (A.U.)')
colorbar
axis square

subplot(2,3,3)
c = (polyvaln(SLMtoPower,slmXYZ(1:3,:)').^2);
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],c,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Estimated 2P Power')
colorbar
axis square

subplot(2,3,6)
normVal = basVal./max(basVal(:));

c = (polyvaln(SLMtoPower,slmXYZ(1:3,:)').^2)-normVal';
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],c,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Error 2P Power')
colorbar
axis square


disp(['The RMS error: ' num2str(meanRMS) ' A.U. Power Estimate']);
disp(['The Max power error: ' num2str(max(RMS)*100) '% of request']);

CoC.SLMtoPower = SLMtoPower;
out.CoC = CoC;
out.powerFitmodelTerms = modelterms;

%% Plot Axial FWHM vs Depth
FWHM = FWHMValBackup;
depth = basXYZBackup(3,:); 
slmXYZ = slmXYZBackup;

figure(1001); clf
subplot(1,2,1);
plot(FWHM,depth,'o')
% plot(FWHM,slmCoords(3,:),'o')

ylabel('Axial Depth \mum')
xlabel('z-FWHM \mum')
ylim([-75 175])
xlim([7.5 100])
title(['Mean z-FWHM in the typical useable volume (0 to 100um) is: ' num2str(mean(FWHM(depth>0 & depth<100))) 'um'])

refline(0,0)
refline(0,100)


subplot(1,2,2);
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],FWHM,'filled')
caxis([20 60])
h= colorbar;
xlabel('SLM X')
ylabel('SLM Y')
zlabel('SLM Z')
set(get(h,'label'),'string','z-FWHM \mum')

fprintf(['FWHM in the typical useable volume (0 to 100um) is: ' num2str(mean(FWHM(depth>0 & depth<100))) 'um\n'])

%% Run this to save non-holeburn run PRE multitarg
disp(['Elapsed time for non-holeburn run is ',num2str(toc(ttemp)),'s'])
save(fullfile([pathToUse,'Galvo00_nonHoleWorkspace_',date,'_',datestr(now,'HHMMSS'),'.mat']),'-v7.3','-nocompression');

%% THIS BEGINS THE NEW SECTION 3/15/21

%% Now using these CoC lets create holograms that shoot a pattern into a field of view

disp('Picking Holes to Burn')


%module to restrict burn grid to most likely SI FOV.
%added 7/20/19 -Ian
binarySI = ~isnan(SIpeakVal);
SImatchProb = mean(binarySI');%probability that point was detected aka that was in SI range

SImatchXY = camXYZ(1:2,1:625); %location of points in XYZ

figure(8);clf;
s=scatter(SImatchXY(1,:),SImatchXY(2,:),[],SImatchProb,'filled');

SImatchThreshold = 0.9; % threshold for being in SI FOV (set to 0 to take whole range)

SIx = SImatchXY(1,SImatchProb>SImatchThreshold);
SIy = SImatchXY(2,SImatchProb>SImatchThreshold);

SIboundary = boundary(SIx',SIy');
hold on
p=plot(SIx(SIboundary),SIy(SIboundary));

sz = size(Bgd);
%for fine targets
bufferMargin = 0.05; %fraction of total area as buffer
SImatchRangeXforFine = [max(min(SIx(SIboundary))-sz(1)*bufferMargin,1) ...
    min(max(SIx(SIboundary))+sz(1)*bufferMargin,sz(1))];

SImatchRangeYforFine = [max(min(SIy(SIboundary))-sz(2)*bufferMargin,1) ...
    min(max(SIy(SIboundary))+sz(2)*bufferMargin,sz(2))];
r = rectangle('position',...
    [SImatchRangeXforFine(1) SImatchRangeYforFine(1) SImatchRangeXforFine(2)-SImatchRangeXforFine(1) SImatchRangeYforFine(2)-SImatchRangeYforFine(1)]);
r.EdgeColor='g';

%for hole burning
bufferMargin = 0.02; %fraction of total area as buffer
SImatchRangeX = [max(min(SIx(SIboundary))-sz(1)*bufferMargin,1) ...
    min(max(SIx(SIboundary))+sz(1)*bufferMargin,sz(1))];

SImatchRangeY = [max(min(SIy(SIboundary))-sz(2)*bufferMargin,1) ...
    min(max(SIy(SIboundary))+sz(2)*bufferMargin,sz(2))];

r = rectangle('position',...
    [SImatchRangeX(1) SImatchRangeY(1) SImatchRangeX(2)-SImatchRangeX(1) SImatchRangeY(2)-SImatchRangeY(1)]);
r.EdgeColor='r';

rline = line(NaN,NaN,'LineWidth',1','LineStyle', '-','color','r');
gline = line(NaN,NaN,'LineWidth',1','LineStyle', '-','color','g');

colorbar
legend('Prob of SI FOV','Detected SI FOV','Burn Boundary Box','Calib Boundary Box')
xlabel('Camera X pixels')
ylabel('Camera Y Pixels')
set(gca,'clim',[0 1])

nBurnGrid = 12; %number of points in the burn grid
xpts = linspace(SImatchRangeX(1),SImatchRangeX(2),nBurnGrid);
ypts = linspace(SImatchRangeY(1),SImatchRangeY(2),nBurnGrid);

XYpts =[];
for i=1:nBurnGrid
    for k=1:nBurnGrid
        XYpts(:,end+1) = [xpts(k) ypts(i)];
    end
end
XYgrid = XYpts;
zsToBlast = [-100 -50 0 50 100];%older
% zsToBlast = [175 225 275 325 375];% match to SI Calib %linspace(0,90,11);% Changed to account for newer optotune 9/28/20; Changed to account for new optotune range 9/19/19 by Ian 0:10:80; %OptoPlanes to Blast
interXdist = xpts(2)-xpts(1);
%  xOff = round(interXdist/numel(zsToBlast));
interYdist = ypts(2)-ypts(1);
%  yOff = round(interYdist/numel(zsToBlast));

gridSide = ceil(sqrt(numel(zsToBlast)));
xOff = round(interXdist/gridSide);
yOff = round(interYdist/gridSide);

% %Turn into a more unique looking pattern
% numPts = size(XYpts,2);
% FractionOmit = 0.25; %changed down to 10% from 25% bc not really needed. 9/19/19 by Ian
% XYpts(:,randperm(numPts,round(numPts*FractionOmit)))=[];
% XYpts = reshape(XYpts,[2 numel(XYpts)/2]);
% 
% figure(6);
% scatter(XYpts(1,:),XYpts(2,:),'o');
% 
% disp([num2str(size(XYpts,2)) ' points per plane selected. ' num2str(size(XYpts,2)*numel(zsToBlast)) ' total'])

intermediateFitsT = toc(tIntermediateFine);

%% Simulate and create new Fine POints
% do a CoC to get more points to shoot

denseFineTimer = tic; 

nSimulatedTargs = 10000;

% get basler targets to shoot in from basler range
% for X
a = min(basXYZBackup(1,:));
b = max(basXYZBackup(1,:));
% a =SImatchRangeXforFine(1);
% b = SImatchRangeXforFine(2);
r = (b-a).*rand(nSimulatedTargs,1) + a;
rX = round(r);

% for Y
a = min(basXYZBackup(2,:));
b = max(basXYZBackup(2,:));
r = (b-a).*rand(nSimulatedTargs,1) + a;
rY = round(r);

% for Z
a = min(basXYZBackup(3,:));
b = max(basXYZBackup(3,:));
r = (b-a).*rand(nSimulatedTargs,1) + a;
rZ = round(r);

bas2shoot = [rX rY rZ];

testSLM = function_Eval3DCoC(camToSLM, bas2shoot);
expectBas = function_Eval3DCoC(SLMtoCam, testSLM);

testSLM(:,4) = ones(size(testSLM,1),1);

% make sure the SLM vals are within range
excludeMe = testSLM(:,1) < 0 | testSLM(:,1) > 1;
excludeMe = excludeMe | testSLM(:,2) < 0 | testSLM(:,2) > 1;

testSLM = testSLM(~excludeMe,:);
expectBas = expectBas(~excludeMe,:);

% generate multi-target holos that are spread apart
multiholosize=20;
planes = 7; 
holosperplane = 10;
ntotalPoints = multiholosize * planes * holosperplane;
disp(['Using ' num2str(ntotalPoints) ' points in round 2.'])

slm_coords = {};
bas_coords = {};
%c = 0;

[idx, cent] = kmeans(expectBas(:,3), planes);
[~,porder] = sort(cent,'ascend');
% figure
% scatter3(expectBas(:,1), expectBas(:,2), expectBas(:,3), [], categorical(idx))

for i=1:planes
    iter=0;
    h=0;
    while 1
        while h < holosperplane
            iter = iter+1;
            if iter > 10000
                disp(['****BAD WARNING! Exited hologram determination loop early. Could not find a suitable hologram for plane ' num2str(i) '.****']) 
                break
            end

            targs_this_plane = find(idx==i);
            % choose rand holos
            holo_idxs = randperm(length(targs_this_plane),multiholosize);
            dist = pdist2(expectBas(holo_idxs,:),expectBas(holo_idxs,:));
            temp = rand(size(dist,1));
            dist(find(diag(diag(temp))))=nan;
            if any(dist<100)
                continue
            end
            h = h+1;
            bas_coords{i}{h} = expectBas(targs_this_plane(holo_idxs),:);
            slm_coords{i}{h} = testSLM(targs_this_plane(holo_idxs),:);

            idx(targs_this_plane(holo_idxs)) = -i; %prevent shooting the same target twice. if there are too few in the simulation will error
        end
        break
    end
end



figure(1579)
clf
cmap = colormap(parula(numel(slm_coords)*holosperplane));
c = 0;
for i = 1:numel(slm_coords)
    hold on
    for j = 1:numel(slm_coords{i})
        c = c + 1;
        hold on
        subplot(1,2,1)
        scatter3(bas_coords{i}{j}(:,1),bas_coords{i}{j}(:,2),bas_coords{i}{j}(:,3), [], cmap(c,:), 'filled')%, 'MarkerFaceAlpha',0.7)
        hold on
        title('Bas Coords')
        subplot(1,2,2)
        scatter3(slm_coords{i}{j}(:,1),slm_coords{i}{j}(:,2),slm_coords{i}{j}(:,3), [], cmap(c,:), 'filled')%, 'MarkerFaceAlpha',0.7)
        title('SLM Coords')
    end
end
%% compute holos

c = 0;
for i=1:length(slm_coords)
    for j=1:length(slm_coords{i})
        c = c + 1;
        ht = tic;
        disp(['Compiling multi-target hologram ' num2str(c)])
        
        thisCoord = slm_coords{i}{j};
        thisCoord(:,3) = round(thisCoord(:,3),3); %Added 3/15/21 by Ian for faster compute times 

        [ mtholo, Reconstruction, Masksg ] = function_Make_3D_SHOT_Holos(Setup,thisCoord);
        holos2shoot{i}{j} = mtholo;
        disp(['done in ' num2str(toc(ht)) 's.'])
    end          
end

disp('now to shooting...') 

%% now repeat multi-target search with new holograms
clear peakValue4 peakDepth4 peakFWHM4 peakFWHMxy4 dataUZ4

%%

background = function_BasGetFrame(Setup,5);
range = 6;
box_range = 20; % distance threshold is set to 100
disp('shooting!')

planes = numel(slm_coords);
for i = 1:planes
    holos_this_plane = numel(slm_coords{i});
    disp(['Plane ' num2str(i) ' of ' num2str(planes)])
    
    % find the mean z of the holo targets and set a range around it
    % rearanging so it doesn't move unnescessarily
    meanz = mean(cellfun(@(x) mean(x(:,3)),bas_coords{i}));
%         minz = min(cellfun(@(x) min(x(:,3)),bas_coords{i}));
%         maxz = min(cellfun(@(x) max(x(:,3)),bas_coords{i}));

%      meanz = mean(bas_coords{i}{j}(:,3));
    fineUZ = linspace(meanz-fineRange, meanz+fineRange, finePts);

    % for every holo on that plane
%     for j = 1:holos_this_plane
        dataUZPlane = castImg(nan([size(Bgdframe(:,:,1)) finePts holos_this_plane]));
        
        % set power
%         multi_pwr = size(slm_coords{i}{j},1) * pwr;        
%         Function_Feed_SLM(Setup.SLM, holos2shoot{i}{j});
%         
        
        
        % for every sutter z plane
        fprintf('Depth: ')
        figure(4);clf;
        for k = 1:finePts
            fprintf([num2str(round(fineUZ(k))) ' ']);
            
            % move the sutter
            currentPosition = getPosition(Sutter.obj);
            position = Sutter.Reference;
            position(3) = position(3) + sutterposmult*(fineUZ(k));
            diff1 = currentPosition(3)-position(3);
            moveTime=moveTo(Sutter.obj,position);

            if i==1
                pause(1)
            else
                pause(0.1);
            end
           
            a = floor(sqrt(holos_this_plane));
            b = ceil(holos_this_plane/a);
            ro = min([a b]);
            co = max([a b]); 
            

            for j= 1:holos_this_plane
                multi_pwr = size(slm_coords{i}{j},1) * pwr *1;
                Function_Feed_SLM(Setup.SLM, holos2shoot{i}{j});
                
                requestPower(multi_pwr,masterSocket)
                
                % grab a frame, convert to uint8
                frame = function_BasGetFrame(Setup,3);
                frame = castImg(mean(frame,3));
                
                % turn off the laser
                requestPower(0,masterSocket)
                
                % subtract the background and filter
                frame =  max(frame-Bgd,0);
                frame = imgaussfilt(frame,2);
                % store into dataUZ(x,y,z-plane)
                dataUZPlane(:,:,k,j) =  frame;
                %             dataUZ4{i}{j} = dataUZ;
                
                figure(4);
                subplot(ro,co,j)
                imagesc(frame)
                colorbar
                caxis([0 150]);
                title({['Live Data. Depth ' num2str(round(fineUZ(k)))] ; ['Plane: ' num2str(i) '. Set ' num2str(j)]})
                drawnow
       
            end
        end
        
        for j= 1:holos_this_plane           
        fineUZ4{i}{j} = fineUZ;
        dataUZ4{i}{j} = dataUZPlane(:,:,:,j); %brought out of for loop
        
        dataUZ = dataUZPlane(:,:,:,j);
        
        % move sutter back to reference
        position = Sutter.Reference;
        moveTime=moveTo(Sutter.obj,position);
        pause(0.1)
        
        % target parsing, might do later instead
        for targ = 1:size(slm_coords{i}{j},1)
            
            expected_xyz = bas_coords{i}{j}(targ,:);
            [x, y] = size(Bgd);
            
            targX = round(expected_xyz(1)-box_range:expected_xyz(1)+box_range);
            targY = round(expected_xyz(2)-box_range:expected_xyz(2)+box_range);
            
            if max(targX)>x
                targX = expected_xyz(1)-box_range:x;
            end
            if max(targY)>y
                targY = expected_xyz(2)-box_range:y;
            end
            if min(targX)<1
                targX = 1:expected_xyz(1)+box_range;
            end
            if min(targY)<1
                targY = 1:expected_xyz(2)+box_range;
            end
            
            try
                % method 1 - rely on XY from first step
                targ_stack = double(squeeze(mean(mean(dataUZ(targX,targY,:)))));
                mxProj = max(dataUZ(targX,targY,:),[],3);
                [ holo_x,holo_y ] =function_findcenter(mxProj );
                xyFine4{i}{j}(:,targ) = [holo_x+(min(targX)), holo_y+(min(targY))];
            catch
                targ_stack = nan(finePts,1);
                xyFine4{i}{j}(:,targ) =[nan, nan];
            end
            

            try
                ff = fit(fineUZ', targ_stack-1*min(targ_stack), 'gauss1');
                peakValue4{i}{j}(targ) = ff.a1;
                peakDepth4{i}{j}(targ) = ff.b1;
                peakFWHM4{i}{j}(targ) = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
            catch
                disp(['Error on fit! Holo: ', num2str(j), ' Target: ', num2str(targ)])
                peakValue4{i}{j}(targ) = NaN;
                peakDepth4{i}{j}(targ) = NaN;
                peakFWHM4{i}{j}(targ) = NaN;
            end
        end
    end
end
        
fineT = toc(denseFineTimer);
disp(['Dense Fine Fits took ' num2str(fineT) 's']);

%% New Fits with denser Fine
denseFitsTimer = tic;

c=0;
slmXYZextra = [];
baxXYZextra =[];
basValextra=[];
FWHMValExtra = [];
peakDepthValExtra =[];

for i=1:planes
    for j=1:holos_this_plane
         for targ = 1:size(slm_coords{i}{j},1)
            c=c+1;
            slmXYZextra(c,:) = slm_coords{i}{j}(targ,:);
            baxXYZextra(c,:) = xyFine4{i}{j}(:,targ);
            basValextra(c) = peakValue4{i}{j}(targ);
            FWHMValExtra(c) = peakFWHM4{i}{j}(targ);
            peakDepthValExtra(c) = peakDepth4{i}{j}(targ);
         end
    end
end
        
%% exclude trials

slmXYZ4 = slmXYZextra';
basXYZ4 = [baxXYZextra peakDepthValExtra']';
basVal4 = basValextra;
FWHMVal4 = FWHMValExtra;%added 7/20/2020 -Ian

excludeTrials = all(basXYZ4(1:2,:)==[1 1]'); %hayley's understanding: if bas x and y are both one, exclude this trial

% excludeTrials = excludeTrials | basVal4>260; %max of this camera is 255

basDimensions = size(Bgdframe);
excludeTrials = excludeTrials | basXYZ4(1,:)>=basDimensions(1)-1;
excludeTrials = excludeTrials | basXYZ4(2,:)>=basDimensions(2)-1;
excludeTrials = excludeTrials | basXYZ4(3,:)<-150; %9/19/19 Ian Added to remove systematic low fits
excludeTrials = excludeTrials | basXYZ4(3,:)>150;


excludeTrials = excludeTrials | any(isnan(basXYZ4(:,:)));
excludeTrials = excludeTrials | basVal4<1; %8/3 hayley add 5; Ian ammend to 1 9/13
excludeTrials = excludeTrials | basVal4>(mean(basVal4)+3*std(basVal4)); %9/13/19 Ian Add

slmXYZBackup = slmXYZ4(:,~excludeTrials);
basXYZBackup = basXYZ4(:,~excludeTrials);
basValBackup = basVal4(:,~excludeTrials);
FWHMValBackup = FWHMVal4(~excludeTrials); % added 7/20/2020 -Ian
%basValBackup = basValBackup(:,1:386); % WH add to exlude trials with water loss
%slmXYZBackup = slmXYZBackup(:,1:386); % did this on 1/29/20
%basXYZBackup = basXYZBackup(:,1:386);
%%
f41=figure(1922);
f41.Units = 'Normalized';
f41.Position = [0.05 0.4 0.5 0.5];
subplot(1,2,1)
% scatter3(basXYZBackup(1,:),basXYZBackup(2,:),basXYZBackup(3,:), 50, 'k', 'Filled', 'MarkerFaceAlpha',0.5)
% hold on
% scatter3(xyzLoc(1,:), xyzLoc(2,:), xyzLoc(3,:), 70,  'r', 'Filled', 'MarkerFaceAlpha', 0.7)
% legend('Fine','Coarse')
% title('Detected basXYZs')
% subplot(1,2,2)
scatter3(basXYZBackup(1,:),basXYZBackup(2,:),basXYZBackup(3,:), 75, basValBackup, 'Filled')
colorbar
colormap default
title({'Second Denser Fine';'basXYZ and basVals (fine)'})

% f42=figure(42);
% clf(42)
subplot(1,2,2)
plot(basValBackup,'o')
title('basVal by trial')
xlabel('time/holo/acq num')
ylabel('pixel intensity')


%% fit SLM to Camera
%use model terms

basXYZ4 = basXYZBackup;
slmXYZ4 = slmXYZBackup;
basVal4 = basValBackup;

disp('Fitting SLM to Camera')
modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
    1 1 0; 1 0 1; 0 1 1 ; 1 1 1 ;...
    2 0 0; 0 2 0; 0 0 2;  ...
    2 0 1; 2 1 0; 0 2 1; 1 2 0; 0 1 2;  1 0 2; ... ];  %XY spatial calibration model for Power interpolations
    2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2;];
reOrder = randperm(size(slmXYZ4,2));
slmXYZ4 = slmXYZ4(:,reOrder);
basXYZ4 = basXYZ4(:,reOrder);

holdback = 100;%50;

refAsk = (slmXYZ4(1:3,1:end-holdback))';
refGet = (basXYZ4(1:3,1:end-holdback))';

%  SLMtoCam = function_3DCoC(refAsk,refGet,modelterms);

errScalar = 2; %2.8;%2.5;
figure(1977)%;clf;subplot(1,2,1)
[SLMtoCam, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,0,1977);
title('SLM to Cam v2')

Ask = refAsk;
True = refGet;
Get = function_Eval3DCoC(SLMtoCam,Ask);

figure(103);clf
subplot(1,2,1)
scatter3(True(:,1),True(:,2),True(:,3),'*','k')
hold on
scatter3(Get(:,1), Get(:,2), Get(:,3),'o','r')

ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
% legend('Measured targets', 'Estimated Targets');
title({'Reference Data'; 'SLM to Camera'})

refRMS = sqrt(sum((Get-True).^2,2));
subplot(1,2,2)
scatter3(True(:,1),True(:,2),True(:,3),[],refRMS,'filled');
colorbar
ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
title({'Reference Data'; 'RMS Error in position'})
caxis([0 30])


Ask = (slmXYZ4(1:3,end-holdback:end))';
True = (basXYZ4(1:3,end-holdback:end))';
Get = function_Eval3DCoC(SLMtoCam,Ask);

figure(101);clf
% subplot(1,2,1)
scatter3(True(:,1),True(:,2),True(:,3),'*','k')
hold on
scatter3(Get(:,1), Get(:,2), Get(:,3),'o','r')


ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
legend('Measured targets', 'Estimated Targets');
title('SLM to Camera')

RMS = sqrt(sum((Get-True).^2,2));
meanRMS = nanmean(RMS);
disp('Error based on Holdback Data...')
disp(['The RMS error: ' num2str(meanRMS) ' pixels for SLM to Camera']);

% pxPerMu = size(frame,1) / 1000; %really rough approximate of imaging size
pxPerMu = 0.57723;

disp(['Thats approx ' num2str(meanRMS/pxPerMu) ' um']);

xErr = sqrt(sum((Get(:,1)-True(:,1)).^2,2));
yErr = sqrt(sum((Get(:,2)-True(:,2)).^2,2));
zErr = sqrt(sum((Get(:,3)-True(:,3)).^2,2));

disp('Mean:')
disp(['X: ' num2str(mean(xErr)/pxPerMu) 'um. Y: ' num2str(mean(yErr)/pxPerMu) 'um. Z: ' num2str(mean(zErr)) 'um.']);
disp('Max:')
disp(['X: ' num2str(max(xErr)/pxPerMu) 'um. Y: ' num2str(max(yErr)/pxPerMu) 'um. Z: ' num2str(max(zErr)) 'um.']);

% subplot(1,3,2)
figure(111)
scatter3(True(:,1),True(:,2),True(:,3),[],RMS,'filled');
colorbar
ylabel('Y Axis Pixels')
xlabel('X axis Pixels')
zlabel('Depth \mum')
title('RMS Error in position')


refAsk = (basXYZ4(1:3,1:end-holdback))';
refGet = (slmXYZ4(1:3,1:end-holdback))';

%  camToSLM = function_3DCoC(refAsk,refGet,modelterms);

% subplot(1,2,2)
figure(1978)
[camToSLM, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,0,1978);
title('Cam to SLM v2')

Ask = (basXYZ4(1:3,end-holdback:end))';
True = (slmXYZ4(1:3,end-holdback:end))';
Get = function_Eval3DCoC(camToSLM,Ask);


figure(121);
% subplot(1,3,3)
scatter3(True(:,1),True(:,2),True(:,3),'*','k')
hold on
scatter3(Get(:,1), Get(:,2), Get(:,3),'o','r')

ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Depth units')
legend('Measured targets', 'Estimated Targets');
title('Camera to SLM')

% RMS = sqrt(sum((Get-True).^2,2));
% meanRMS = nanmean(RMS);
% 
% disp(['The RMS error: ' num2str(meanRMS) ' SLM units for Camera to SLM']);

CoC.camToSLM=camToSLM;
CoC.SLMtoCam = SLMtoCam;

out.CoC=CoC;
out.CoCmodelterms = modelterms;

rtXYZ = function_Eval3DCoC(SLMtoCam,function_Eval3DCoC(camToSLM,basXYZ4(1:3,end-holdback:end)'));

err = sqrt(sum((rtXYZ - basXYZ4(1:3,end-holdback:end)').^2,2));
meanRTerr = nanmean(err);
disp(['The Mean Round Trip RMS error: ' num2str(meanRTerr) ' pixels (' num2str(meanRTerr/pxPerMu) ' um) camera to SLM to camera']);

%% fit power as a function of SLM
disp('Fitting Power as a function of SLM')
%  modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
%      1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;...
%      2 0 1; 2 1 0; 0 2 1; 0 1 2; 1 2 0; 1 0 2;   ];  %XY spatial calibration model for Power interpolations
slmXYZ4 = slmXYZBackup;
basVal4 = basValBackup;


modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
    1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;...
    2 0 1; 2 1 0; 0 2 1; 0 1 2; 1 2 0; 1 0 2;...
    2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2; ];  %XY spatial calibration model for Power interpolations

intVal = basVal4;
%% Optional: clamp extreme fluorescence values (calibration-specific safeguard)
% Some calibration sessions can produce a few saturated/over-bright points
% that distort the SLM->power fit. Use this clamp to limit their influence.
if ~exist('cfg','var')
    cfg = struct();
end
if ~isfield(cfg,'clampFluorescence')
    cfg.clampFluorescence = true; % preserves prior behavior
end
if ~isfield(cfg,'fluorescenceClampMax')
    cfg.fluorescenceClampMax = 13;
end
if cfg.clampFluorescence
    intVal(intVal > cfg.fluorescenceClampMax) = cfg.fluorescenceClampMax;
end
intVal = sqrt(intVal); %convert fluorescence intensity (2P) to 1P illumination intensity
intVal=intVal./max(intVal(:));

refAsk = (slmXYZ4(1:3,1:end-holdback))';
refGet = intVal(1:end-holdback);

SLMtoPower =  polyfitn(refAsk,refGet,modelterms);

Ask = (slmXYZ4(1:3,end-holdback:end))';
True = intVal(end-holdback:end)';

Get = polyvaln(SLMtoPower,Ask);

RMS = sqrt(sum((Get-True).^2,2));
meanRMS = nanmean(RMS);

figure(145);clf
subplot(2,3,1)
scatter3(slmXYZ4(1,:),slmXYZ4(2,:),slmXYZ4(3,:),[],intVal,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Measured Power (converted to 1p)')
colorbar
axis square

subplot(2,3,2)
scatter3(slmXYZ4(1,:),slmXYZ4(2,:),slmXYZ4(3,:),[],polyvaln(SLMtoPower,slmXYZ4(1:3,:)'),'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Estimated Power Norm.')
colorbar
axis square

subplot(2,3,4)
% scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],polyvaln(SLMtoPower,slmXYZ(1:3,:)')-intVal','filled');
scatter3(slmXYZ4(1,:),slmXYZ4(2,:),slmXYZ4(3,:),[],basVal4,'filled');

ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Raw Fluorescence')
colorbar
axis square

subplot(2,3,5)
c = sqrt((polyvaln(SLMtoPower,slmXYZ4(1:3,:)')-intVal').^2);
scatter3(slmXYZ4(1,:),slmXYZ4(2,:),slmXYZ4(3,:),[],c,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Error RMS (A.U.)')
colorbar
axis square

subplot(2,3,3)
c = (polyvaln(SLMtoPower,slmXYZ4(1:3,:)').^2);
scatter3(slmXYZ4(1,:),slmXYZ4(2,:),slmXYZ4(3,:),[],c,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Estimated 2P Power')
colorbar
axis square

subplot(2,3,6)
normVal = basVal4./max(basVal4(:));

c = (polyvaln(SLMtoPower,slmXYZ4(1:3,:)').^2)-normVal';
scatter3(slmXYZ4(1,:),slmXYZ4(2,:),slmXYZ4(3,:),[],c,'filled');
ylabel('Y Axis SLM units')
xlabel('X axis SLM units')
zlabel('Z axis SLM units')
title('Error 2P Power')
colorbar
axis square


disp(['The RMS error: ' num2str(meanRMS) ' A.U. Power Estimate']);
disp(['The Max power error: ' num2str(max(RMS)*100) '% of request']);

CoC.SLMtoPower = SLMtoPower;
out.CoC = CoC;
out.powerFitmodelTerms = modelterms;

%% Plot Axial FWHM vs Depth
FWHM = FWHMValBackup;
depth = basXYZBackup(3,:); 
slmXYZ = slmXYZBackup;

figure(1001); clf
subplot(1,2,1);
plot(FWHM,depth,'o')
% plot(FWHM,slmCoords(3,:),'o')

ylabel('Axial Depth \mum')
xlabel('z-FWHM \mum')
ylim([-75 175])
xlim([7.5 100])
title(['Mean z-FWHM in the typical useable volume (0 to 100um) is: ' num2str(mean(FWHM(depth>0 & depth<100))) 'um'])

refline(0,0)
refline(0,100)


subplot(1,2,2);
scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],FWHM,'filled')
caxis([20 60])
h= colorbar;
xlabel('SLM X')
ylabel('SLM Y')
zlabel('SLM Z')
set(get(h,'label'),'string','z-FWHM \mum')

fprintf(['FWHM in the typical useable volume (0 to 100um) is: ' num2str(mean(FWHM(depth>0 & depth<100))) 'um\n'])

%% Run this to save non-holeburn PLUS multitarg run

disp(['Elapsed time for non-holeburn run is ',num2str(toc(ttemp)),'s'])
save(fullfile([pathToUse,'Galvo00_nonHoleWorkspace_plusmultitarg_',date,'_',datestr(now,'HHMMSS'),'.mat']),'-v7.3','-nocompression');


%% Plot Hole Burn Stuff
tCompileBurn = tic;

figure(4); clf

clear XYtarg SLMtarg
for i = 1:numel(zsToBlast)
    a = mod(i-1,gridSide);
    b = floor((i-1)/gridSide);
    
numPts = size(XYgrid,2);
FractionOmit = 0.0; %changed down to 10% from 25% bc not really needed. 9/19/19 by Ian
XYpts(:,randperm(numPts,round(numPts*FractionOmit)))=[];
XYpts = reshape(XYpts,[2 numel(XYpts)/2]);

    XYuse = bsxfun(@plus,XYpts,([xOff*a yOff*b])');    
    optoZ = zsToBlast(i);
    
    zOptoPlane = ones([1 size(XYuse,2)])*optoZ;
    
    Ask = [XYuse; zOptoPlane];
    estCamZ = polyvaln(OptZToCam,Ask');
    meanCamZ(i) = nanmean(estCamZ); %for use by sutter
    Ask = [XYuse; estCamZ'];
    estSLM = function_Eval3DCoC(camToSLM,Ask');
    estPower = polyvaln(SLMtoPower,estSLM);
    
    % negative DE restrictions
    ExcludeBurns = estPower<0 | estSLM(:,1)<slmXrange(1)-0.1 | estSLM(:,1)>slmXrange(2)+0.1 |...
        estSLM(:,2)<slmYrange(1)-0.1 | estSLM(:,2)>slmYrange(2)+0.1; %don't shoot if you don't have the power
    estSLM(ExcludeBurns,:)=[];
    estPower(ExcludeBurns)=[];
    XYuse(:,ExcludeBurns)=[];
    zOptoPlane(ExcludeBurns)=[];
    estCamZ(ExcludeBurns)=[];     
    
    XYtarg{i} = [XYuse; zOptoPlane];
    SLMtarg{i} = [estSLM estPower];
    
    subplot(1,2,1)
    scatter3(XYuse(1,:),XYuse(2,:),estCamZ,[],estPower,'filled')
    
    hold on
    subplot (1,2,2)
    scatter3(estSLM(:,1),estSLM(:,2),estSLM(:,3),[],estPower,'filled')
    
    disp([num2str(min(estSLM(:,3))) ' ' num2str(max(estSLM(:,3)))])  
    hold on
end

subplot(1,2,1)
title('Targets in Camera Space')
zlabel('Depth \mum')
xlabel('X pixels')
ylabel('Y pixels')

subplot(1,2,2)
title('Targets in SLM space')
xlabel('X SLM')
ylabel('Y SLM')
zlabel('Z SLM')
c = colorbar;
c.Label.String = 'Estimated Power';

%% Burn Holes
disp('Compiling Holos To Burn')
tCompileBurn = tic;

clear tempHololist
for k = 1:numel(zsToBlast)
    for i=1:size(XYtarg{k},2) % parfor to for 03/31/22 because Out Of Memory error
        t=tic;
        fprintf(['Compiling Holo ' num2str(i) ' for depth ' num2str(k)]);
        subcoordinates =  [SLMtarg{k}(i,1:3) 1];
        %check to avoid out of range holos; added 11/1/19
        %12/5/19 now it allows negative zs
        if ~any(subcoordinates(1:2)>1 | subcoordinates(1:2) <0)
            DE(i) = SLMtarg{k}(i,4);
            [ Hologram,~,~ ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates );
        else
            DE(i)= 0;
            Hologram = blankHolo;
        end
        tempHololist(:,:,i)=Hologram;
        fprintf([' took ' num2str(toc(t)) 's\n']);
    end
    holos{k}=tempHololist;
    Diffraction{k}=DE;
end
disp(['Compiling Done took ' num2str(toc(tCompileBurn)) 's']);

compileBurnT = toc(tCompileBurn);

%% MSOCKET WITH SI COMPUTER: RUN IF MSOCKET WITH SI GOT DISCONNECTED DURING CALIBRATION
%{
%initialize this and go to scanimage computer anr run SIcalibration script 
disp('Waiting for msocket communication to ScanImage Computer')
%then wait for a handshake
srvsock2 = mslisten(3042);
SISocket = msaccept(srvsock2,15);
msclose(srvsock2);
sendVar = 'A';
mssend(SISocket, sendVar);
%MasterIP = '128.32.177.217';
%masterSocket = msconnect(MasterIP,3002);

invar = [];

while ~strcmp(invar,'B');
    invar = msrecv(SISocket,.1);
end;
disp('communication from Master To SI Established');
%}
%%
disp('IN MESOSCOPE, INCREASE REP RATE TO 1200KHZ (REST OF CALIB SHOULD HAVE BEEN DONE IN 20kHz)')
disp('Blasting Holes for SI to SLM alignment, this will take about an hour and take 25Gb of space')
tBurn = tic;

%confirm that SI computer in eval Mode
mssend(SISocket,'1+2');
invar=[];
while ~strcmp(num2str(invar),'3') %stupid cludge so that [] read as false
    invar = msrecv(SISocket,0.01);
end
disp('linked')

%setup acquisition

numVol = 10; %number of SI volumes to average
flybackT = 10; % set high for slow optotune to avoid ripples
baseName = '''calib''';

mssend(SISocket,['hSI.hFastZ.userZs = [' num2str(zsToBlast) '];']);
mssend(SISocket,['hSI.hFastZ.numVolumes = [' num2str(numVol) '];']);
mssend(SISocket,['hSI.hFastZ.flybackTime = [' num2str(flybackT) '];']);
mssend(SISocket,'hSI.hFastZ.enable = 1 ;');

mssend(SISocket,'hSI.hBeams.pzAdjust = 0;');
mssend(SISocket,'hSI.hBeams.powers = 7;'); %power on SI laser. important no to use too much don't want to bleach

mssend(SISocket,'hSI.extTrigEnable = 0;'); %savign
mssend(SISocket,'hSI.hChannels.loggingEnable = 1;'); %savign
mssend(SISocket,'hSI.hScan2D.logFilePath = ''C:\Calib\Temp'';');
% mssend(SISocket,'hSI.hScan2D.logFileCounter = 1;');
mssend(SISocket,['hSI.hScan2D.logFileStem = ' baseName ';']);
mssend(SISocket,'hSI.hScan2D.logFileCounter = 1;');

mssend(SISocket,['hSICtl.updateView;']);

%clear invar
invar = msrecv(SISocket,0.01);
while ~isempty(invar)
    invar = msrecv(SISocket,0.01);
end

mssend(SISocket,'30+7');
invar=[];
while ~strcmp(num2str(invar),'37')
    invar = msrecv(SISocket,0.01);
end
disp('completed parameter set')

%%Burn

%AcquireBaseline
disp('Acquire Baseline')

mssend(SISocket,'hSI.startGrab()');
invar = msrecv(SISocket,0.01);
while ~isempty(invar)
    invar = msrecv(SISocket,0.01);
end
wait = 1;
while wait
    mssend(SISocket,'hSI.acqState;');
    invar = msrecv(SISocket,0.01);
    while isempty(invar)
        invar = msrecv(SISocket,0.01);
    end
    
    if strcmp(invar,'idle')
        wait=0;
        disp(['Ready for Next'])
    else
        %             disp(invar)
    end
end
%%
burnTime = 0.3; %in seconds, very rough and not precise
burnPowerMultiplier = 50;
disp('Now Burning')

for k=1:numel(zsToBlast)%1:numel(zsToBlast)
    
    offset = round(meanCamZ(k));
    currentPosition = getPosition(Sutter.obj);
    position = Sutter.Reference;
    position(3) = position(3) + sutterposmult*(offset);
    diff1 = currentPosition(3)-position(3);
    moveTime=moveTo(Sutter.obj,position);
    if k==1
        pause(1)
    else
        pause(0.1);
    end
    
    tempHololist=holos{k};
    
    for i=1:size(XYtarg{k},2)%1:size(XYuse,2)
        t=tic;
        fprintf(['Blasting Hole ' num2str(i) '. Depth ' num2str(zsToBlast(k))]);
        Function_Feed_SLM( Setup.SLM, tempHololist(:,:,i));
        
        DE = Diffraction{k}(i);
        if DE<0.2 %if Diffraction efficiency too low just don't even burn %Ian 9/20/19
            DE=inf;
        end
        blastPower = pwr*burnPowerMultiplier /1000 /DE; %ALERT!!!!!!!!!!
        
%         if blastPower>2 %cap for errors, now using a high divided mode so might be high 
%             blastPower =2;
%         end
        
        stimT=tic;
        mssend(masterSocket,[blastPower 1 1]);
        while toc(stimT)<burnTime
        end
        mssend(masterSocket,[0 1 1]);
        
        %flush masterSocket %flush and handshake added 9/20/19 by Ian
        invar='flush';
        while ~isempty(invar)
            invar = msrecv(masterSocket,0.01);
        end
        %re send 0
        mssend(masterSocket,[0 1 1]);
        %check for handshake
        invar=[];
        while ~strcmp(invar,'gotit')
            invar = msrecv(masterSocket,0.01);
        end
 
        mssend(SISocket,'hSI.startGrab()');
        invar = msrecv(SISocket,0.01);
        while ~isempty(invar)
            invar = msrecv(SISocket,0.01);
        end
        
        wait = 1;
        while wait
            mssend(SISocket,'hSI.acqState');
            invar = msrecv(SISocket,0.01);
            while isempty(invar)
                invar = msrecv(SISocket,0.01);
            end
            
            if strcmp(invar,'idle')
                wait=0;
                %             disp(['Ready for Next'])
            else
                %             disp(invar)
            end
        end
        disp([' Took ' num2str(toc(t)) 's'])
    end   
end

position = Sutter.Reference;
moveTime=moveTo(Sutter.obj,position);

burnT = toc(tBurn);
disp(['Done Burning. Took ' num2str(burnT) 's']);

disp('Done with Lasers and ScanImage now, you can turn it off')

%% HS: it's easier to save XYtarg and zsToBlast from Workspace here then do the analysis in SI computer
% save(['S:\Hyeyoung\XYtargzsToBlast' date '_' datestr(now,'HHMMSS') '.mat'], 'XYtarg', 'zsToBlast')

%% Move file to MesoSynology

disp('Moving files')
tMov = tic;

%on ScanImage Computer
servercalibfolder = ['calib_',datestr(now,'mmddyyyy'),'_',datestr(now,'HHMM')];
servercalibroot = 'S:\Mesoshare\holography\SpatialCalib\';
destination = [servercalibroot,servercalibfolder];
mkdir([servercalibroot,servercalibfolder]);
source = 'C:\Calib\Temp\calib*';

%clear invar
invar = msrecv(SISocket,0.01);
while ~isempty(invar)
    invar = msrecv(SISocket,0.01);
end


mssend(SISocket,['copyfile(''' source ''',''' destination ''')']);
invar = msrecv(SISocket,0.01);
while isempty(invar)
    invar = msrecv(SISocket,0.01);
end
disp(['Moved. Took ' num2str(toc(tMov)) 's']);
MovT= toc(tMov);

%% read/compute frame

%%
mssend(SISocket,'end');
%% HS 220203: note, bigread3 is replaced with mesotifread.
% note, bigread3 just assumes that the even frames correspond to red channel
% in mesotifread, the actual red channels is extracted no matter what the
% channel save setting was, and the red channel data is analyzed.

% channel 1 is green, channel 2 is red. the original code analyzed the red
% channel, but not adding an option in case green channel is recorded
% instead.
whichpmt = 2;


tLoad = tic;
% pth = destination; %On this computer
pth = [servercalibroot,servercalibfolder]; %temp fix b/c frankenshare down
files = dir([pth,'\*.tif']);

baseN = eval(baseName);

% [dummy fr] = bigread3(fullfile(pth,files(3).name) );
switch whichpmt
    case 1 % green channel was recorded
[fr, dummy, Ly, Lxs]=mesotifread( fullfile(pth,files(3).name) );
    case 2 % red channel was recorded
[dummy, fr, Ly, Lxs]=mesotifread( fullfile(pth,files(3).name) );
end
nOpto = numel(zsToBlast);
nBurnHoles = size(XYtarg{1},2);

baseFr = mean(fr(:,:,1:nOpto:end),3);%mean(fr(:,:,1:nOpto:end),3);%Probably more accurate to just do correct zoom, but sometimes having difficulty

k=1;c=0; SIXYZ =[];
for i=2:numel(files)
    t = tic;
    fprintf(['Loading/Processing Frame ' num2str(i),' ']);
%     try
        % [dummy fr] = bigread3(fullfile(pth,files(i).name) );
        switch whichpmt
            case 1 % green channel was recorded
                [fr, dummy]=mesotifread( fullfile(pth,files(i).name) );
            case 2 % red channel was recorded
                [dummy, fr]=mesotifread( fullfile(pth,files(i).name) );
%                 for j = 1:size(fr,3)
%                     fr(:,:,j) = [fr(:,1:500,j),imresize(fr(1:800,501:1000,j),[1000,500])];
%                 end
%                 fr = cat(2,fr(:,1:400,:),fr(:,801:1200,:),fr(:,401:800,:));
        end

        if c>=nBurnHoles
            k=k+1;
            c=0;
            nBurnHoles = size(XYtarg{k},2);
        end
        c=c+1;
        
        Frame = mean(fr(:,:,k:nOpto:end),3);%mean(fr(:,:,k:nOpto:end),3); %Probably more accurate to just do correct zoom, but sometimes having difficulty
        Frames{k}(:,:,c) = Frame;
        
        if c>1
%             baseFrame = Frames{k}(:,:,c-1);
%             
%             %try to exclude those very bright spots
%             maskFR = imgaussfilt(Frame,3) - imgaussfilt(Frame,16);
%             mask = maskFR > mean(maskFR(:))+6*std(maskFR(:));
%             
%             %remove the low frequency slide illumination differences
%             filtNum = 4;
%             frameFilt = imgaussfilt(Frame,filtNum);
%             baseFilt = imgaussfilt(baseFrame,filtNum);
%             
%             
%             toCalc = (baseFrame-baseFilt) - (Frame-frameFilt);
%             toCalc(mask)=0;
            
            toCalc = Frames{k}(:,:,c-1) - Frame;
            [ x,y ] =function_findcenter(toCalc);
        else
            x = 0;
            y=0;
        end
%     catch
%         fprintf('\nError in Hole analysis... probably loading.')
%         x = 0;
%         y=0;
%     end
    
    
    SIXYZ(:,end+1) = [x,y,zsToBlast(k)];
    disp([' Took ' num2str(toc(t)) ' s']);
end
%%
SIXYZbackup=SIXYZ;
disp(['Done Loading/Processing SI files. Took ' num2str(toc(tLoad)) 's'])
loadT = toc(tLoad);

%%
% load('S:\Hyeyoung\SIXYZfft_Temp.mat')
%% do non-cv SI to cam calculation
disp('IN MESOSCOPE, USER NEEDS TO DESIGNATE THE SI COORDINATES THAT CORRESPOND TO SLM BOUNDARIES')
burnFitsTimer = tic;

% modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
%     1 1 0; 1 0 1; 0 1 1 ; 1 1 1 ;...
%     2 0 0; 0 2 0; 0 0 2;  ...
%     2 0 1; 2 1 0; 0 2 1; 1 2 0; 0 1 2;  1 0 2; ... ];  %XY spatial calibration model for Power interpolations
%     2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2;];
modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
    1 1 0; 1 0 1; 0 1 1; 2 0 0; 0 2 0; 0 0 2];  %XY spatial calibration model for Power interpolations

cam3XYZ = [XYtarg{:};];
SIXYZ = SIXYZbackup;
tempSLM = cellfun(@(x) x',SLMtarg,'UniformOutput',false);
slm3XYZ = [tempSLM{:}];
slm3XYZ=slm3XYZ(1:3,1:size(SIXYZ,2));

% SIXlb = 1600; SIXub = 2400; SIYlb = 150; SIYub = 550; 
SIXlb = min(SIXYZ(2,:)); SIXub = max(SIXYZ(2,:)); SIYlb = min(SIXYZ(1,:)); SIYub = max(SIXYZ(1,:)); 
% SIXlb = min(SIXYZ(2,:))-1; SIXub = max(SIXYZ(2,:))+1; SIYlb = min(SIXYZ(1,:))-1; SIYub = max(SIXYZ(1,:))+1; 

cam3XYZ=cam3XYZ(:,1:size(SIXYZ,2));

excl = logical(zeros(1,size(slm3XYZ,2)));
excl = SIXYZ(1,:)<=SIYlb | SIXYZ(1,:)>=SIYub| SIXYZ(2,:)<=SIXlb | SIXYZ(2,:)>=SIXub;
% excl = excl | slm3XYZ(1,:)<slmXrange(1) | slm3XYZ(1,:)>slmXrange(2) |...
%     slm3XYZ(2,:)<slmYrange(1) | slm3XYZ(2,:)>slmYrange(2);
cam3XYZ(:,excl)=[];
SIXYZ(:,excl)=[];

% % exclude all of the topmost plane
% excl = SIXYZ(3,:)>min(SIXYZ(3,:));
% excl = SIXYZ(3,:)>60;
% cam3XYZ(:,excl)=[];
% SIXYZ(:,excl)=[];

refAsk = SIXYZ(1:3,:)';
refGet = (cam3XYZ(1:3,:))';

errScalar = 2.3; %1.6;2.5;2.6;
figure(2594)%;clf
% subplot(1,2,1)
[SItoCam, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,0,2594);
title('SI to Cam')

errScalar = 2.5; %1.6;2.5;2.6;
figure(2595)
% subplot(1,2,2)
[CamToSI, trialN] = function_3DCoCIterative(refGet,refAsk,modelterms,errScalar,0,2595);
title('Cam to SI')

CoC.CamToSI = CamToSI;
CoC.SItoCam = SItoCam;
out.CoC=CoC;

%% alternate calculation
% modelterms =[0 0 0; 1 0 0; 0 1 0; 0 0 1;...
%     1 1 0; 1 0 1; 0 1 1; 1 1 1; 2 0 0; 0 2 0; 0 0 2;...
%     2 0 1; 2 1 0; 0 2 1; 0 1 2; 1 2 0; 1 0 2;...
%     2 2 0; 2 0 2; 0 2 2; 2 1 1; 1 2 1; 1 1 2; ];  %XY spatial calibration model for Power interpolations

tempSLM = cellfun(@(x) x',SLMtarg,'UniformOutput',false);
slm3XYZ = [tempSLM{:}];
SIXYZ = SIXYZbackup;

slm3XYZ=slm3XYZ(1:3,1:size(SIXYZ,2));

% excl = SIXYZ(1,:)<SIYlb | SIXYZ(1,:)>SIYub| SIXYZ(2,:)<SIXlb | SIXYZ(2,:)>SIXub;
% excl = excl | slm3XYZ(1,:)<slmXrange(1) | slm3XYZ(1,:)>slmXrange(2) |...
%     slm3XYZ(2,:)<slmYrange(1) | slm3XYZ(2,:)>slmYrange(2);
slm3XYZ(:,excl)=[];
SIXYZ(:,excl)=[];

% % exclude all of the topmost plane
% excl = SIXYZ(3,:)>min(SIXYZ(3,:));
% slm3XYZ(:,excl)=[];
% SIXYZ(:,excl)=[];

refAsk = SIXYZ(1:3,:)'+0.0*randn(size(SIXYZ,2),1);
refGet = (slm3XYZ(1:3,:))';

errScalar = 2.3;
figure(2616)%;clf
% subplot(1,2,1)
[SItoSLM, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,0,2616);
title('SI to SLM')

errScalar = 2.3;
figure(2617)
% subplot(1,2,2)
[SLMtoSI, trialN] = function_3DCoCIterative(refGet,refAsk,modelterms,errScalar,0,2617);
title('SLM to SI')

CoC.SItoSLM = SItoSLM;
CoC.SLMtoSI = SLMtoSI;


%% TODO: EDIT FOR MESOSCOPE Calculate round trip errors

numTest = 10000;

rangeX = [0 600];%[0 511];
rangeY = [0 1200];%[0 511];
rangeZ = [0 60];% Make Sure to match this to the correct range for this optotune;

clear test;
valX = round((rangeX(2)-rangeX(1)).*rand(numTest,1)+rangeX(1));
valY = round((rangeY(2)-rangeY(1)).*rand(numTest,1)+rangeY(1));
valZ = round((rangeZ(2)-rangeZ(1)).*rand(numTest,1)+rangeZ(1));

test = [valX valY valZ];
%%display
test2 = function_SLMtoSI(function_SItoSLM(test,CoC),CoC);
ER1xy = test2(:,1:2)-test(:,1:2);
RMSE1xy = sqrt(sum(ER1xy'.^2));

SIpxPerMu = 0.75;

ER1z = test2(:,3)-test(:,3);
RMSE1z = abs(ER1z);

meanE1rxy = mean(RMSE1xy);
meanE1rz = mean(RMSE1z);

figure(12);clf
subplot(4,2,1)
histogram(RMSE1xy/SIpxPerMu,0:0.1:12)
xlim([0 12])
xlabel('XY Error \mum')
title({'4 Step CoC'; ['Mean RMS err: ' num2str(meanE1rxy) '\mum']})

subplot(4,2,2)
histogram(RMSE1z,0:0.1:12)
xlim([0 12])
xlabel('Z Error optoTuneUnits')
title(['Mean RMS err: ' num2str(meanE1rz) ' optotune Units'])

estSLM = function_Eval3DCoC(CoC.SItoSLM,test);
test2 = function_Eval3DCoC(CoC.SLMtoSI,estSLM);
ER2xy = test2(:,1:2)-test(:,1:2);
RMSE2xy = sqrt(sum(ER2xy'.^2));

% SIpxPerMu = 512/680;

ER2z = test2(:,3)-test(:,3);
RMSE2z = abs(ER2z);
meanE2rxy = mean(RMSE2xy);
meanE2rz = mean(RMSE2z);

subplot(4,2,3)
histogram(RMSE2xy/SIpxPerMu,0:0.1:12)
xlim([0 12])
xlabel('XY Error \mum')
title({'1 Step CoC'; ['Mean RMS err: ' num2str(meanE2rxy) '\mum']})

subplot(4,2,4)
histogram(RMSE2z,0:0.1:12)
xlim([0 12])
xlabel('Z Error optoTuneUnits')
title(['Mean RMS err: ' num2str(meanE2rz) ' optotune Units'])


estSLM = function_Eval3DCoC(CoC.SItoSLM,test);
estSIasym = function_SLMtoSI(estSLM,CoC);

ERA = estSIasym-test;
RMSErAxy = sqrt(sum(ERA(:,1:2)'.^2));
RMSErAz = abs(ERA(:,3));


subplot(4,2,5)
histogram(RMSErAxy,0:0.1:12)
xlim([0 12])
xlabel('XY Error \mum')

meanE3rxy = mean(RMSErAxy);
meanE3rz = mean(RMSErAz);
title({'Asymetric CoC; 1S Forward, 4S Reverse'; ['Mean RMS err: ' num2str(meanE3rxy) '\mum']})

subplot(4,2,6)
histogram(RMSErAz,0:0.1:12)
xlim([0 12])
xlabel('Z Error optoTuneUnits')
title(['Mean RMS err: ' num2str(meanE3rz) ' optotune Units'])



estSLM2 = function_SItoSLM(test,CoC);
estSLM2 = estSLM2(:,1:3);

estSIasym2 = function_Eval3DCoC(CoC.SLMtoSI,estSLM2);


ERA2 = estSIasym2-test;
RMSErAxy = sqrt(sum(ERA2(:,1:2)'.^2));
RMSErAz = abs(ERA2(:,3));


subplot(4,2,7)%aysmetric reverse; foward with 4 chan
histogram(RMSErAxy,0:0.1:12)
xlim([0 12])
xlabel('XY Error \mum')

meanE3rxy = mean(RMSErAxy);
meanE3rz = mean(RMSErAz);
title({'Asymetric CoC reverse. 4S Forward, 1S Reverse'; ['Mean RMS err: ' num2str(meanE3rxy) '\mum']})

subplot(4,2,8) 
histogram(RMSErAz,0:0.1:12)
xlim([0 12])
xlabel('Z Error optoTuneUnits')
title(['Mean RMS err: ' num2str(meanE3rz) ' optotune Units'])

%%Plot scatter
N=10000;


figure(13);clf
subplot(1,2,1)
val=RMSErAxy;
scatter3(test(1:N,1),test(1:N,2),test(1:N,3),[],val(1:N),'filled')
xlabel('SI X')
ylabel('SI Y')
zlabel('Opto Depth')
caxis([0 15])
colorbar
title('Simulated XY error, both methods')

subplot(1,2,2)
val=RMSErAz;
scatter3(test(1:N,1),test(1:N,2),test(1:N,3),[],val(1:N),'filled')
xlabel('SI X')
ylabel('SI Y')
zlabel('Opto Depth')
caxis([0 15])
colorbar
title('Simulated Z error, both methods')




figure(600);clf
subplot(1,2,1)
val=RMSE1xy/SIpxPerMu;
scatter3(test(1:N,1),test(1:N,2),test(1:N,3),[],val(1:N),'filled')
xlabel('SI X')
ylabel('SI Y')
zlabel('Opto Depth')
caxis([0 15])
colorbar
title('Simulated XY error, 1st methods')

subplot(1,2,2)
val=RMSE1z;
scatter3(test(1:N,1),test(1:N,2),test(1:N,3),[],val(1:N),'filled')
xlabel('SI X')
ylabel('SI Y')
zlabel('Opto Depth')
caxis([0 15])
colorbar
title('Simulated Z error, 1st methods')

burnFitsT = toc(burnFitsTimer);

%% Save Output Function
disp('Saving...')
tSave = tic;

% Save the fitted calibration struct (CoC) in two forms:
% - a timestamped snapshot for provenance/reproducibility
% - `ActiveCalib.mat` which is the file loaded by online holo generation
save(fullfile(pathToUse,[date,'_',datestr(now,'HHMMSS'),'_Calib.mat']),'CoC')
save(fullfile(pathToUse,'ActiveCalib.mat'),'CoC')



% times.saveT = toc(tSave);
% times.burnFitsT = burnFitsT;
% times.loadT = loadT;
% times.MovT = MovT;
% times.burnT = burnT;
% times.compileBurnT = compileBurnT;
% % times.finalFitsT = finalFitsT; %Final Fits Camera to SLM
% times.finalFineT = fineT; %Second Dense Fine
% times.intermediateFitsT = intermediateFitsT;
% times.intermediateT = multiT; %first pass fine fit
% times.coarseFitsT = fitsT; %Coarse
% times.coarseT = coarseT; %Coarse Fit
% times.siT = siT;
% times.singleCompileT = singleCompileT;
% times.multiCompileT = multiCompileT;
% times.manualT = tManual; %time spent doing manual setup. 

totT = toc(tBegin);
times.totT = totT;

% Save full workspace for debugging. This is intentionally large and is not
% meant for routine versioning; it captures intermediate variables that can
% be invaluable when diagnosing calibration failures or regressions.
save(fullfile([pathToUse,'CalibWorkspace_',date,'_',datestr(now,'HHMMSS'),'.mat']),'-v7.3','-nocompression');
disp(['Saving took ' num2str(toc(tSave)) 's']);

disp(['All Done, total time from begining was ' num2str(toc(tBegin)) 's. Bye!']);

%% use this to run
%[SLMXYZP] = function_SItoSLM(SIXYZ,CoC);




[Setup.SLM ] = Function_Stop_SLM( Setup.SLM );

try; function_close_sutter( Sutter ); end
try function_stopBasCam(Setup); end

%%
% %% Plot lateral FWHM vs Depth
% 
% for i = 1:planes
%     holos_this_plane = numel(slm_coords{i});
%     % for every holo on that plane
%     for j = 1:holos_this_plane
% %         if size(slmMultiCoordsIndiv{i}{j},2) == 0 || size(slmMultiCoordsIndiv{i}{j},2) == 2 % or <3 ??
% %             continue
% %         end
%         expected_z = xyzLoc(3,target_ref);
%         dataUZ = dataUZPlane(:,:,:,j);
%         % OK, now parse the basler data in expected holo spots
%         for targ = 1:size(slm_coords{i}{j},1)
%           expected_xyz = bas_coords{i}{j}(targ,:);
%             [x, y] = size(Bgd);
%            targX = round(expected_xyz(1)-box_range:expected_xyz(1)+box_range);
%             targY = round(expected_xyz(2)-box_range:expected_xyz(2)+box_range);
%             if max(targX)>x
%                 targX = round(expected_xyz(1)-box_range:x);
%             end
%             if max(targY)>y
%                 targY = round(expected_xyz(2)-box_range:y);
%             end
%             if min(targX)<1
%                 targX = round(1:expected_xyz(1)+box_range);
%             end
%             if min(targY)<1
%                 targY = round(1:expected_xyz(2)+box_range);
%             end
% %             for k=1:size(dataUZ,3) 
% %                 imagesc(dataUZ(targX,targY,k))
% %                 title(['Plane ',num2str(i),' Holo ',num2str(j),' Target ',num2str(targ)])
% %                 colorbar
% %                 pause
% %             end
%             targ_stack_x = double(squeeze(max(max(dataUZ(targX,targY,:),[],3),[],2)));
%             targ_stack_y = double(squeeze(max(max(dataUZ(targX,targY,:),[],3),[],1)));
%             if(max(targ_stack_x) < 10 | max(targ_stack_y)<10)
%                 disp(['Junk point Plane : ',num2str(i), 'Holo: ', num2str(j), ' Target: ', num2str(targ)])
%                 peakFWHMx{i}{j}(targ) = NaN;
%                 peakFWHMy{i}{j}(targ) = NaN;
%             else
%             try
%                 ff = fit((1:length(targ_stack_x))', targ_stack_x, 'gauss1');
%                 peakFWHMx{i}{j}(targ) = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
%                 ff = fit((1:length(targ_stack_y))', targ_stack_y', 'gauss1');
%                 peakFWHMy{i}{j}(targ) = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
%             catch
%                 disp(['Error on fit! Plane : ',num2str(i), 'Holo: ', num2str(j), ' Target: ', num2str(targ)])
%                 peakFWHMx{i}{j}(targ) = NaN;
%                 peakFWHMy{i}{j}(targ) = NaN;
%             end
%             end
%         end
%     end
% end

% %%
% 
% depth = peakDepthValExtra; 
% 
% c=0;
% 
% for i=1:planes
%     if numel(peakDepth)<i
%         holos_this_plane = 0;
%     else
%         holos_this_plane = numel(slm_coords{i});
%     end
%     
%     for j=1:holos_this_plane
%         for targ = 1:size(slm_coords{i}{j},1)
%             c = c+1;
%             FWHMvalx(c) = peakFWHMx{i}{j}(targ);
%             FWHMvaly(c) = peakFWHMy{i}{j}(targ);
%         end
%     end
% end 
% 
% BASpxPerMu = 400/680;
% FWHMvalx = FWHMvalx/BASpxPerMu;
% FWHMvaly = FWHMvaly/BASpxPerMu;
% %FWHMvalx = FWHMvalx(~excludeTrials);
% %FWHMvaly = FWHMvaly(~excludeTrials);
% 
% newdepth = depth;
% newslmXYZ = slmXYZextra';
% newExcludeTrials = sqrt(FWHMvalx.^2 + FWHMvaly.^2) > 30;
% FWHMvalx = FWHMvalx(~newExcludeTrials);
% FWHMvaly = FWHMvaly(~newExcludeTrials);
% newdepth = newdepth(~newExcludeTrials);
% newslmXYZ = newslmXYZ(:,~newExcludeTrials);
% 
% figure(1010); clf
% subplot(1,2,1);
% plot(FWHMvalx,newdepth,'o')
% % plot(FWHM,slmCoords(3,:),'o')
% ylabel('Axial Depth \mum')
% xlabel('x-FWHM \mum')
% ylim([-75 175])
% xlim([7.5 35])
% title(['Mean x-FWHM in the typical useable volume (0 to 100um) is: ' num2str(nanmean(FWHMvalx(newdepth>0 & newdepth<100))) 'um'])
% 
% refline(0,0)
% refline(0,100)
%  
% subplot(1,2,2);
% scatter3(newslmXYZ(1,:),newslmXYZ(2,:),newslmXYZ(3,:),[],FWHMvalx,'filled')
% caxis([10 30])
% h= colorbar;
% xlabel('SLM X')
% ylabel('SLM Y')
% zlabel('SLM Z')
% set(get(h,'label'),'string','x-FWHM \mum')
% %%%%%%%%
% 
% figure(1020); clf
% subplot(1,2,1);
% plot(FWHMvaly,newdepth,'o')
% % plot(FWHM,slmCoords(3,:),'o')
% ylabel('Axial Depth \mum')
% xlabel('y-FWHM \mum')
% ylim([-75 175])
% xlim([7.5 35])
% title(['Mean y-FWHM in the typical useable volume (0 to 100um) is: ' num2str(nanmean(FWHMvaly(newdepth>0 & newdepth<100))) 'um'])
% 
% refline(0,0)
% refline(0,100)
% 
% subplot(1,2,2);
% scatter3(newslmXYZ(1,:),newslmXYZ(2,:),newslmXYZ(3,:),[],FWHMvaly,'filled')
% caxis([10 30])
% h= colorbar;
% xlabel('SLM X')
% ylabel('SLM Y')
% zlabel('SLM Z')
% set(get(h,'label'),'string','y-FWHM \mum')
% 
% finalFitsT = toc(denseFitsTimer);
%%
% %% Plot lateral FWHM vs Depth
% for i = 1:planes
%     
%     holos_this_plane = numel(slmMultiCoordsIndiv{i});
%     % for every holo on that plane
%     for j = 1:holos_this_plane
%         
%         if size(slmMultiCoordsIndiv{i}{j},2) == 0 || size(slmMultiCoordsIndiv{i}{j},2) == 2 % or <3 ??
%             continue
%         end
%                 
%         target_ref = targListIndiv{i}{j}(1);
%         expected_z = xyzLoc(3,target_ref);
%         
%         dataUZ = dataUZ3{i}{j};
%         fineUZ = fineUZ3{i}{j};
%         
%         % OK, now parse the basler data in expected holo spots
%         for targ = 1:size(slmMultiCoordsIndiv{i}{j},2)
%            
%             target_ref = targListIndiv{i}{j}(targ);
%             expected_xyz = xyzLoc(:,target_ref);
%             [x, y] = size(Bgd);
%             
%             targX = expected_xyz(1)-box_range:expected_xyz(1)+box_range;
%             targY = expected_xyz(2)-box_range:expected_xyz(2)+box_range;
% 
%             if max(targX)>x
%                 targX = expected_xyz(1)-box_range:x;
%             end
%             if max(targY)>y
%                 targY = expected_xyz(2)-box_range:y;
%             end
%             if min(targX)<1
%                 targX = 1:expected_xyz(1)+box_range;
%             end
%             if min(targY)<1
%                 targY = 1:expected_xyz(2)+box_range;
%             end
% 
%             targ_stack_x = double(squeeze(max(max(dataUZ(targX,targY,:),[],3),[],2)));
%             targ_stack_y = double(squeeze(max(max(dataUZ(targX,targY,:),[],3),[],1)));
% 
%             try
%                 ff = fit((1:length(targ_stack_x))', targ_stack_x, 'gauss1');
%                 peakFWHMx{i}{j}(targ) = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
%                 ff = fit((1:length(targ_stack_y))', targ_stack_y', 'gauss1');
%                 peakFWHMy{i}{j}(targ) = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
%             catch
%                 disp(['Error on fit! Holo: ', num2str(j), ' Target: ', num2str(targ)])
%                 peakFWHMx{i}{j}(targ) = NaN;
%                 peakFWHMy{i}{j}(targ) = NaN;
%             end
%         end
%     end
% end
% 
% c=0;
% for i=1:planes
%     
%     if numel(peakDepth)<i
%         holos_this_plane = 0;
%     else
%         holos_this_plane = numel(peakDepth{i}); 
%     end
%     
%     for j=1:holos_this_plane
%         for targ = 1:size(slmMultiCoordsIndiv{i}{j},2)
%             c = c+1;
%             FWHMvalx(c) = peakFWHMx{i}{j}(targ);
%             FWHMvaly(c) = peakFWHMy{i}{j}(targ);
%          end
%     end
% end
% BASpxPerMu = 400/680;
% FWHMvalx = FWHMvalx/BASpxPerMu;
% FWHMvaly = FWHMvaly/BASpxPerMu;
% 
% % FWHMvalx = FWHMvalx(~excludeTrials);
% % FWHMvaly = FWHMvaly(~excludeTrials);
% 
% figure(1010); clf
% subplot(1,2,1);
% plot(FWHMvalx,depth,'o')
% % plot(FWHM,slmCoords(3,:),'o')
% 
% ylabel('Axial Depth \mum')
% xlabel('x-FWHM \mum')
% ylim([-75 175])
% xlim([7.5 35])
% title(['Mean x-FWHM in the typical useable volume (0 to 100um) is: ' num2str(mean(FWHMvalx(depth>0 & depth<100))) 'um'])
% 
% refline(0,0)
% refline(0,100)
% 
% subplot(1,2,2);
% scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],FWHMvalx,'filled')
% caxis([10 30])
% h= colorbar;
% xlabel('SLM X')
% ylabel('SLM Y')
% zlabel('SLM Z')
% set(get(h,'label'),'string','x-FWHM \mum')
% %%%%%%%%
% figure(1020); clf
% subplot(1,2,1);
% plot(FWHMvaly,depth,'o')
% % plot(FWHM,slmCoords(3,:),'o')
% 
% ylabel('Axial Depth \mum')
% xlabel('y-FWHM \mum')
% ylim([-75 175])
% xlim([7.5 35])
% title(['Mean y-FWHM in the typical useable volume (0 to 100um) is: ' num2str(mean(FWHMvaly(depth>0 & depth<100))) 'um'])
% 
% refline(0,0)
% refline(0,100)
% 
% subplot(1,2,2);
% scatter3(slmXYZ(1,:),slmXYZ(2,:),slmXYZ(3,:),[],FWHMvaly,'filled')
% caxis([10 30])
% h= colorbar;
% xlabel('SLM X')
% ylabel('SLM Y')
% zlabel('SLM Z')
% set(get(h,'label'),'string','y-FWHM \mum')
% 
% 
% finalFitsT = toc(denseFitsTimer);



        
 