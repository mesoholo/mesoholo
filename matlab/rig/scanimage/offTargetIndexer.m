function [tempinds] = offTargetIndexer(masterxy,nstim,varargin)
if(nargin<=2)
    distthresh = 50;
else
    distthresh = varargin{1};
end


ntargs = nstim;
temp = masterxy;
sztemp1 = size(temp,1);
sztemp1;

offxy = [];

distflag = 1;
while(distflag)
%             figure(101)
%             plot(temp(:,1),temp(:,2),'o','col',[rand rand rand])
%             pause
    sztemp1 = size(temp,1);
    i=1;
    while i<=nstim
        distvec = pdist2(temp,temp(i,:));
        distvec(i) = 999;
        offinds = find(distvec<=distthresh);
        offinds(offinds<=ntargs)=[];
%                 pause
        offxy = [offxy;temp(offinds,:)];
        temp(offinds,:) = [];
        i= i+1;
    end
    sztemp2 = size(temp,1);
    if(sztemp2==sztemp1)
        distflag = 0;
        sztemp2;
        disp('Off-target indexing done')
    end   
end

tempinds = find(ismember(masterxy,offxy,'rows'));