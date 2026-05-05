function [ mesoRequest ] = make_mesoRequest_uday(all_XYnew,all_centersZ,all_yoffsets,all_xoffsets,xrotate,yrotate,all_zMaps,all_AO0s,all_AO1s,all_powers,hSI,Zplanes,powcurve)
%make_mesoRequest: Generates mesoscale holoRequest 
%   Detailed explanation goes here
loc = MesoLocFile_SI();
mesoRequest.objective = 20;
mesoRequest.zoom = hSI.hRoiManager.scanZoomFactor;
zoomscalef = 1/mesoRequest.zoom;
groupID = 1;
nfovs = size(all_XYnew,2);
mesoRequest.groupID = [];
mesoRequest.AO0 = [];
mesoRequest.AO1 = [];
mesoRequest.powerfactors = [];
mesoRequest.zRemapping = {};
mesoRequest.xoffRemapping = {};
mesoRequest.yoffRemapping = {};
mesoRequest.targets = [];
mesoRequest.actualtargets = [];
mesoRequest.xoffset = [];
mesoRequest.yoffset = [];
mesoRequest.ignoreROIdata = 1;

for f = 1:nfovs
    if isempty(all_XYnew{1,f})
        
    else
        ntargets = size(all_XYnew{1,f},1);
        mesoRequest.groupID = [mesoRequest.groupID, groupID*ones(1,ntargets)];
        mesoRequest.AO0(1,groupID) = all_AO0s{1,f};
        mesoRequest.AO1(1,groupID) = all_AO1s{1,f};
        mesoRequest.powerfactors(1,groupID) = all_powers{1,f};
        
        %XY xoordinates
        
        curr_xoffset = all_xoffsets{1,f};
        curr_yoffset = all_yoffsets{1,f};
        curr_xynew = all_XYnew{1,f};
        
        sipix = 512;
        lx=680;
        ly=680;
        if(~isnan(curr_xoffset))
            MODxoffset = curr_xoffset*zoomscalef;%*sipix/lx;
        end
        if(~isnan(curr_yoffset))
            MODyoffset = curr_yoffset*zoomscalef;%*sipix/ly;
        end
        
        centerXY = zeros(ntargets,2);
        centerXY = fliplr(curr_xynew);
        %centerXY(sum(centerXY,2)==2,:) = [];
        
        centerZ = zeros(ntargets,1);
        centerZ = all_centersZ{1,f};
        %(sum(centerXY,2)==2,:) = [];
        
        % Z coordinate
        %Hacky Z Correction added by Ian 9/30/19
        zMap = all_zMaps{1,f};
        if isempty(zMap) || numel(zMap)==1 || all(zMap(:)~=Zplanes)
            %don't change z Mapping
            mesoRequest.zRemapping(1,groupID)=0;
            centerZc = centerZ;
            MODxoffset = 0;
            MODyoffset = 0;
        else
            if(isnan(curr_xoffset))
                w = fit(zMap(1,:)',xrotate'*zoomscalef,'cubicinterp');
                MODxoffset = w(centerZ);%*sipix/lx;
                mesoRequest.xoffRemapping{1,groupID} = w;
            end
            if(isnan(curr_yoffset))
                w = fit(zMap(1,:)',yrotate'*zoomscalef,'cubicinterp');
                MODyoffset = w(centerZ);%*sipix/ly;
                mesoRequest.yoffRemapping{1,groupID} = w;
            end
            %remap Z
            w = fit(zMap(1,:)',zMap(2,:)','cubicinterp');
            centerZc=w(centerZ);
            mesoRequest.zRemapping{1,groupID} = w;
        end
        
        targets=[centerXY centerZc];
        actualtargets = [centerXY centerZ];
        mesoRequest.targets = [mesoRequest.targets;targets];
        mesoRequest.actualtargets = [mesoRequest.actualtargets;actualtargets];

        
        mesoRequest.xoffset(1,groupID) = MODxoffset;
        mesoRequest.yoffset(1,groupID) = MODyoffset;    
        
        groupID = groupID+1;
        
    end


end

%%%% Temp Uday 08/06/24 random patterns at weight level - comment out
% ncells = 51;
% ngroups = 50;
% mesoRequest.roiWeights = ones(1,ncells);
% mesoRequest.roiWeights = [mesoRequest.roiWeights;linspace(0.05,1,ncells)];
% mesoRequest.roiWeights = [mesoRequest.roiWeights;linspace(1,0.05,ncells)];
% for i=4:ngroups
%     mesoRequest.roiWeights = [mesoRequest.roiWeights;0.05+0.95*rand(1,ncells)];
% end
% mesoRequest.roiWeights = ncells*mesoRequest.roiWeights./sum(mesoRequest.roiWeights,2);
% mesoRequest.groupID = [];
% for i=1:ngroups
%     mesoRequest.groupID = [mesoRequest.groupID;i*ones(1,ncells)];
% end
% mesoRequest.groupID = mesoRequest.groupID';
% mesoRequest.groupID = mesoRequest.groupID(:);
% mesoRequest.AO0 = repmat(mesoRequest.AO0,[1,ngroups]);
% mesoRequest.AO1 = repmat(mesoRequest.AO1,[1,ngroups]);
% mesoRequest.powerfactors = repmat(mesoRequest.powerfactors,[1,ngroups]);
% mesoRequest.xoffset = repmat(mesoRequest.xoffset,[1,ngroups]);
% mesoRequest.yoffset = repmat(mesoRequest.yoffset,[1,ngroups]);
%%%%

