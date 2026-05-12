%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/scanimage/make_mesoRequest_uday.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [ mesoRequest ] = make_mesoRequest_uday(all_XYnew,all_centersZ,all_yoffsets,all_xoffsets,xrotate,yrotate,all_zMaps,all_AO0s,all_AO1s,all_powers,hSI,Zplanes,powcurve)
%make_mesoRequest_uday  Build a multi-FOV mesoscale holoRequest struct.
%
% This function collates targets from multiple ScanImage FOVs into a single
% request structure written to the shared Holorequest folders. Historically,
% several experimental modes were toggled by commenting/uncommenting blocks;
% those are now controlled via `cfg` below.

%% Configuration (toggle behavior here)
cfg = struct();

% - **Save behavior**
cfg.saveToShared = true;  % write to HoloRequest_SI and HoloRequest_DAQ

% - **Weight/randomization modes**
% Some experiments used synthetic/random desired activation patterns to test
% power-curve fitting and pattern generation. Set this false for "normal"
% targeting behavior (no `roiWeights`/desired vectors added).
cfg.randomDesiredF = struct();
cfg.randomDesiredF.enabled = true;     % preserves current script behavior
cfg.randomDesiredF.nGroups = 50;
cfg.randomDesiredF.baseLevel = 0.5;    % baseline desired (0..1) per ROI
cfg.randomDesiredF.minLevel = 0.05;
cfg.randomDesiredF.maxLevel = 1.0;

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

%% Optional: generate synthetic desired-F patterns and convert to roiWeights
if cfg.randomDesiredF.enabled
    allvalmat = powcurve.allvalmat;
    satinds = powcurve.satinds;
    allpows = powcurve.allpows;

    ncells = length(powcurve.goodcells);
    ngroups = cfg.randomDesiredF.nGroups;

    % Build desired patterns (0..1) then scale by each ROI’s max response.
    desired01 = cfg.randomDesiredF.baseLevel * ones(1, ncells);
    for i = 2:ngroups
        if i == 2
            desired01 = [desired01; cfg.randomDesiredF.minLevel + ...
                (cfg.randomDesiredF.maxLevel - cfg.randomDesiredF.minLevel) * rand(1, ncells)];
        else
            desired01 = [desired01; desired01(2, randperm(ncells))];
        end
    end

    mesoRequest.desiredvec = desired01;
    mesoRequest.desiredFvec = [];
    mesoRequest.roiWeights = [];

    for i = 1:ngroups
        desiredF = desired01(i,:) .* allvalmat(:,end)'; % scale to per-ROI max
        [~,p0inds] = min(abs(allvalmat - desiredF'), [], 2);
        p0inds(p0inds==length(allpows)) = satinds(p0inds==length(allpows));

        p0 = zeros(length(p0inds),1);
        for j = 1:length(p0inds)
            p0(j) = allpows(p0inds(j));
        end

        mesoRequest.roiWeights = [mesoRequest.roiWeights; p0'];
        mesoRequest.desiredFvec = [mesoRequest.desiredFvec; desiredF];
    end

    % Expand group-level metadata to per-pattern groups.
    mesoRequest.groupID = [];
    for i = 1:ngroups
        mesoRequest.groupID = [mesoRequest.groupID; i*ones(ncells,1)];
    end
    mesoRequest.AO0 = repmat(mesoRequest.AO0,[1,ngroups]);
    mesoRequest.AO1 = repmat(mesoRequest.AO1,[1,ngroups]);
    mesoRequest.powerfactors = repmat(mesoRequest.powerfactors,[1,ngroups]);
    mesoRequest.xoffset = repmat(mesoRequest.xoffset,[1,ngroups]);
    mesoRequest.yoffset = repmat(mesoRequest.yoffset,[1,ngroups]);
end


if cfg.saveToShared
    try
        save([loc.HoloRequest_SI 'holoRequest.mat'],'mesoRequest');
        save([loc.HoloRequest_DAQ 'holoRequest.mat'],'mesoRequest');
    catch
        disp('****WARNING: HOLOREQUEST SAVE ERROR!!! Find another way...****')
    end
end

