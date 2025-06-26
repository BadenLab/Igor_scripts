#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_ParameterTable()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==1)
	print "OS_Parameters table already exists - just opening that..."
else
	print "Generating new OS_Parameters table..."

// make a new table
make /o/n=100 OS_Parameters = NaN

// reads data-header
wave wParamsNum
wave /T wParamsStr

// Define Entries
variable entry_position = 0

//////////// from the wParamsNum wave // Andre 2016 04 14
Variable xPixelsInd,yPixelsInd,realPixDurInd,lineDur,sampRate,sampPeriod// Andre 2016 04 14 & 04 26


/// DETREND ////////////////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Detrend_Skip,OS_Parameters
OS_Parameters[%Detrend_Skip] = 1 // 1 skips the detrend
entry_position+=1

SetDimLabel 0,entry_position,Detrend_nTimeBin,OS_Parameters
OS_Parameters[%Detrend_nTimeBin] = 10 // 1 temporal binning? 1,2,3,4... - default 1
entry_position+=1

SetDimLabel 0,entry_position,Detrend_smooth_window,OS_Parameters
OS_Parameters[%Detrend_smooth_window] = 1000 // smoothing window in seconds - default 1000
entry_position+=1

SetDimLabel 0,entry_position,LightArtifact_cut,OS_Parameters
OS_Parameters[%LightArtifact_cut] = 2 // nPixels cut in X to remove LightArtifact - default 3
entry_position+=1

/// MULTIPLANE ////////////////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,nPlanes,OS_Parameters
OS_Parameters[%nPlanes] = 1 // number of scan planes to be deinterleaved
entry_position+=2

/// ROI PLACEMENT /////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,ROI_corr_min,OS_Parameters
OS_Parameters[%ROI_corr_min] = 1 // Activity correlation minimum to allow a seeded ROI to grow - default 1, which disabled ROI placement
entry_position+=1

SetDimLabel 0,entry_position,ROI_GaussSize,OS_Parameters
OS_Parameters[%ROI_GaussSize] = 3 // for Correlation Projection subtraction image - default = 3
entry_position+=1					

SetDimLabel 0,entry_position,ROI_minPx,OS_Parameters
OS_Parameters[%ROI_minPx] = 5 // for Corr/SD: min number of pixels in a ROI
entry_position+=1					

SetDimLabel 0,entry_position,ROI_maxPx,OS_Parameters
OS_Parameters[%ROI_maxPx] = 15 // for Corr/SD: max number of pixels in a ROI
entry_position+=1		

SetDimLabel 0,entry_position,ROIGap_px,OS_Parameters
OS_Parameters[%ROIGap_px] = 1 // minimum spacing between ROIs - SD Roi placement
entry_position+=1

SetDimLabel 0,entry_position,ROI_SD_min,OS_Parameters
OS_Parameters[%ROI_SD_min] = 10 // SD minimum value for SD auto ROI - default 10
entry_position+=1

SetDimLabel 0,entry_position,useMask4Corr,OS_Parameters
OS_Parameters[%useMask4Corr] = 0 // for correlation analysis, does it use a SARFIA Mask (e.g. from Cell Lab) to place ROIs
entry_position+=2

SetDimLabel 0,entry_position,ROI_PxBinning,OS_Parameters
OS_Parameters[%ROI_PxBinning] = 1 // Bin pixels to autoplace ROIs (speedup = 2^Bin)  - default 1
entry_position+=1

SetDimLabel 0,entry_position,IncludeDiagonals,OS_Parameters
OS_Parameters[%IncludeDiagonals] = 1 // Use diagnoal pixels to compute correlation projection? - default 0
entry_position+=1

SetDimLabel 0,entry_position,TimeCompress,OS_Parameters
OS_Parameters[%TimeCompress] = 1 // Time-compress traces by factor X when computing correlation - default 10 (original time)
entry_position+=2

/// TRACE AND TRIGGER EXTRACTION  ///////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Skip_First_Triggers,OS_Parameters 
OS_Parameters[%Skip_First_Triggers] = 0  // skips last trigger, e.g. when last loop is not complete - default 0
entry_position+=1

SetDimLabel 0,entry_position,Skip_Last_Triggers,OS_Parameters // KF 20160310
OS_Parameters[%Skip_Last_Triggers] = 0  // skips last trigger, e.g. when last loop is not complete - default 0
entry_position+=1

SetDimLabel 0,entry_position,Baseline_nSeconds,OS_Parameters
OS_Parameters[%Baseline_nSeconds] = 5  // takes the 1st n seconds to calculate the baseline noise (for z-normalisation) - default 5
entry_position+=1

