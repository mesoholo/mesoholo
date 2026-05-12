%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/holo_computer/getPSF.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function getPSF

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

clear;%close all;clc
imaqreset

%% Pathing
tBegin = tic;
mesoholo_setup();
% addpath(genpath('C:\Program Files\Meadowlark Optics\Blink OverDrive Plus\'));
savepath

calibpathEnv = getenv("MESOHOLO_CALIB_PATH");
if strlength(calibpathEnv) == 0
    error(['MESOHOLO_CALIB_PATH is not set. ' ...
        'Point it to a folder containing ActiveCalib.mat (with variable CoC).']);
end
calibpath = fullfile(char(calibpathEnv), 'ActiveCalib.mat');

disp('done pathing')

%% Clear and set SLM range

% First, make sure your slm ranges are in the imaging fov.
% Use imaging zoom level that you want to use for calibration and turn focus on SI
% Run QuickSLMHolo at close to boundary coords to map out the 4 corners of
% imaging square/rectangle

%ranges set by exploration moving holograms looking at z1 fov.
slmXrange = [0.2 0.8];
slmYrange = [0.2 0.8];
slmZrange = [0 0.2]; % 0.1 = imaging 0

%% Setup Stuff
disp('Setting up stuff...');

[Setup ] = function_loadparameters2();
Setup.CGHMethod=2;
Setup.GSoffset=0;
Setup.verbose =0;
Setup.useGPU =1;

Setup.useThorCam = 0;
Setup.maxFramesPerAcquire = 10; %set to 0 for unlimited (frames will return will be
Setup.camExposureTime = 50000;
Setup.camGain = 1;

if Setup.useGPU
    disp('Getting gpu...'); %this can sometimes take a while at initialization
    g= gpuDevice;
end

[Setup.SLM ] = Function_Stop_SLM( Setup.SLM );
[ Setup.SLM ] = Function_Start_SLM( Setup.SLM );

Setup.Sutterport ='COM6';
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
    Setup.xroi = 650:1250;
    Setup.yroi = 250:850;
else
    castImg = @uint8;
    castAs = 'uint8';
    camMax = 255;
end
%% look for objective in 1p or you know... have it already set up

function_BasPreview(Setup);

%% Make mSocketConnections with DAQ and SI Computers 
%initialize this section and then start the msocket on DAQ comp -
%DAQcalibration script

disp('Waiting for msocket communication From DAQ')
%then wait for a handshake
srvsock = mslisten(3054);
masterSocket = msaccept(srvsock,30);
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

%% Set Power Levels
% Exposure1P = -2; %[59 1000000] defines frame rate of Bassler [-14 0]
% BasGain = 450; % [0 12] [136 542]
% try Setup = function_stopBasCam(Setup); end
pwr = 5;
%60 at 50 divided mode 3/8/2020 (150+ burns, 60 looks crisp)
disp(['individual hologram power set to ' num2str(pwr) 'mW']);
%
disp('Find the spot and check if this is the right amount of power')
% slmCoordsTemp = [0.01+rand(nholos,1)*0.25 0.05+rand(nholos,1)*0.9,...
%     0.05+rand(nholos,1)*0.15 1*ones(nholos,1)];
% slmCoordsTemp = [0.55 0.55 0.045 1];
%slmCoordsTemp = SLMCoordinates(:,8*11+(1:11))';
                  
slmCoordsTemp = [0.45 0.45 0 1;...
                 0.45 0.55 0 1;...
                 0.55 0.45 0 1;...
                 0.55 0.55 0 1];%;...
                 %0.5 0.5 0 1]; %%%% Center square to REALLY center 0-order block
                 xyoff = 0.22;
                 slmCoordsTemp = [slmCoordsTemp;slmCoordsTemp+[xyoff xyoff zslm 1;
                                    xyoff -xyoff zslm 1;
                                    -xyoff xyoff zslm 1;
                                    -xyoff -xyoff zslm 1]];
%slmCoordsTemp = [0.15 0.15 0 1;...
                 %0.15 0.85 0 1;...
                 %0.85 0.15 0 1;...
                 %0.85 0.85 0 1;...
                %0.5 0.5 0 1]; %%%% Corner square to find bounds
 %slmCoordsTemp = [0.3 0.3 0 1;...
                 %0.3 0.7 0 1;...
                 %0.7 0.3 0 1;...
                 %0.7 0.7 0 1;...
                %0.5 0.5 0 1]; %%%% Custom LA
% slmCoordsTemp = [0.4,0.7,0,1;...
%                  0.6,0.7,0,1;...
%                  0.3,0.45,0,1;...
%                  0.35,0.36,0,1;...
%                  0.65,0.36,0,1;...
%                  0.7,0.45,0,1;...
%                  0.5,0.3,0,1]; %%%% SMILEY
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

mssend(masterSocket,[nholos*pwr/1000 1 1]);

function_BasPreview(Setup);
mssend(masterSocket,[0 1 1]); 

%% Collect holos frames (skip for calibration)
mssend(masterSocket,[nholos*pwr/1000 1 1]);
disp('Collecting Background Frames');

nBackgroundFrames = 10;

Bgdframe = function_BasGetFrame(Setup,nBackgroundFrames);% function_Basler_get_frames(Setup, nBackgroundFrames );
Bgd = uint8(mean(Bgdframe,3));
meanBgd = mean(single(Bgdframe(:)));
stdBgd =  std(single(Bgdframe(:)));

threshHold = meanBgd+3*stdBgd;
mssend(masterSocket,[0 1 1]); 

meanframe=mean(Bgdframe,3);
imagesc(meanframe)


%save("C:/Users/MesoSI/Desktop/Lamiae_20240429_MesoHologalvo_characterisations/quadrant_frames/AO0_2_AO1_0_large_5xpower.mat","Bgdframe");



%% Collect background frames for signal to noise testing
disp('Collecting Background Frames');

nBackgroundFrames = 10;

Bgdframe = function_BasGetFrame(Setup,nBackgroundFrames);% function_Basler_get_frames(Setup, nBackgroundFrames );
Bgd = uint8(mean(Bgdframe,3));
meanBgd = mean(single(Bgdframe(:)));
stdBgd =  std(single(Bgdframe(:)));

threshHold = meanBgd+3*stdBgd;

fprintf(['3\x03c3 above mean threshold ' num2str(threshHold,4) '\n'])
%%
%%Collect PSF

figure(1234); clf
Sutter.Reference = getPosition(Sutter.obj);

position = Sutter.Reference;
moveTime=moveTo(Sutter.obj,position);

muPerPix = mean([1209/1024,1503/1280]);
% 1325/1000, 1310/1000
% basler with 600x600 pix roi Mesoscope has a 785um fov
%Camera full res, 1209 um along mouse AP/1024pix (long axis of
%sf), 1503 um along mouse ML/1280pix (short axis of sf)
sz = size(Bgd);
% UZ= -25:5:125;
% UZ = -125:5:25;
UZ = -80:10:80;
 dataUZ = zeros([sz numel(UZ)]);
 nframes = 5;
disp('Collecting PSF') 
 for i=1:numel(UZ)
     position = Sutter.Reference;
     
     position(3) = position(3)+sutterposmult*UZ(i);
     moveTime=moveTo(Sutter.obj,position);
     if i==1
            pause(1)
        else
            pause(0.1);
    end
        
         mssend(masterSocket,[nholos*pwr/1000 1 1]);%la
        invar=[];
        while ~strcmp(invar,'gotit')%la
            invar = msrecv(masterSocket,0.01);%la
        end%la
        frame = function_BasGetFrame(Setup,nframes);%function_Basler_get_frames(Setup, 3 );
        frame = uint8(mean(frame,3));
        
         mssend(masterSocket,[0 1 1]);%la
        invar=[];%la
        while ~strcmp(invar,'gotit')%la
            invar = msrecv(masterSocket,0.01);%tla
        end%ls
        
        frame =  max(frame-Bgd,0);
        frame = imgaussfilt(frame,2);
        dataUZ(:,:,i) =  frame;
        
        figure(1234); 
        subplot(1,2,1)
        imagesc(frame');
%         xtick = set(gca,'XTick',[1:200:1400]/muPerPix);
%         xticklabel = str2num(get(gca,'XTickLabel'))*muPerPix;
%         set(hca,'XTickLabel',xticklabel);
%         ytick = set(gca,'YTick',[1:200:1400]/muPerPix);
%         yticklabel = str2num(get(gca,'YTickLabel'))*muPerPix;
%         set(hca,'yTickLabel',yticklabel);
        colorbar
        axis square
        title(['Frame ' num2str(i)])
        
        subplot(1,2,2)
        imagesc(max(dataUZ,[],3)');
%         xtick = set(gca,'XTick',[1:200:1400]/muPerPix);
%         xticklabel = str2num(get(gca,'XTickLabel'))*muPerPix;
%         set(hca,'XTickLabel',xticklabel);
%         ytick = set(gca,'YTick',[1:200:1400]/muPerPix);
%         yticklabel = str2num(get(gca,'YTickLabel'))*muPerPix;
%         set(hca,'yTickLabel',yticklabel);
        colorbar
        axis square
        title('Max Projection')
        drawnow;
%         pause
 end

        position = Sutter.Reference;
        moveTime=moveTo(Sutter.obj,position);  
disp('done')

%%
%%%%%%%%%%%
% muPerPix = 1040/600; % new basler with 600x600 pix roi
% muPerPix = 660/400; % thor cam with 400x400 pix roi

mxProj = max(dataUZ,[],3);

pklocs = function_findcenters(mxProj,30,nholos); %mxProj,mindist,nholos

npks = size(pklocs,1);
zFWHMs = zeros(npks,1);
fzs = cell(npks,1);
zvals = zeros(numel(UZ),npks);
zstack = zeros(numel(UZ),npks);
xFWHMs = zeros(npks,1);
fxs = cell(npks,1);
xrange = -80:80;
xvals = zeros(npks,length(xrange));
xstack = zeros(npks,length(xrange));
for n=1:npks
% [ x,y ] =function_findcenter(mxProj);
x = pklocs(n,2);
y = pklocs(n,1);

range = 2;
dimx = max((x-range),1):min((x+range),size(dataUZ,1));
dimy =  max((y-range),1):min((y+range),size(dataUZ,2));

thisStack = squeeze(mean(mean(dataUZ(dimx,dimy,:))));
[a peakPlane ] = max(thisStack);
peakFrame = dataUZ(:,:,peakPlane); 
xLine = double(peakFrame(x,y+xrange));
% xSize = linspace(1,1000,numel(xLine)); 
xSize = xrange;
f1 = fit(xSize', xLine', 'gauss1');
xValue =f1.a1;
xDepth =f1.b1;
xFWHM = 2*sqrt(2*log(2))*f1.c1/sqrt(2);
xFWHMs(n) = xFWHM;
fxs{n} = f1;
xvals(n,:) = xSize;
xstack(n,:) = xLine;

ff = fit(UZ', thisStack, 'gauss1');
peakValue =ff.a1;
peakDepth =ff.b1;
peakFWHM = 2*sqrt(2*log(2))*ff.c1/sqrt(2);
zFWHMs(n) = peakFWHM;
fzs{n} = ff;
zvals(:,n) = UZ';
zstack(:,n) = thisStack;

end
%%
figure();clf
for n=1:npks
subplot(1,2,1)
plot(xvals(n,:),xstack(n,:),'o-')
hold on
plot(fxs{n})
legend('hide')
subplot(1,2,2)
plot(zvals(:,n),zstack(:,n),'o-') 
hold on
plot(fzs{n})
legend('hide')
end
subplot(1,2,1)
title(['Lateral Fit FWHM ' num2str(mean(xFWHMs)*muPerPix)])
subplot(1,2,2)
title(['Axial Fit FWHM ' num2str(mean(zFWHMs))])

%%
% save('C:\Users\MesoSI\Documents\MATLAB\MesoHoloCode\Uday\psf_z+80_40kHz_gateON.mat',...
%     'UZ','dataUZ','mxProj','pklocs','npks','zFWHMs','fzs','zvals','zstack',...
%     'xFWHMs','fxs','xvals','xstack','xrange','muPerPix','nholos','SICoordinates','SLMCoordinates')
% save('C:\Users\MesoSI\Documents\MATLAB\Mesopilot_figs\workspace_stack3_smile_20mW.mat')
% save('S:\Lamiae\20221101-PSFsFigure\wsX45Y45Z05eq70umbis.mat')

%%
Sutter.Reference = getPosition(Sutter.obj);

position = Sutter.Reference;
moveTime=moveTo(Sutter.obj,position);

[ HoloTemp,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,slmCoordsTemp );
blankHolo = zeros([1920 1152]);
Function_Feed_SLM( Setup.SLM, HoloTemp);
mssend(masterSocket,[nholos*pwr/1000 1 1]);
function_BasPreview(Setup);

UZ = [-50:5:50,-50:5:50,-50:5:50,-50:5:50];
 dataUZ = zeros([sz numel(UZ)]);
 nframes = 5;
disp('Scanning depths ...') 
 for i=1:numel(UZ)
     position = Sutter.Reference;
     
     position(3) = position(3)+sutterposmult*UZ(i);
     moveTime=moveTo(Sutter.obj,position);
     if i==1
            pause(1)
        else
            pause(0.1);
     end
 end
 %% RESET everything
 mssend(masterSocket,[0 1 1]);
 position = Sutter.Reference;
 moveTime=moveTo(Sutter.obj,position);