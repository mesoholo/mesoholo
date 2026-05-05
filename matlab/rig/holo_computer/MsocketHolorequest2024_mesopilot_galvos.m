 %% 
% function MsocketHolorequest2020

%clear all
timeout = 5000;

%% Configuration (toggle behavior here)
cfg = struct();
cfg.applyShearCorrection = false;  % legacy "quick fix" for anisotropic offsets
cfg.shear = struct();
cfg.shear.rxDelta = 0;
cfg.shear.lxDelta = 0;
cfg.shear.right = struct('dx', 0.025, 'dy', 0.01, 'pow', 1);
cfg.shear.left  = struct('dx', 0.025, 'dy', 0.015,'pow', 1);

mesoholo_setup();
disp('done pathing')

calibPath = getenv("MESOHOLO_CALIB_PATH");
if strlength(calibPath) == 0
    error(['MESOHOLO_CALIB_PATH is not set. ' ...
        'Point it to a folder containing ActiveCalib.mat (with variable CoC).']);
end
load(fullfile(char(calibPath), 'ActiveCalib.mat'), 'CoC');


[Setup ] = function_loadparameters2();
Setup.CGHMethod = 2;
Setup.verbose = 0;
Setup.useGPU = 1;
Setup.maxiter = 20;
gpuDevice([]);
gpuDevice(1);

% cycleiterations =1; % Change this number to repeat the sequence N times instead of just once

%Overwrite delay duration
Setup.TimeToPickSequence = 0.05;    %second window to select sequence ID
Setup.SLM.timeout_ms = timeout;     %No more than 2000 ms until time out
% calibID =1;                     % Select the calibration ID (z1=1 but does not exist, Z1.5=2, Z1 sutter =3);

%% now start msocket communication
 
disp('Waiting for msocket communication (run xxExpRunnerxx on daq and stuff on SI)')

%%do this one first
%then wait for a handshake
srvsock = mslisten(3054);
masterSocket = msaccept(srvsock,60); % Timeout after 60s
% flushMSocket(masterSocket);
msclose(srvsock)
sendVar = 'A';
mssend(masterSocket, sendVar);
%MasterIP = '128.32.177.160';
%masterSocket = msconnect(MasterIP,3002);

invar = [];

while ~strcmp(invar,'B');
invar = msrecv(masterSocket,.5);


end;
disp('communication from Master To Holo Established');

x = 1;     HRin = []; 

while x>0
    HRin = msrecv(masterSocket,5);%listening to Master socket to get holorequest structure

    if ~isempty(HRin);
        disp('new File Detected - running HoloRequest')
        holoRequest = HRin;
        x=0; %once you got it finish listening
    end
end

%%Load SI Coordinates

if ~isfield(holoRequest,'ignoreROIdata')  %if we're doing things normally  %ignoreROIdata existing is a 0 or 1 variable in Holorequest struct
    try
        load([Setup.Holorequestpath 'ROIData.mat']);
    catch
        disp('No ROIData file')
        return
    end
    LN = numel(ROIdata.rois);  %if for blind map grid this is 216x3x number of depths(6)?
    SICoordinates = zeros(3,LN);
    for i = 1:LN
        u = mean(ROIdata.rois(i).vertices); %what vertices-wt is that?
        u(1)=u(1)+holoRequest.xoffset(:);
        u(2)=u(2)+holoRequest.yoffset(:);
        
        SICoordinates(1:2,i) = u;
        SICoordinates(3,i) = ROIdata.rois(i).OptotuneDepth;
    end
    SLMCoordinates = zeros(4,LN);
    
else  %if I'm doing a custom sequence
  LN = size(holoRequest.targets,1);  %for blind mapping LN=216
    SLMCoordinates = zeros(4,LN);  
    SICoordinates = holoRequest.targets; % Nx3: [x y z] in SI coordinates
    % Apply group-level XY offsets (xoffset/yoffset are indexed by groupID).
    for t = 1:LN
        g = holoRequest.groupID(t);
        SICoordinates(t,1) = SICoordinates(t,1) + holoRequest.xoffset(g);
        SICoordinates(t,2) = SICoordinates(t,2) + holoRequest.yoffset(g);
    end
    SICoordinates = SICoordinates'; % 3xN for downstream code
end
%%quickly compute Difraction Efficiencies (DE)  and return them over
%%msocket (that is used by H for power balancing fitting)

