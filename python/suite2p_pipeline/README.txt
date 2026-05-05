crop the FOV down to the ActualHoloFOV in jupyter notebook, then run suite2p
1. open Anaconda Powershell Prompt and enter the following commands:
		conda activate CLbehavior
		cd C:\Users\MesoDAQ\Documents\GitHub\Meso_HScode\SI\suite2p_pipeline
		jupyter notebook
2. in Matlab R2021b, run C:\Users\MesoDAQ\Documents\GitHub\Meso_HScode\SI\suite2p_pipeline\mesoscope_json_from_scanimage_210617_59.m
3. in jupyter notebook, run mesocroph5_justgreen.ipynb  (took <15min total for HS_Ai203_2\220531\ : ~2min for conversion to h5,~12min for suite2p)
	- for full FOV, run mesofullh5parallels2p.ipynb (took 41min total for HS_Ai203_2\220531\ : ~3min for conversion to h5,~38min for suite2p))
	- to run both channels in cropped FOV, run mesocroph5s2p_allch.ipynb (haven't tested this code, might run into out-of-memory error depending on the recording length)

HOW TO FIND COORDINATES CORRESPONDING TO ActualHoloFOV  BOUNDARIES IN YOUR CURRENT MROI SETTING
% run the following in the MATLAB instance running Scanimage
% find out ActualHoloFOV boundaries using C:\Users\MesoDAQ\Documents\MATLAB\MesoSICode\HScode\suite2p_pipeline\convertcoords_HoloFOVtoCurrentFOV.m
% the arguments for convertcoords_HoloFOVtoCurrentFOV should already be in the workspace if C:\Users\MesoDAQ\Documents\MATLAB\MesoSICode\makeMasks3D_holeburn.m was run that day
% xynew(:,1) is the horizontal axis, xynew(:,2) is the vertical axis
% set xlb, xub (horizontal axis) and ylb, yub (vertical axis) accordingly in mesocroph5.ipynb 
xyorig = [50 50; fullnpix_orig(1)-50 fullnpix_orig(2)-50];
xynew = convertcoords_HoloFOVtoCurrentFOV(hSI,xyorig, fullnpix_orig, fullxsize_orig, fullysize_orig, fullxcenter_orig, fullycenter_orig)

HOW TO INSTALL CLbehavior ENVIRONMENT
open Anaconda Powershell Prompt and enter the following commands:
	cd C:\Users\MesoDAQ\Documents\GitHub\MesoSI_HScode\CLbehavior
	conda env create -f environment.yml
