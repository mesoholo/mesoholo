%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/duplicateTrimmer.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [temp] = duplicateTrimmer(masterxy,calibratedTargets)

ntargs = size(calibratedTargets,1);
temp = [calibratedTargets(:,1:2);masterxy];
sztemp1 = size(temp,1);
sztemp1;

distflag = 1;
while(distflag)
    %         figure(101)
    %         plot(temp(:,1),temp(:,2),'o','col',[rand rand rand])
    %         pause
    sztemp1 = size(temp,1);
    i=1;
    while i<=size(temp,1)
        distvec = pdist2(temp,temp(i,:));
        distvec(i) = 999;
        rminds = find(distvec<=2.5);
        rminds(rminds<=ntargs)=[];
        %         pause
        temp(rminds,:) = [];
        i= i+1;
    end
    sztemp2 = size(temp,1);
    if(sztemp2==sztemp1)
        distflag = 0;
        sztemp2;
        disp('Trimming done')
    end   
end

temp = round(temp);