%% Optional: anisotropic "shear" correction (legacy calibration workaround)
xcenter = mean(SICoordinates(2,:));
rxcenter = xcenter + cfg.shear.rxDelta;
lxcenter = xcenter - cfg.shear.lxDelta;
if cfg.applyShearCorrection
    rMask = SICoordinates(2,:) > rxcenter;
    lMask = SICoordinates(2,:) < lxcenter;

    SICoordinates(1,rMask) = SICoordinates(1,rMask) - cfg.shear.right.dx * (xcenter - SICoordinates(2,rMask)).^cfg.shear.right.pow;
    SICoordinates(2,rMask) = SICoordinates(2,rMask) - cfg.shear.right.dy * (xcenter - SICoordinates(2,rMask)).^cfg.shear.right.pow;

    SICoordinates(1,lMask) = SICoordinates(1,lMask) - cfg.shear.left.dx  * (xcenter - SICoordinates(2,lMask)).^cfg.shear.left.pow;
    SICoordinates(2,lMask) = SICoordinates(2,lMask) - cfg.shear.left.dy  * (xcenter - SICoordinates(2,lMask)).^cfg.shear.left.pow;
end

if isfield(holoRequest,'roiWeights')   %holorequest do not have roiWeights feature at the start, Daq needs to change the struct
    weightsToUse = holoRequest.roiWeights;
    weightsToUse(isnan(weightsToUse))=1;
    disp('Weighting Holograms based on roiWeights')
else
    weightsToUse = ones([1 LN]);
    disp('NO weights detected using flat weight')
end

AC=[];DE_list=[];
[AC, DE_list] = computeDEfromList(SICoordinates, holoRequest.rois, weightsToUse);

%%Compute SLM Coordinates
DEfloor = 0.25;

