% written by Hyeyoung Shin 2/3/2022
% takes in coordinates from the output of mesotifread function, then adds
% integration ROIs to the ScanImage "ROI Group Editor" window
% note, click "Edit Integration Fields" in the "INTEGRATION CONTROLS"
% window after executing this code to see the ROIs.
% Ly =        1484;
% Lxs =
%    608
%    608
%    608
%    608
%    608

function addmesoSIrois(targetcoords, hSI) %, Ly, Lxs)
   
clearprev = false;
if clearprev
    hSI.hIntegrationRoiManager.roiGroup.clear()
end

if numel(size(targetcoords)) ~=2
    error('expectged input to have two columns')
end
Nplanes = numel(hSI.hRoiManager.currentRoiGroup.rois);
% if length(Lxs) ~= Nplanes
%     error('number of elements in onLxs and Nplanes should match')
% end

Lxs = zeros(Nplanes,1);
Lys = zeros(Nplanes,1);
for iplane = 1:Nplanes
imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(iplane).scanfields(1);
Lys(iplane) = imagingScanfield.pixelResolutionXY(2);
Lxs(iplane) = imagingScanfield.pixelResolutionXY(1);
end
Ly = unique( double(Lys) );
if numel(Ly) ~= 1
    error('error determining Ly in hSI')
end

xshifts = [0; cumsum(Lxs(1:end-1))];

targetmroi = zeros(size(targetcoords,1),3);
targetmroi(:,1) = targetcoords(:,1);
targetmroi(:,3) = sum(targetcoords(:,2) - xshifts'>0,2);
targetmroi(:,2) = targetcoords(:,2)-xshifts(targetmroi(:,3));

if size(targetmroi,1)>100
    error('are you sure you want that many integration rois?')
end


% send targets to ScanImage
tic
% xy: first column determines vertical position from top, second column
% determines horizontal position from left
% xy = [1000 500];

radius = 7;
Nplanes = numel(hSI.hRoiManager.currentRoiGroup.rois);
for iplane = 1:Nplanes
    xy = targetmroi(:,1:2);
    xy = xy(targetmroi(:,3)==iplane, :);

    imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(iplane).scanfields(1);
    Nmaskrows = imagingScanfield.pixelResolutionXY(2);
    Nmaskcols = imagingScanfield.pixelResolutionXY(1);

%     disp(['Plane ', num2str(iplane)])
%     disp('tif Ly Lx')
%     disp([Ly Lxs(iplane)])
%     disp('hRoiManager pixelResolutionXY')
%     disp(imagingScanfield.pixelResolutionXY([2, 1]))

    % size(volmeso)         420        7180         126
    % imagingScanfield.pixelResolutionXY 607        1483
    % in the mesoscope, the imagingScanfield.pixelResolutionXY does not
    % correspond to number of pixels (not sure what happens in other rigs?)
    % % the following strategy failed
    % % Nmaskcols = onLxs(iplane); % this is the number of pixels
    % % Nmaskrows = onLy;
    
%     xy(:,1) = xy(:,1)*imagingScanfield.pixelResolutionXY(2)/Ly;
%     xy(:,2) = xy(:,2)*imagingScanfield.pixelResolutionXY(1)/Lxs(iplane);

    sources = zeros(Nmaskrows,Nmaskcols,size(xy,1));
    SE=strel('disk',radius,4);

    for n = 1:size(sources,3);
        sources(round(xy(n,1)),round(xy(n,2)),n)=1;
        sources(:,:,n)=imdilate(sources(:,:,n),SE);
    end
    
    if size(xy,1)>0
        figure(51);imshow(squeeze(max(sources,[],3)))
    end
    
    % hSI.hRoiManager.currentRoiGroup
    %   RoiGroup with properties:
    %            rois: [1×5 scanimage.mroi.Roi]
    %      activeRois: [1×5 scanimage.mroi.Roi]
    %     displayRois: [1×5 scanimage.mroi.Roi]
    %              zs: 40
    %            name: 'MROI Imaging ROI Group'
    number = 0;
    %    for o = 1:size(OptoTuneDepthsToProbe)
    %
    for i = 1:size(sources,3)
        mask = sources(:,:,i);
        intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
        intsf.threshold = 100;
        introi = scanimage.mroi.Roi();
        introi.discretePlaneMode=1;
        %     introi.add(double(zs(i)), intsf);
        introi.add(0, intsf); % add ROI at depth 0
        introi.name = ['ROI ' num2str(number+1) ' Plane ' num2str(iplane)];
        hSI.hIntegrationRoiManager.roiGroup.add(introi);
        number=number+1;
    end

    % rois = evalin('base','hSI.hIntegrationRoiManager.roiGroup.rois');
    % pixelToRefTransform = evalin('base','hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1).pixelToRefTransform');
    % %selectAllROIs;
    % hSI.hIntegrationRoiManager.hIntegrationRoiOutputChannels(1).hIntegrationRois = hSI.hIntegrationRoiManager.roiGroup.rois;
end
toc
disp('rois updated')

% end