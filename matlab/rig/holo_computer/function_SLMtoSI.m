%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/holo_computer/function_SLMtoSI.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [SIXYZ] = function_SLMtoSI(SLMXYZ,CoC)

if size(SLMXYZ,2)==4
    SLMXYZ = SLMXYZ(:,1:3);
end

approachMethod = 2;

% SItoCam = CoC.SItoCam;
% OptZToCam = CoC.OptZToCam;
% camToSLM = CoC.camToSLM;
% SLMtoPower = CoC.SLMtoPower;

CamToSI = CoC.CamToSI;
SLMtoCam = CoC.SLMtoCam;
camToOpto = CoC.camToOpto;

if approachMethod==1
estCam = function_Eval3DCoC(SLMtoCam,SLMXYZ);
estOpto = polyvaln(camToOpto,estCam);
estSI = function_Eval3DCoC(CamToSI,estCam);

SIXYZ = [estSI(:,1:2) estOpto];

else
%shortcut approach
% estSLM = function_Eval3DCoC(CoC.SItoSLM,test);
estSI = function_Eval3DCoC(CoC.SLMtoSI,SLMXYZ);
SIXYZ = estSI;
end
