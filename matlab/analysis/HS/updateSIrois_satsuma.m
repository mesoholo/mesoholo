%Import XY coordinates of targets to add to scanimage integration ROIs
function updateSIrois(hSI,realZsTargets,clearprev)
pathToSources = 'W:\Satsuma\SatsumaHoloShare\lastHoloRequest\lastholomori.mat';
xy_mori = load(pathToSources);
maxTarg = 100

if length(xy_mori.holoRequest.targets)>maxTarg
    xy_mori.holoRequest.targets=xy_mori.holoRequest.targets(1:maxTarg,:)
end
%% Create Array of Targets
radius = 5;
xy = xy_mori.holoRequest.targets(:,1:2);% fliplr();
%xy=fliplr(xy)
zs = xy_mori.holoRequest.targets(:,3);
%if isempty(realZsTargets)

    %realZsTargets = [-9,14,35,67]%sort(unique(zs));
%end

disp(realZsTargets)
%TODO make this into a function of the current planes using hSI object
OptoTuneDepthsToProbe = hSI.hStackManager.zs;
for i = 1:size(realZsTargets,2)
   zs(zs==realZsTargets(i)) =OptoTuneDepthsToProbe(i);
end
  sources = zeros(512,512,size(xy,1));
  SE=strel('disk',radius,4);
   
   for n = 1:size(sources,3);
       sources(round(xy(n,1)),round(xy(n,2)),n)=1;
       sources(:,:,n)=imdilate(sources(:,:,n),SE);
   end
   
   figure(51);imagesc(max(sources,[],3))
   
   %% send targets to ScanImage 
   if clearprev
      hSI.hIntegrationRoiManager.roiGroup.clear()
   end
   imagingScanfield = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);

   number = 0;
%    for o = 1:size(OptoTuneDepthsToProbe)
%        
   for i = 1:size(sources,3)
       mask = sources(:,:,i);
       intsf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(imagingScanfield,mask);
       intsf.threshold = 100;
       introi = scanimage.mroi.Roi();
       introi.discretePlaneMode=1;
       introi.add(double(zs(i)), intsf);
       introi.name = ['ROI ' num2str(number+1) ' Depth ' num2str(zs(i))];
       hSI.hIntegrationRoiManager.roiGroup.add(introi);
       number=number+1;
   end
   
% rois = evalin('base','hSI.hIntegrationRoiManager.roiGroup.rois');
% pixelToRefTransform = evalin('base','hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1).pixelToRefTransform');
% %selectAllROIs;
% hSI.hIntegrationRoiManager.hIntegrationRoiOutputChannels(1).hIntegrationRois = hSI.hIntegrationRoiManager.roiGroup.rois;
disp('rois updated')
end