SetDimLabel 0,entry_position,Ignore1stXseconds,OS_Parameters
OS_Parameters[%Ignore1stXseconds] = 1 // for baseline extraction & for averaging across triggers (below): ignores X 1st seconds of triggers
entry_position+=1

SetDimLabel 0,entry_position,IgnoreLastXseconds,OS_Parameters
OS_Parameters[%IgnoreLastXseconds] = 0 // if weird stuff happens at end of trace can cut away
entry_position+=2

/// BASIC AVERAGING  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Trigger_Mode,OS_Parameters
OS_Parameters[%Trigger_Mode] = 1 // Use every nth trigger - default 1
entry_position+=1

SetDimLabel 0,entry_position,Stim_Marker,OS_Parameters
OS_Parameters[%Stim_Marker] = 0 // Plot regular stimulus marker in a loop?
entry_position+=1

SetDimLabel 0,entry_position,nLines_lumped,OS_Parameters
OS_Parameters[%nLines_lumped] = 1 // For Averaging and beyond, how many lines are combined (to speed up)?
entry_position+=2


/// Average STACK  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,AvgStack_make,OS_Parameters
OS_Parameters[%AvgStack_make] = 0 // yes or no /0/1; 2 = min sub, 3 = avg sub, 4 = median sub
entry_position+=1

SetDimLabel 0,entry_position,AvgStack_SkipTrig,OS_Parameters
OS_Parameters[%AvgStack_SkipTrig] = 1 // Every how many triggers should this chop
entry_position+=1

SetDimLabel 0,entry_position,AvgStack_firstplane,OS_Parameters
OS_Parameters[%AvgStack_firstplane] = 1 // only if multiplane, which plane is the first in z, default 1
entry_position+=1

SetDimLabel 0,entry_position,PlotOnlyMeans,OS_Parameters
OS_Parameters[%PlotOnlyMeans] = 20 // plot only the means above this number of ROIs
entry_position+=1

SetDimLabel 0,entry_position,PlotOnlyHeatMap,OS_Parameters
OS_Parameters[%PlotOnlyHeatMap] = 50 // PlotOnlyHeatMap above this number of ROIs
entry_position+=2



/// QC Projections  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,QCProjection_make,OS_Parameters
OS_Parameters[%QCProjection_make] = 0 // Compute QC projection or not - default 1 (yes)
entry_position+=1

SetDimLabel 0,entry_position,QCProj_TriggersPerStim,OS_Parameters
OS_Parameters[%QCProj_TriggersPerStim] = 1 // Get QC proj per n Triggers - default 1
entry_position+=1

SetDimLabel 0,entry_position,QCProjection_binning,OS_Parameters
OS_Parameters[%QCProjection_binning] = 1 // Binning parameter for QC projection. Default 1
entry_position+=2


/// QuickCluster  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Clustering_nClasses,OS_Parameters
OS_Parameters[%Clustering_nClasses] = 10 // how many Classes seeded into Clustering (kMeans)
entry_position+=1

SetDimLabel 0,entry_position,Clustering_SDplot,OS_Parameters
OS_Parameters[%Clustering_SDplot] = 5 // nSDs plotted in Clustering display
entry_position+=1


/// EVENT TRIGGERING  ////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Events_nMax,OS_Parameters
OS_Parameters[%Events_nMax] = 1000 // maximal number of events identified in single full trace - default 1000
entry_position+=1

SetDimLabel 0,entry_position,Events_Threshold,OS_Parameters
OS_Parameters[%Events_Threshold] = 1 // Threshold for Peak detection (log scale), default = 1
entry_position+=1

SetDimLabel 0,entry_position,Events_RateBins_s,OS_Parameters
OS_Parameters[%Events_RateBins_s] = 0.05 // "Smooth_size" for Event rate plots (s) - default 0.05
entry_position+=2



/// RF Calculations  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Noise_EventSD,OS_Parameters
OS_Parameters[%Noise_EventSD] = 0.7 // Sensitivity of Event triggering
entry_position+=1

SetDimLabel 0,entry_position,Noise_PxSize_degree,OS_Parameters
OS_Parameters[%Noise_PxSize_degree] = 3 // pixel size of 3D noise - default 3 degrees
entry_position+=1

SetDimLabel 0,entry_position,Noise_interval_sec,OS_Parameters
OS_Parameters[%Noise_interval_sec] = 0.078 // Refresh rate of the Noise (in seconds)
entry_position+=1

SetDimLabel 0,entry_position,Noise_FilterLength_s,OS_Parameters
OS_Parameters[%Noise_FilterLength_s] = 2 // Length extracted in seconds
entry_position+=1

