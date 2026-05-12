%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/holo_computer/function_3DCoC.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function CoC = function_3DCoC(refAsk,refGet,modelterms)

FitX =  polyfitn(refAsk,refGet(:,1),modelterms);
FitY =  polyfitn(refAsk,refGet(:,2),modelterms);
FitZ =  polyfitn(refAsk,refGet(:,3),modelterms);

% methodstr = 'cubicinterp';
% FitX = fit(refAsk(:,1),refGet(:,1),methodstr);
% FitY = fit(refAsk(:,2),refGet(:,2),methodstr);
% FitZ = fit(refAsk(:,3),refGet(:,3),methodstr);

% FitX = ridge(refGet(:,1),refAsk,0.5,0);
% FitY = ridge(refGet(:,2),refAsk,0.5,0);
% FitZ = ridge(refGet(:,3),refAsk,0.5,0);

CoC.FitX = FitX;
CoC.FitY = FitY;
CoC.FitZ = FitZ;