%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/holo_computer/function_3DCoCIterative.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [CoC, trialN] = function_3DCoCIterative(refAsk,refGet,modelterms,errScalar,Verbose,fignum);

nIter = 500;
totN = size(refAsk,1);
trialN = 1:totN;

slowway = 1;
%  errScalar =2.5;

go=1; c=0;
errs = false([totN 1]);
while go
    refAsk(errs,:) =[];
    refGet(errs,:) = [];
    trialN(errs)=[];
    c=c+1;
    CoC = function_3DCoC(refAsk,refGet,modelterms);
%     CoC = function_RegressPoly3D(refAsk,refGet,modelterms);
    Get = function_Eval3DCoC(CoC,refAsk,modelterms);
    RMS = sqrt(sum((Get-refGet).^2,2));
    
    errs = RMS>mean(RMS)+std(RMS)*errScalar;
    %%slow way might be better
    if slowway
        if sum(errs)>0;
            [a b] = max(RMS);
            errs = false([1 size(refAsk,1)]);
            errs(b)=1;
        end
    end
    
    if Verbose
    disp(['Pass ' num2str(c) '. RMS error: ' num2str(mean(RMS)) '. Trials to exclude: ' num2str(sum(errs))]);
    end
    if sum(errs)==0 || c>nIter || (numel(trialN)-sum(errs))<=size(modelterms,1)
        go=0;
        disp('Converged as much as we want')
        if (numel(trialN)-sum(errs))<=size(modelterms,1)
            disp(['Error Did Not Converge!'])
        end
    end
end
disp([num2str(totN-numel(trialN)) ' of ' num2str(totN) ' Trials excluded due to excess error']);

figure(fignum);clf
scatter3(refGet(:,1),refGet(:,2),refGet(:,3),'o')
hold on
scatter3(Get(:,1),Get(:,2),Get(:,3),'*','r')