SetDimLabel 0,entry_position,Kernel_SDplot,OS_Parameters
OS_Parameters[%Kernel_SDplot] = 30 // nSDs plotted in kernel function
entry_position+=1

SetDimLabel 0,entry_position,Noise_Compression,OS_Parameters
OS_Parameters[%Noise_Compression] = 10 // Noise RF calculation speed up
entry_position+=1

SetDimLabel 0,entry_position,nColourChannels,OS_Parameters
OS_Parameters[%nColourChannels] = 4 // for STRFs and Kernels
entry_position+=2


/// GENERAL ////////////////////////////////////////////////////////////////////////////////////////////////

if (waveexists($"wParamsNum")==1) // 2P Data taken with ScanM, get timing info from there
	setdimlabel 0,entry_position,LineDuration,OS_Parameters
	xPixelsInd = FindDimLabel(wParamsNum,0,"User_dxPix" )// Andre 2016 04 14
	yPixelsInd = FindDimLabel(wParamsNum,0,"User_dyPix" )// Andre 2016 04 14
	realPixDurInd = FindDimLabel(wParamsNum,0,"RealPixDur" )// Andre 2016 04 14
	lineDur = (wParamsNum[xPixelsInd] *  wParamsNum[realPixDurInd]) * 10^-6// Andre 2016 04 14
	OS_Parameters[%LineDuration] = lineDur
	entry_position+=1
else
	setdimlabel 0,entry_position,LineDuration,OS_Parameters
	OS_Parameters[%LineDuration] = 0.001 // placehol;der to be overwritten
	entry_position+=1
endif


SetDimLabel 0,entry_position,Data_Channel,OS_Parameters
OS_Parameters[%Data_Channel] = 0 // Fluorescence Data in wDataChX - default 0
entry_position+=1

SetDimLabel 0,entry_position,Data_Channel2,OS_Parameters
OS_Parameters[%Data_Channel2] = 1 // Fluorescence Data in wDataChX - default 1 (for Ratiometric)
entry_position+=1

SetDimLabel 0,entry_position,Trigger_Channel,OS_Parameters
OS_Parameters[%Trigger_Channel] = 2 // Trigger Data in wDataChX - default 2 
entry_position+=1

SetDimLabel 0,entry_position,Display_Stuff,OS_Parameters
OS_Parameters[%Display_Stuff] = 1 // generate graphs? - 0/1 - default 1
entry_position+=2

// Additional crap

SetDimLabel 0,entry_position,Detrend_RatiometricData,OS_Parameters
OS_Parameters[%Detrend_RatiometricData] = 0 // Does Ratiometric data get detrended (1) or just combined (0)? - default 0
entry_position+=1

SetDimLabel 0,entry_position,Use_Znorm,OS_Parameters
OS_Parameters[%Use_Znorm] = 1 // use znormalised or raw traces (0/1) - default 1
entry_position+=1

SetDimLabel 0,entry_position,Trigger_Threshold,OS_Parameters
OS_Parameters[%Trigger_Threshold] = 20000 // Threshold to Trigger in Triggerchannel - default 20000
entry_position+=1

SetDimLabel 0,entry_position,Trigger_after_skip_s,OS_Parameters
OS_Parameters[%Trigger_after_skip_s] = 0.1 // if triggers in triggerchannel, it skips X seconds - default 0.1
entry_position+=1

SetDimLabel 0,entry_position,Trigger_DisplayHeight,OS_Parameters
OS_Parameters[%Trigger_DisplayHeight] = 6  // How long are the trigger lines in the display (in SD) - default 6
entry_position+=1

SetDimLabel 0,entry_position,Trigger_LevelRead_after_lines,OS_Parameters
OS_Parameters[%Trigger_levelread_after_lines] = 2  // to read "Triggervalue" - want to avoid landing on the slope of the trigger - default 2
entry_position+=2

/// REGISTERING /////////////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,registration_averageN,OS_Parameters
OS_Parameters[%Registration_AverageN] = 10 // Downsampling to speed up
entry_position+=1

SetDimLabel 0,entry_position,Registration_skipN,OS_Parameters
OS_Parameters[%Registration_SkipN] = 10 // register using every n images
entry_position+=2

/// redimension the OS_parameter table, so it doesn't have trailing NaN's
redimension /N=(entry_position) OS_Parameters

endif
		
// Display the Table
edit /k=1 /W=(50,50,300,700)OS_Parameters.l, OS_Parameters

end

//////////////////////////

function OS_ParameterTable_kill()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==1)
	wave OS_parameters
	killwaves OS_parameters	
	print "OS_Parameters deleted"
else
	print "OS_Parameters was already deleted"
endif
end