[SLMCoordinates] = function_SItoSLM(SICoordinates',CoC)';
AttenuationCoeffs =SLMCoordinates(4,:);
% AttenuationCoeffs(AttenuationCoeffs > 0) = 1; %%%% ONLY for no DE correction
% DE_list(DE_list > 0) = 1; %%%% ONLY for no DE correction
lowDE = AttenuationCoeffs<DEfloor;
AttenuationCoeffs(lowDE)=DEfloor;
SLMCoordinates(4,lowDE)=DEfloor;
disp([num2str(sum(lowDE)) ' Target(s) below Diffraction Efficiency floor (' num2str(DEfloor) ').']);

%%%% For PPSF
% DE_list = mean(DE_list)*ones(size(DE_list));
%%%%
mssend(masterSocket,DE_list);
disp('Sent DE to master');

SLMCoordinates(4,:) = 1./SLMCoordinates(4,:);
SLMCoordinates(3,:) = round(SLMCoordinates(3,:),3);
SLMCoordinates(1,SLMCoordinates(1,:)>=1)=0.99;
SLMCoordinates(1,SLMCoordinates(1,:)<=0)=0.01;
SLMCoordinates(2,SLMCoordinates(2,:)>=1)=0.99;
SLMCoordinates(2,SLMCoordinates(2,:)<=0)=0.01;

%%
% close all
% f = figure('units','normalized','innerposition',[0.125 0.3 0.75 0.5]);

figure()
subplot('Position',[0.05 0.2 0.3 0.6])
scatter3(SICoordinates(1,:),SICoordinates(2,:),SICoordinates(3,:),[],SLMCoordinates(4,:),'filled'); 
% colorbar;
xlabel('X, SI coordinates');ylabel('Y, SI coordinates'); zlabel('Z, SI coordinates'); title('Intensity Correction coefficients');
set(gca,'View',[90,90])
axis square
subplot('Position',[0.4 0.2 0.3 0.6])
scatter3(SLMCoordinates(1,:),SLMCoordinates(2,:),SLMCoordinates(3,:),[],SLMCoordinates(4,:),'filled'); 
% colorbar;
set(gca,'zlim',[-0.1 0.1])
set(gca,'View',[180,-90])
xlabel('X, SLM coordinates');ylabel('Y, SLM coordinates'); zlabel('Z, SLM coordinates'); title('Intensity Correction coefficients');
axis square
subplot('Position',[0.75 0.2 0.2 0.6])
hist(AttenuationCoeffs,20);
ylabel('Count')
xlabel('Single Target Diffraction Efficiency')
title('Histogram of Diffraction Efficiencies')
pause(1);



%%Sort Holograms

% holoRequest.rois;

numTargets = cellfun(@(x) numel(x),holoRequest.rois);

numSolo = sum(numTargets<=1);
solos = find(numTargets<=1);
numMid  = sum(numTargets>1 & numTargets < 25);
mids = find(numTargets>1 & numTargets < 25);
numLarge = sum(numTargets>=25 & numTargets < 50);
larges = find(numTargets>=25 & numTargets < 50);
numExtraLarge = sum( numTargets >= 50);
extraLarges =find( numTargets >= 50);


%%Compile Holograms
%optomized for our hologram computer that has a certain amount of gpu space
if size(weightsToUse,2)==1
    weightsToUse=weightsToUse';
end

SLMCoordinates(4,:)=SLMCoordinates(4,:).*weightsToUse; %I don't think this will do anything for single target holos but i'm not sure.

% for i=1:numSolo
%     hololist{i}=sparse(zeros(1920,1152));
%     temphololist{i} = sparse(zeros(1920,1152));
% end
%solos
tic
clear hololist
if numSolo ==0
    disp('No Single Target Holos')
elseif numSolo<60
    disp('Less than 40 Single Holo Targets')
    for i=1:numSolo
        j=solos(i);
        disp(['Now compiling hologram ' int2str(i) ' of ' int2str(numel(solos))])
        ROIselection = holoRequest.rois{j};
        myattenuation = AttenuationCoeffs(ROIselection);
        energy = 1./myattenuation; 
        energy = energy/sum(energy);
        DE(j) = sum(energy.*myattenuation);
        disp(['Diffraction efficiency of the hologram : ' int2str(100*DE(j)) '%']);
        subcoordinates = SLMCoordinates(:,ROIselection);
        [ Hologram,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates' );
        hololist{j} = Hologram;
    end
else 
    disp('More than 40 Single Holo Targets')
    chunksize = 100;
    nchunks = ceil(numSolo/chunksize);
    clear tempDE temphololist
    ROIs =  holoRequest.rois([solos]);
    p =gcp('nocreate');
    if isempty(p) || ~isprop(p,'NumWorkers') || p.NumWorkers ~=5
        delete(p);
        parpool(5);
    end
    tholos = tic;
%     for chunk = 1:nchunks
%         currholos = (chunk-1)*chunksize+(1:chunksize);
%         if(chunk==nchunks)
%             currholos = (chunk-1)*chunksize+(1:mod(numSolo,chunkSize));
%         end
            
    parfor j=1:numSolo
        disp(['Now compiling hologram ' int2str(j) ' of ' int2str(numel(solos))])
        ROIselection =ROIs{j};
        myattenuation = AttenuationCoeffs(ROIselection);
        energy = 1./myattenuation; energy = energy/sum(energy);
        tempDE(j) = sum(energy.*myattenuation);
        disp(['Diffraction efficiency of the hologram : ' int2str(100*tempDE(j)) '%']);
        subcoordinates = SLMCoordinates(:,ROIselection);
        [ Hologram,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates' );
        temphololist{j} = Hologram;
        disp(['Time elapsed is ',num2str(toc(tholos)),'s. Expected total time is ',...
            num2str(toc(tholos)*numSolo/j),'s.']);
    end
    disp('Now storing in matrix...')
    tmatrix = tic;
    for i = 1:numSolo
        j=solos(i);
        DE(j)=tempDE(i);
        hololist{j}=temphololist{i};
        disp(['Time elapsed is ',num2str(toc(tmatrix)),'s. Expected total time is ',...
            num2str(toc(tmatrix)*numSolo/i),'s.']);
    end
end 


%Midsize holograms
if numMid ==0
    disp('No Midsized Holos')
else 
    disp('Computing Midsized Holos')
    
    clear tempDE temphololist
    ROIs =  holoRequest.rois([mids]);
%     p =gcp('nocreate');
%     if isempty(p) || ~isprop(p,'NumWorkers') || p.NumWorkers ~=5
%         delete(p);
%         parpool(5);
%     end
    for j=1:numMid
        disp(['Now compiling hologram ' int2str(j) ' of ' int2str(numel(mids))])
        ROIselection =ROIs{j};
        myattenuation = AttenuationCoeffs(ROIselection);
        energy = 1./myattenuation; energy = energy/sum(energy);
        tempDE(j) = sum(energy.*myattenuation);
        disp(['Diffraction efficiency of the hologram : ' int2str(100*tempDE(j)) '%']);
        subcoordinates = SLMCoordinates(:,ROIselection);
        [ Hologram,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates' );
        temphololist{j} = Hologram;
    end
    for i = 1:numMid
        j=mids(i);
        DE(j)=tempDE(i);
        hololist{j}=temphololist{i};
    end
end 


%Large holograms
if numLarge ==0
    disp('No Large Holos')
else 
    disp('Computing Large Holos')
    
    clear tempDE temphololist
    ROIs =  holoRequest.rois([larges]);
%     p =gcp('nocreate');
%     if isempty(p) || ~isprop(p,'NumWorkers') || p.NumWorkers ~=2
%         delete(p);
%         parpool(2);
%     end
    for j=1:numLarge
        disp(['Now compiling hologram ' int2str(j) ' of ' int2str(numel(larges))])
        ROIselection =ROIs{j};
        myattenuation = AttenuationCoeffs(ROIselection);
        energy = 1./myattenuation; energy = energy/sum(energy);
        tempDE(j) = sum(energy.*myattenuation);
        disp(['Diffraction efficiency of the hologram : ' int2str(100*tempDE(j)) '%']);
        subcoordinates = SLMCoordinates(:,ROIselection);
        [ Hologram,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates' );
        temphololist{j} = Hologram;
    end
    for i = 1:numLarge
        j=larges(i);
        DE(j)=tempDE(i);
        hololist{j}=temphololist{i};
    end   
end

%Extra Large holograms
if numExtraLarge ==0
    disp('No Extra Large Holos')
else
    
    disp('Computing Extra Large Holos')
        
    for i=1:numExtraLarge
        j=extraLarges(i);
        disp(['Now compiling hologram ' int2str(i) ' of ' int2str(numel(extraLarges))])
        ROIselection = holoRequest.rois{j};
        myattenuation = AttenuationCoeffs(ROIselection);
        energy = 1./myattenuation; energy = energy/sum(energy);
        DE(j) = sum(energy.*myattenuation);
        disp(['Diffraction efficiency of the hologram : ' int2str(100*DE(j)) '%']);
        subcoordinates = SLMCoordinates(:,ROIselection);
        [ Hologram,Reconstruction,Masksg ] = function_Make_3D_SHOT_Holos( Setup,subcoordinates' );
        hololist{j} = Hologram;
    end
end


% userholofname = input('Enter holoList filename to save current list of holograms (e.g., holoList_blindmap_1): ','s');
% disp('Saving HoloList, this may take a while...')
% save([Setup.HoloListpath,userholofname,'.mat'],'hololist','-v7.3')

disp('Done')
toc

% for i=1:length(hololist)
%     hololist{i} = padarray(hololist{i},[(1920-Setup.Nx)/2,(1152-Setup.Ny)/2],0,'both');
% end

%% Shoot
%locations=FrankenScopeRigFile();
%save('Y:\holography\FrankenRig\HoloRequest-DAQ\HoloRequest.mat','DE_list','-append')
%totally remove sequences as a thing that exists basically
if(iscell(hololist))
    nholos = length(hololist);
else
    nholos = size(hololist,3);
end
sequences = cell(nholos,1);%frames preloaded to SLM
if(iscell(hololist))
    sequences = hololist;
else
    for i=1:nholos
        sequences{i} = hololist(:,:,i);
    end
end

flushMSocket(masterSocket)

[Setup.SLM ] = Function_Stop_SLM( Setup.SLM );
Setup.SLM.wait_For_Trigger = 1;
Setup.SLM.timeout_ms = timeout;
% Setup.SLM.external_Pulse = 1;
[ Setup.SLM ] = Function_Start_SLM( Setup.SLM );

%sendVar='B';
%mssend(masterSocket,sendVar)

while true
%     try Setup = function_stopBasCam(Setup); end
%     [Setup] = function_startBasCam(Setup);
%     function_BasPreview(Setup);
    [slmTimes,slmOutcomes] = ShootSequencesMsocket(Setup,sequences,masterSocket);

end

    
% end