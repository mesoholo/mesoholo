%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/visual_stim/gen_wininfo_uday.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function wininfo = gen_wininfo_uday(result)
%gen_wininfo_uday  Initialize Psychtoolbox window and geometry conversions.
%
% wininfo = gen_wininfo_uday(result)
%
% Purpose
% - Opens a Psychtoolbox window and computes pixel↔degree conversions given
%   the monitor size and viewing distance.
% - Packages window handles, geometry, and a background texture into `wininfo`
%   for downstream stimulus code (`gen_gratings_uday`, `generateNoise_xyt_uday`).
%
% Inputs
% - result: struct created by the stimulus runner (e.g. `run_gratings_*`).
%   Expected fields include `DScreen` (cm), `VertScreenSize` (cm),
%   `HorzScreenSize` (cm), and optionally background parameters.
%
% Output
% - wininfo: struct containing Psychtoolbox window (`w`), rects, frame rate,
%   pixel-per-degree scale factors, and a pre-made background texture (`BG`).

%% Select background color / luminance
Bcol = 128;
screenNumber = max(Screen('Screens'));
% screenNumber = 1;
blI = BlackIndex(screenNumber);
whI = WhiteIndex(screenNumber);

blI = BlackIndex(screenNumber);
whI = WhiteIndex(screenNumber);

if isfield(result, 'background') 
    switch result.background
        case 'w'
            Bcol = whI;
        case 'g'
            Bcol = (blI+whI)/2;
        case 'k'
            Bcol = blI;
        otherwise
            error('background color was misspecified')
    end
else
    Bcol = (blI+whI)/2;
end

if isfield(result, 'backgroundcontrast') 
    Bcol = blI + (whI-blI)*result.backgroundcontrast;
end

%% Optional: gamma correction lookup (rig-specific)
try
if result.GammaCorrect
    if isempty(which('mesoholo_repo_root'))
        addpath(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    end
    gammaMat = getenv('MESOHOLO_GAMMA_LUT');
    if isempty(gammaMat)
        gammaMat = fullfile(mesoholo_repo_root(), 'data', 'fixtures', 'gamma', 'scaledluxvalues20260325.mat');
    end
    scaledluxvals = load(gammaMat);
    [~,Bcol] = min(abs(scaledluxvals.scaledluxvals - (Bcol/255)));
end
catch
end

%% Open Psychtoolbox window (panel fitter for consistent framebuffer scaling)
scaleby = 0.5;
xRes = RectWidth(Screen('Rect', screenNumber))*scaleby;
yRes = RectHeight(Screen('Rect', screenNumber))*scaleby;
fitSize = [xRes,yRes];
%
AssertOpenGL; % Psychtoolbox function

PsychImaging('PrepareConfiguration');

PsychImaging('AddTask', 'General', 'UsePanelFitter', fitSize, 'Aspect');

Screen('Preference', 'VBLTimestampingMode', -1);
wininfo.skipSync = 0;
if wininfo.skipSync == 1
    disp('HEY BIG WARNING SINK OFF')
end
Screen('Preference','SkipSyncTests', wininfo.skipSync);
% Screen('Preference','SkipSyncTests', 0);

% Center small framebuffer inside big framebuffer. Scale it up to
% maximum size while preserving aspect ration of the original
% framebuffer:

[w,windowRect] = PsychImaging('OpenWindow',screenNumber,Bcol); %Screen('OpenWindow',screenNumber);
% HideCursor()

%% Monitor geometry and pixels-per-degree conversion
[sw,sh] = Screen('DisplaySize',screenNumber);
sw = result.HorzScreenSize*10;
sh = result.VertScreenSize*10;
if ~(sw==197 && sh==148)
    disp('check monitor size rig 2')
end
screenWidth = sw/10;
screenHeight = sh/10;

% VertScreenDimDeg = atand(result.VertScreenSize/result.DScreen); % in visual degrees
% PixperDeg = yRes/VertScreenDimDeg;
DiagPix = sqrt(xRes^2+yRes^2);
Diagcm = sqrt(screenWidth^2+screenHeight^2);
DiagDeg = 2*atand((Diagcm/2)/result.DScreen); % viewing angle: 116.2 degrees in rig computer (on 200106)
DPixperDeg = DiagPix / DiagDeg;
XDeg = 2*atand((screenWidth/2)/result.DScreen); % viewing angle: 102.8 degrees in rig computer (on 200106)
XPixperDeg = xRes / XDeg;
YDeg = 2*atand((screenHeight/2)/result.DScreen); % viewing angle: 90.2 degrees in rig computer (on 200106)
YPixperDeg = yRes / YDeg;
try
    xposStim = result.position(:,1);
    yposStim = result.position(:,2);
catch
    xposStim = NaN;
    yposStim = NaN;
end
frameRate = Screen('FrameRate',screenNumber);

%% Package outputs
wininfo.xRes = xRes;
wininfo.yRes = yRes;
wininfo.w = w;
wininfo.windowRect = windowRect;
wininfo.screenWidthcm = screenWidth;
wininfo.screenHeightcm = screenHeight;
wininfo.DiagPix = DiagPix;
wininfo.Diagcm = Diagcm;
wininfo.DiagDeg = DiagDeg;
wininfo.DPixperDeg = DPixperDeg;
wininfo.XDeg = XDeg;
wininfo.XPixperDeg = XPixperDeg;
wininfo.YDeg = YDeg;
wininfo.YPixperDeg = YPixperDeg;
wininfo.PixperDeg = YPixperDeg;
wininfo.xposStim = xposStim;
wininfo.yposStim = yposStim;
wininfo.frameRate = frameRate;
% wininfo.ifi = ifi;
wininfo.Bcol = Bcol;
wininfo.blI = blI;
wininfo.whI = whI;
wininfo.grI = (blI + whI)/2;
wininfo.screenNumber = screenNumber;

wininfo.scaleby= scaleby;
bg = ones(yRes,xRes)*Bcol;
wininfo.BG = Screen('MakeTexture', wininfo.w, bg);
end