%%%% Temp Uday 08/19/24 random patterns at dF level - comment out
goodcells = powcurve.goodcells;
satpows = powcurve.satpows;
satinds = powcurve.satinds;
allvalmat = powcurve.allvalmat;
allpowmat = powcurve.allpowmat;
allpows = powcurve.allpows;
ncells = length(goodcells);
ngroups = 50;
%%%% For random F recreation
desiredvec = 0.5*ones(1,ncells);
% desiredvec(1,:) = desiredvec(1,:).*allvalmat(:,end)';
for i=2:ngroups
    if(i==2)
        desiredvec = [desiredvec;0.05+0.95*rand(1,ncells)];
%         desiredvec(i,:) = desiredvec(i,:).*allvalmat(:,end)';
    else
        desiredvec = [desiredvec;desiredvec(2,randperm(ncells))];
    end
end
%%%%
%%%% For vis vec recreation
% desiredvec = powcurve.visvec;
% desiredvec = [desiredvec;mean(desiredvec)*ones(1,ncells)];
% for i=3:ngroups
%     desiredvec = [desiredvec;desiredvec(1,randperm(ncells))];
% end
%%%% For random F recreation w/average patterns
% nbasepatterns = 5;
% desiredvec = [];
% for i=1:nbasepatterns
%     if(i==1)
%         desiredvec = [desiredvec;0.1+0.9*rand(1,ncells)];
%         desiredvec(i,:) = desiredvec(i,:).*allvalmat(:,end)';
%     elseif(i==2)
%         [~,indsd] = sort(mean(desiredvec(1:i-1,:),1),'descend');
%         [~,indsa] = sort(mean(desiredvec(1:i-1,:),1),'ascend');
%         tempvec = mean(desiredvec(1:i-1,:),1);
%         tempvec(indsd) = tempvec(indsa);
%         desiredvec = [desiredvec;tempvec];
%     else
%         nranditer = 100000;
%         tempvecmat = zeros(nranditer,ncells);
%         for j=1:nranditer
%             tempvecmat(j,:) = desiredvec(1,randperm(ncells));
%         end
%         tempsimvec = corr(tempvecmat',desiredvec');
%         tempsimvec(tempsimvec>=-0.05)=NaN;
%         [~,tempsiminds] = sort(mean(tempsimvec,2),'ascend');
%         desiredvec = [desiredvec;tempvecmat(tempsiminds(1),:)];
%     end
% end
% % desiredvec = (desiredvec./sum(desiredvec,2))*ncells/2;
% desiredvec = desiredvec*2;
% for i=1:nbasepatterns
%     for j=i+1:nbasepatterns
%         desiredvec = [desiredvec;(desiredvec(i,:)+desiredvec(j,:))/2];
%     end
% end
% %%%% Additional 5 vectors half of original so the previous means are the
% %%%% sums of these
% for i=1:nbasepatterns
%     desiredvec = [desiredvec;desiredvec(i,:)/2];
% end
% ngroups = size(desiredvec,1)
%%%%
% desiredvec = desiredvec./allvalmat(:,end)';
%%%% 
mesoRequest.desiredvec = [];
mesoRequest.desiredFvec = [];
mesoRequest.roiWeights = [];
for i=1:ngroups
    mesoRequest.desiredvec = [mesoRequest.desiredvec;desiredvec(i,:)];
    desiredvec(i,:) = desiredvec(i,:).*allvalmat(:,end)';
    [~,p0inds] = min(abs(allvalmat-desiredvec(i,:)'),[],2);
    p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));
    p0 = [];
    for j=1:length(p0inds)
        p0 = [p0;allpows(p0inds(j))];
    end
    mesoRequest.roiWeights = [mesoRequest.roiWeights;p0'];
    mesoRequest.desiredFvec = [mesoRequest.desiredFvec;desiredvec(i,:)];
end
mesoRequest.groupID = [];
for i=1:ngroups
    mesoRequest.groupID = [mesoRequest.groupID;i*ones(1,ncells)];
end
mesoRequest.groupID = mesoRequest.groupID';
mesoRequest.groupID = mesoRequest.groupID(:);
mesoRequest.AO0 = repmat(mesoRequest.AO0,[1,ngroups]);
mesoRequest.AO1 = repmat(mesoRequest.AO1,[1,ngroups]);
mesoRequest.powerfactors = repmat(mesoRequest.powerfactors,[1,ngroups]);
mesoRequest.xoffset = repmat(mesoRequest.xoffset,[1,ngroups]);
mesoRequest.yoffset = repmat(mesoRequest.yoffset,[1,ngroups]);
%%%%


try
    save([loc.HoloRequest_SI 'holoRequest.mat'],'mesoRequest');
    save([loc.HoloRequest_DAQ 'holoRequest.mat'],'mesoRequest');
catch
    disp('****WARNING: HOLOREQUEST SAVE ERROR!!! Find another way...****')

end

