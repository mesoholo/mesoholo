% http://scanimage.vidriotechnologies.com/display/SI2019/IntegrationField+API
%% Definition of an IntegrationField
hSf = scanimage.mroi.scanfield.fields.IntegrationField();  % create an Integration Scanfield
hSf.channel = 1;                                    % assign IntegrationField to channel 1
hSf.centerXY = [0.5,0.5];                           % set center [x,y] of IntegrationField to center of Reference space
hSf.sizeXY = [0.25,0.25];                           % set size [x,y] of IntegrationField in Reference space
hSf.rotationDegrees = 0;                            % set rotation of IntegrationField in Reference space
hSf.mask = rand(10);                                % set a mask with weights for underlying pixels
 
hRoi = scanimage.mroi.Roi();   % create empty Roi
z = 0;
hRoi.add(z,hSf);               % add IntegrationField at z = 0
 
hSI.hIntegrationRoiManager.roiGroup.add(hRoi);  % add IntegrationRoi to IntegrationRoiManager

% creates a large ROI in the "ROI Group Editor" window, centered at (0,0)
% spans X: -2760 to 2760, Y: -3000 to 3000
% no error message!

%% Create IntegrationField by masking entire Imaging Scanfield
hSf_imaging = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);    % get the current imaging Scanfield
z = hSI.hRoiManager.currentRoiGroup.rois(1).zs(1);                      % get z of the current imaging Scanfield
resXY = hSf_imaging.pixelResolution;                                    % get pixel resolution of current imaging Scanfield
mask = zeros(resXY(2),resXY(1));                 % create a mask for the scanfield that has the same pixel resolution as the imaging scanfield
mask(1:10,1:10) = 1;                             % set upper left corner to 1
  
hSf = scanimage.mroi.scanfield.fields.IntegrationField.createFromMask(hSf_imaging,mask);    % create IntegrationField from imaging scanfield and mask
hSf.channel = 1;  % assign IntegrationField to channel 1
  
hRoi = scanimage.mroi.Roi();                    % create empty Roi
hRoi.add(z,hSf);                                % add IntegrationField to Roi
hSI.hIntegrationRoiManager.roiGroup.add(hRoi);  % add IntegrationRoi to IntegrationRoiManager

% this adds an ROI at the top left of 3X3 Area.roi, size 20um in Y (height) and 10um in X (width)
% but also generates following error message on Command Window:

% No appropriate method, property, or field 'channel' for class 'scanimage.mroi.scanfield.fields.RotatedRectangle'.
% 
% Error in scanimage.guis.RoiGroupEditor/updateTable (line 2074)
%                                 obj.tblData{idx,4} = sf.channel;
% 
% Error in scanimage.guis.RoiGroupEditor/rgChangedPar (line 3032)
%             obj.updateTable();
% 
% Error in scanimage.guis.RoiGroupEditor/rgChanged (line 3014)
%             obj.rgChangedPar();
% 
% Error in scanimage.guis.RoiGroupEditor>@(varargin)obj.rgChanged(varargin{:}) (line 608)
%             obj.hRGListener = most.util.DelayedEventListener(0.5,obj.editingGroup,'changed',@obj.rgChanged);
% 
% Error in most.util.DelayedEventListener/ (line 85)
%             obj.functionHandle(varargin{:});
% 
% Error in most.util.DelayedEventListener/timerCallback (line 76)
%                         obj.executeFunctionHandle(obj.hListener.Source,eL);
% 
% Error in most.util.DelayedEventListener>@(varargin)obj.timerCallback(varargin{:}) (line 20)
%                 'StopFcn',@obj.timerCallback,...
% 
% Error in timer/timercb (line 30)
%     		feval(val{1}, obj, eventStruct, val{2:end});
% 
% Error in timercb (line 13)
% timercb(t, varargin{2:end});

%% Create IntegrationField by masking individual pixels of Imaging Scanfield
hSf_imaging = hSI.hRoiManager.currentRoiGroup.rois(1).scanfields(1);    % get the current imaging Scanfield
z = hSI.hRoiManager.currentRoiGroup.rois(1).zs(1);                      % get z of the current imaging Scanfield
 
% define mask by assigning a weight to individual pixels in the imaging scanfield
mask = [1,1, 1; ...
        1,2, 1; ...
        2,1, 1; ...
        2,2, 1];
hSf = createFromMask(hSf_imaging,mask); % create IntegrationField from imaging scanfield and mask
hSf.channel = 1;                        % assign IntegrationField to channel 1
  
Roi = scanimage.mroi.Roi();                     % create empty Roi
hRoi.add(z,hSf);                                % add IntegrationField to Roi
hSI.hIntegrationRoiManager.roiGroup.add(hRoi);  % add IntegrationRoi to IntegrationRoiManager

% generates following error message on Command Window:
% Undefined function or variable 'createFromMask'.