#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Official ScanM Data Preprocessing Scripts - by Tom Baden    	///
/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Requires "ROIs", detrended data stack + trigger stack		///
///	Input Arguments - data Ch (0,1,2...?), Trigger Ch (0,1,2)     	///
///	e.g. "OS_TracesAndTriggers(0,2)"							///
///   --> reads wDataChX_detrended,wDataChY					///
///   --> generates 4 output waves								///
///   - TracesX: (per ROI, raw traces, by frames)					///
///   - TracesX_znorm: (per ROI, z-normalised traces, by frames)	///
///	- TracetimesX: for each frame (per ROI, 2 ms precision)		///
///   - Triggertimes: Timestamps of Triggers (2 ms precision)		///
///   - Triggervalue: Level of each Trigger  event					///
/////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_STRFs_new()


	variable nColours = 4
	variable nTriggers_per_Colour = 100
	
	variable RGB_Attenuation = 20 // the larger, the more attenuated the RGB RFs will come out

//////// NEW VARIABLEWS NOT IMPLEMENTED FULLY YET

	variable CropNoiseEdges = 2 //20 for 25um(=1.18deg) // HACK FOR NOW
	variable preSDProjectSmooth = 0
	
	variable adjust_by_pols = 1
	
	variable nF_Max_per_Noiseframe = 8 // how many frames between triigers is allowed as a noise frame - hardcode




// 0 //  check if NoiseArray3D is there
if (waveexists($"NoiseArray3D")==0)
	print "Warning: NoiseArray3D wave missing - please import! Procedure aborted."
	abort
endif

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
// 2 //  check for Detrended Data stack
variable Channel = OS_Parameters[%Data_Channel]
if (waveexists($"wDataCh"+Num2Str(Channel)+"_detrended")==0)
	print "Warning: wDataCh"+Num2Str(Channel)+"_detrended wave not yet generated - doing that now..."
	OS_DetrendStack()
endif
// 3 //  check for ROI_Mask
if (waveexists($"ROIs")==0)
	print "Warning: ROIs wave not yet generated - doing that now (using correlation algorithm)..."
	OS_AutoRoiByCorr()
	DoUpdate
endif
// 4 //  check if Traces and Triggers are there
if (waveexists($"Triggertimes")==0)
	print "Warning: Traces and Trigger waves not yet generated - doing that now..."
	OS_TracesAndTriggers()
	DoUpdate
endif

// 5 //  check if NoiseArray3D is there
	


// flags from "OS_Parameters"
variable Display_Stuff = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration]
variable Noise_PxSize = OS_Parameters[%Noise_PxSize_degree]
variable Event_SD = OS_Parameters[%Noise_EventSD]
variable FilterLength = OS_Parameters[%Noise_FilterLength_s]
variable Hz = OS_Parameters[%samp_rate_Hz]
variable Skip_First_Trig = OS_Parameters[%Skip_First_Triggers]
variable Skip_Last_Trig = OS_Parameters[%Skip_Last_Triggers]

// data handling
wave ROIs

variable xx,yy,ff,rr,tt,ii,ll

wave Triggertimes_frame // loading by frame, not by time!
variable nTriggers = 0
for (tt=0;tt<Dimsize(triggertimes_frame,0);tt+=1)
	if (Numtype(triggertimes_frame[tt])==0)
		nTriggers+=1
	else
		break
	endif	
endfor
print nTriggers, "Triggers found"



// Identify first and last trigger and select accordingly
//# First trigger
variable firsttrigger_f // first trigger frame
if (Skip_First_Trig != 0)
	firsttrigger_f = triggertimes_frame[Skip_First_Trig]
	print "WARNING: Currenlty Skip_First_Triggers WILL give you weird results... Only use Skip_Last_Triggers"
else 
	firsttrigger_f = triggertimes_frame[0] - 1
endif
//# Last trigger
variable lasttrigger_f // last trigger frame 
if (Skip_Last_Trig != 0)
	lasttrigger_f = triggertimes_frame[nTriggers-Skip_Last_Trig]
else
	lasttrigger_f = triggertimes_frame[nTriggers-1]
endif
//# Print some stuff for sanity's sake
if (Skip_Last_Trig != 0 || Skip_First_Trig != 0)
	print "Trigger adjustment in OS Parameters detected:"
	print "First trigger specified", Skip_First_Trig 
	print "Last trigger:", Skip_Last_Trig 
	print "First trigger frame:", firsttrigger_f 
	print "Last trigger frame:", lasttrigger_f 
	print "Triggers after excluding first/last:", nTriggers - Skip_First_Trig - Skip_Last_Trig
endif
// Duplicate temporal data waves to not change the originals 
string tracetimes_name = "Tracetimes"+Num2Str(Channel)
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
string traces_name = "Traces"+Num2Str(Channel)+"_raw"
if (use_znorm==1)
	traces_name = "Traces"+Num2Str(Channel)+"_znorm"
endif
duplicate /o $input_name InputStack
duplicate /o $traces_name InputTraces
duplicate /o $tracetimes_name InputTraceTimes
// Get rid of trace data where we have asked OS Params to ignore n first triggers
//DeletePoints /m=2 0,firsttrigger_f, InputStack
//DeletePoints 0,firsttrigger_f, InputTraces
//DeletePoints 0,firsttrigger_f, InputTraceTimes

// Crop NoiseArray3D and Triggertimes_Frame accordingly (but only if OS Params set accordingly, otherwise no point)
//if (Skip_Last_Trig != 0 || Skip_First_Trig != 0) // belive it or not but this is an OR statement! 
//	Duplicate/O/R=[firsttrigger_f, nTriggers - lasttrigger_f] Triggertimes_frame test_wav
//endif 

// Before determining nF, Make 'OS_Parameters' IgnoreLastXseconds have an effect 
/// Initial nF
variable nF = DimSize(InputTraces,0)


variable nRois = DimSize(InputTraces,1)
variable nY = DimSize(InputStack,1)

variable Frameduration = nY * LineDuration 
variable nF_Filter = floor(FilterLength / Frameduration) // new strategy - make the noise array match framerate

wave NoiseArray3D
variable nX_Noise = Dimsize(NoiseArray3D,1) // X and Y flipped relative to mouse
variable nY_Noise = Dimsize(NoiseArray3D,0)
variable nZ_Noise = Dimsize(NoiseArray3D,2)

string output_name_SD = "STRF_SD"+Num2Str(Channel) // 3D wave (x/y/Roi)
string output_name_Corr = "STRF_Corr"+Num2Str(Channel) // 3D wave (x/y/Roi)
string output_name_individual = "STRF"+Num2Str(Channel)+"_" 

make /o/n=(nX_Noise,nY_Noise*nColours,nRois) Filter_SDs = 0
make /o/n=(nX_Noise,nY_Noise*nColours,nRois) Filter_Pols = 1 // force to 1 (On)
make /o/n=(nX_Noise,nY_Noise*nColours,nROIs) Filter_Corrs = 0

// make Stim Array
printf "Adjusting NoiseArray to Framerate..."
make /B/o/n=(nX_Noise-CropNoiseEdges*2,nY_Noise-CropNoiseEdges*2,nF) NoiseStimulus_Frameprecision = 0.5 // or should this be 0?

variable nLoops = ceil(nTriggers / nZ_Noise)
print nLoops, "Loops detected"

variable TriggerCounter = 0
for (tt=Skip_First_trig; tt < nTriggers-1 - Skip_Last_trig - Skip_First_trig; tt+=1) // Can hijack this and change tt conditionally
	
	variable currentstartframe = triggertimes_frame[tt]
	variable currentendframe = triggertimes_frame[tt+1]
	
	if (currentendframe-currentstartframe>nF_Max_per_Noiseframe) // this stops is pointlessly filling gaps in the array if trigger gaps are big, eg between loops
		currentendframe = currentstartframe+nF_Max_per_Noiseframe
	endif
	Multithread NoiseStimulus_Frameprecision[][][currentstartframe,currentendframe]=NoiseArray3D[q+CropNoiseEdges][p+CropNoiseEdges][Triggercounter] // // X and Y flipped relative to mouse, i.e. here p and q flipped
	
	Triggercounter+=1
	if (TriggerCounter>nZ_Noise-1)
		Triggercounter = 0
	endif
endfor	

print "done."	

// generate a frameprecision lookup of each colour
variable nColourLoops = ceil(nTriggers / (nColours*nTriggers_per_Colour))
make /o/n=(nF) ColourLookup = NaN
variable colour
for (ll=0;ll<nColourLoops;ll+=1)
	for (colour=0;colour<nColours;colour+=1)
		currentstartframe = triggertimes_frame[ll*(nColours*nTriggers_per_Colour)+colour*nTriggers_per_Colour]
		currentendframe = triggertimes_frame[ll*(nColours*nTriggers_per_Colour)+(colour+1)*nTriggers_per_Colour-1]
		ColourLookup[currentstartframe,currentendframe]=colour
	endfor
endfor

// Get Filters
printf "Calculating kernels for "
printf Num2Str(nRois)
print " ROIs... "
make /o/n=(1) W_Statslinearcorrelationtest

/////////////////////////////////

variable nF_relevant = triggertimes_frame[nTriggers-1]-triggertimes_frame[0] 
make /o/n=(nX_Noise,nY_Noise*nColours,nF_Filter*nROIs) STRFs_concatenated = NaN

make /o/n=(nF_relevant) CurrentPx = NAN
make /o/n=(nROIs) eventcounter = 0

make /o/n=(nX_Noise, nY_Noise, nColours) MeanStim = NaN

for (rr=-1;rr<nRois;rr+=1) // goes through all ROIs
	
	if (rr==-1) // rr == -1 is the reference filter computed as random
		eventcounter = 1000 // meaningless
	else
	// have a fun little count of "events"
		make /o/n=(nF_relevant) CurrentTrace = InputTraces[triggertimes_frame[0]+p][rr] 
		Differentiate  CurrentTrace/D=CurrentTrace_DIF
		make /o/n=(100) CurrentTrace_DIFBase = CurrentTrace_DIF[p]
		WaveStats/Q CurrentTrace_DIFBase
		CurrentTrace_DIF-=V_Avg
		CurrentTrace_DIF/=V_SDev	
		for (ff=0;ff<nF_relevant;ff+=1)
			if (CurrentTrace_DIF[ff]>Event_SD)
				eventcounter[rr]+=1
			endif
		endfor
	endif
	
	
	//print eventcounter[rr], "events detected in ROI", rr
	//

	printf "ROI#"+Num2Str(rr)+"/"+Num2Str(nROIs)+": Colours..."
	make /o/n=(nF_relevant) CurrentLookup = ColourLookup[triggertimes_frame[0]+p]
	
	for (colour=0;colour<nColours;colour+=1)
		if (rr==-1)
			make /o/	n=(nF_relevant) CurrentTrace = 1
			Multithread CurrentTrace[] = (CurrentLookup[p]==colour)?(CurrentTrace[p]):(0)
		else
			make /o/	n=(nF_relevant) CurrentTrace = InputTraces[triggertimes_frame[0]+p][rr] 
			Multithread CurrentTrace[] = (CurrentLookup[p]==colour)?(CurrentTrace[p]):(0)
		endif
		
		make /o/n=(nX_Noise, nY_Noise, nF_Filter) CurrentFilter = 0
		setscale/p z,-FilterLength,0,"s" CurrentFilter
		printf Num2Str(colour)
		doupdate
		// 
		
		if (rr==-1) // compute meanimage
			for (xx=CropNoiseEdges;xx<nX_Noise-CropNoiseEdges;xx+=1)
				for (yy=CropNoiseEdges;yy<nY_Noise-CropNoiseEdges;yy+=1)
					make /o/n=(nF_relevant) CurrentPX = NoiseStimulus_Frameprecision[xx-CropNoiseEdges][yy-CropNoiseEdges][triggertimes_frame[0]+p] * CurrentTrace[p]
					Wavestats/Q CurrentPX
					MeanStim[xx][yy][colour]=V_Avg
				endfor
			endfor
		else	 // compute filter
			for (xx=CropNoiseEdges;xx<nX_Noise-CropNoiseEdges;xx+=1)
				for (yy=CropNoiseEdges;yy<nY_Noise-CropNoiseEdges;yy+=1)
					make /o/n=(nF_relevant) CurrentPX = NoiseStimulus_Frameprecision[xx-CropNoiseEdges][yy-CropNoiseEdges][triggertimes_frame[0]+p]
					Correlate/NODC CurrentTrace, CurrentPX
					Multithread CurrentFilter[xx][yy][]=CurrentPX[r+nF_relevant-nF_Filter]
				endfor
			endfor
			CurrentFilter[][][]/=MeanStim[p][q][colour]
			CurrentFilter[][][]=(NumType(CurrentFilter[p][q][r])==2)?(0):(CurrentFilter[p][q][r]) // kill NANs
			STRFs_concatenated[][nY_Noise*colour,nY_Noise*(colour+1)-1][nF_Filter*rr,nF_Filter*(rr+1)-1]=Currentfilter[p][q-nY_Noise*colour][r-nF_Filter*rr]
			// calculate each filter's correlation map 
			for (xx=CropNoiseEdges;xx<nX_Noise-CropNoiseEdges;xx+=1)
				for (yy=CropNoiseEdges;yy<nY_Noise-CropNoiseEdges;yy+=1)
					make /o/n=(nF_Filter) centerpixel = CurrentFilter[xx][yy][p]
					make /o/n=(nF_Filter) px1 = CurrentFilter[xx][yy-1][p]			
					make /o/n=(nF_Filter) px2 = CurrentFilter[xx][yy+1][p]			
					make /o/n=(nF_Filter) px3 = CurrentFilter[xx-1][yy][p]									
					make /o/n=(nF_Filter) px4 = CurrentFilter[xx+1][yy][p]	
					make /o/n=(nF_Filter) px5 = CurrentFilter[xx-1][yy-1][p]			
					make /o/n=(nF_Filter) px6 = CurrentFilter[xx+1][yy-1][p]			
					make /o/n=(nF_Filter) px7 = CurrentFilter[xx-1][yy+1][p]									
					make /o/n=(nF_Filter) px8 = CurrentFilter[xx+1][yy+1][p]					
					Correlate/NODC centerpixel, px1
					Correlate/NODC centerpixel, px2
					Correlate/NODC centerpixel, px3
					Correlate/NODC centerpixel, px4
					Correlate/NODC centerpixel, px5
					Correlate/NODC centerpixel, px6
					Correlate/NODC centerpixel, px7
					Correlate/NODC centerpixel, px8
					make /o/n=(nF_Filter*2-1) MeanNeighbourPixelCorr = (abs(px1[p])+abs(px2[p])+abs(px3[p])+abs(px4[p])+abs(px5[p])+abs(px6[p])+abs(px7[p])+abs(px8[p]))/8
					Wavestats/Q MeanNeighbourPixelCorr
					Filter_Corrs[xx][yy+colour*nY_Noise][rr]=V_Max
				endfor
			endfor		
	
			// calculating SD projections
				// smooth
			duplicate /o CurrentFilter CurrentFilter_Smth
			if (preSDProjectSmooth>0)
				Smooth /Dim=0 preSDProjectSmooth, CurrentFilter_Smth
				Smooth /Dim=1 preSDProjectSmooth, CurrentFilter_Smth
			endif
				// z-normalise based on 1st frame
			make /o/n=(nX_Noise,nY_Noise) tempwave = CurrentFilter_Smth[p][q][0]
			ImageStats/Q tempwave
			CurrentFilter_Smth[][][]-=V_Avg
			CurrentFilter_Smth[][][]/=V_SDev
				// compute SD as well as polarity mask
			for (xx=0;xx<nX_Noise;xx+=1)
				for (yy=0;yy<nY_Noise;yy+=1)
					make /o/n=(nF_Filter) CurrentTrace = CurrentFilter_Smth[xx][yy][p]
					wavestats/Q CurrentTrace 
					If (V_maxloc<V_minloc) // default is On, so here force to Off 
						Filter_Pols[xx][yy+colour*nY_Noise][rr]=-1
					endif
					Filter_SDs[xx][yy+colour*nY_Noise][rr]=V_SDev
				endfor
			endfor
			
			string filter_name = output_name_individual+Num2Str(rr)+"_"+Num2Str(colour) // creates a name for the filter of each ROI
			duplicate /o CurrentFilter $filter_name 
			
			variable nX_NoiseCrop = nX_Noise-CropNoiseEdges*2
			variable nY_NoiseCrop = nY_Noise-CropNoiseEdges*2
		endif		
		//
		
	endfor // colourloop end
	print "."

endfor

// adjust the corr maps
for (rr=0;rr<nROIs;rr+=1)
	make /o/n=(nX_NoiseCrop,nY_NoiseCrop+nColours*colour) currentCorr = Filter_Corrs[p+CropNoiseEdges][q+CropNoiseEdges][rr]
	Redimension /n=(nX_NoiseCrop*nY_noiseCrop) currentCorr	
	Filter_Corrs[][][rr]/=StatsMedian(currentCorr)
endfor

//


if (adjust_by_pols==1)
	Filter_Corrs[][][]*=Filter_Pols[p][q][r]
	Filter_SDs[][][]*=Filter_Pols[p][q][r]
endif


	// compute SD of concatenated filter
	duplicate /o STRFs_concatenated STRFs_concatenated_SMth
	if (preSDProjectSmooth>0)
		Smooth /Dim=0 preSDProjectSmooth, STRFs_concatenated_SMth
		Smooth /Dim=1 preSDProjectSmooth, STRFs_concatenated_SMth
	endif
	// z-normalise based on 1st frame
	make /o/n=(nX_Noise,nY_Noise) tempwave = STRFs_concatenated_SMth[p][q][0]
	ImageStats/Q tempwave
	STRFs_concatenated_SMth[][][]-=V_Avg
	STRFs_concatenated_SMth[][][]/=V_SDev
	
	make /o/n=(nX_Noise,nY_Noise*nColours) ConcatenatedFilter_SD = NaN
	for (xx=0;xx<nX_Noise;xx+=1)
		for (yy=0;yy<nY_Noise*nColours;yy+=1)
			make /o/n=(nF_Filter*nROIs) CurrentTrace = STRFs_concatenated_SMth[xx][yy][p]
			wavestats/Q CurrentTrace 
			ConcatenatedFilter_SD[xx][yy]=V_SDev
		endfor
	endfor



// Make Corr projection Montage for Display
variable nROIsMax_Display_per_row = 20
variable nRows = Ceil((nROIs)/nROIsMax_Display_per_row) // +1 as last one is the concatenated one
variable nColumns = nROIsMax_Display_per_row
if (nRows==1)
	nColumns = nROIs
endif
make /o/n=(nColumns*nX_Noise,nRows*nY_Noise*nColours) STRF_Corr_Montage = NaN
variable currentXCoordinate = 0
variable currentYCoordinate = 0
for (rr=0;rr<nRois;rr+=1) // goes through all ROIs
	STRF_Corr_Montage[currentXCoordinate*nX_Noise,(currentXCoordinate+1)*nX_Noise-1][currentYCoordinate*nY_Noise*nColours,(currentYCoordinate+1)*nY_Noise*nColours-1]=Filter_Corrs[p-currentXCoordinate*nX_Noise][q-currentYCoordinate*nY_Noise*nColours][rr]
	currentXCoordinate+=1
	if (currentXCoordinate>nColumns-1)
		currentXCoordinate=0
		currentYCoordinate+=1
	endif
endfor

// make RGB version of the montage
make /o/n=(nColumns*nX_Noise,nRows*nY_Noise,3) STRF_Corr_Montage_RGB = NaN
currentXCoordinate = 0
currentYCoordinate = 0
for (rr=0;rr<nRois;rr+=1) // goes through all ROIs
	STRF_Corr_Montage_RGB[currentXCoordinate*nX_Noise,(currentXCoordinate+1)*nX_Noise-1][currentYCoordinate*nY_Noise,(currentYCoordinate+1)*nY_Noise-1][0]=Filter_Corrs[p-currentXCoordinate*nX_Noise][q-currentYCoordinate*nY_Noise][rr] // Red is Red (0)
	STRF_Corr_Montage_RGB[currentXCoordinate*nX_Noise,(currentXCoordinate+1)*nX_Noise-1][currentYCoordinate*nY_Noise,(currentYCoordinate+1)*nY_Noise-1][1]=Filter_Corrs[p-currentXCoordinate*nX_Noise][q-currentYCoordinate*nY_Noise+nY_Noise*1][rr] // Green is Green (1)
	STRF_Corr_Montage_RGB[currentXCoordinate*nX_Noise,(currentXCoordinate+1)*nX_Noise-1][currentYCoordinate*nY_Noise,(currentYCoordinate+1)*nY_Noise-1][2]=Filter_Corrs[p-currentXCoordinate*nX_Noise][q-currentYCoordinate*nY_Noise+nY_Noise*3][rr] // Blue is UV (3)
	currentXCoordinate+=1
	if (currentXCoordinate>nColumns-1)
		currentXCoordinate=0
		currentYCoordinate+=1
	endif
endfor

duplicate/o STRF_Corr_Montage_RGB STRF_Corr_Montage_RGB2
STRF_Corr_Montage_RGB2[][][]=abs(STRF_Corr_Montage_RGB[p][q][r])

STRF_Corr_Montage_RGB[][][]/=RGB_Attenuation
STRF_Corr_Montage_RGB+=1
STRF_Corr_Montage_RGB*=2^15-1
STRF_Corr_Montage_RGB[][][]=(STRF_Corr_Montage_RGB[p][q][r]<0)?(0):(STRF_Corr_Montage_RGB[p][q][r])
STRF_Corr_Montage_RGB[][][]=(STRF_Corr_Montage_RGB[p][q][r]>2^16-1)?(2^16-1):(STRF_Corr_Montage_RGB[p][q][r])

STRF_Corr_Montage_RGB2[][][]/=RGB_Attenuation
STRF_Corr_Montage_RGB2*=2^15-1
STRF_Corr_Montage_RGB2[][][]=(STRF_Corr_Montage_RGB2[p][q][r]<0)?(0):(STRF_Corr_Montage_RGB2[p][q][r])
STRF_Corr_Montage_RGB2[][][]=(STRF_Corr_Montage_RGB2[p][q][r]>2^16-1)?(2^16-1):(STRF_Corr_Montage_RGB2[p][q][r])



print " done."	

////////////////////////////////////////////////////


// export handling
duplicate /o Filter_Corrs $output_name_Corr
duplicate /o Filter_SDs $output_name_SD

// display
string tracename

if (Display_Stuff==1)
		
	// display the Corr montage
	display /k=1
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	Appendimage STRF_Corr_Montage
	ModifyGraph fSize=8,noLabel=2,axThick=0
	ModifyImage STRF_Corr_Montage ctab= {-10,10,RedWhiteBlue,0} // 10 means 10 times the median
	
endif	

// cleanup
killwaves CurrentFilter, Filter_SDs, InputStack,InputTraces,InputTraceTimes
killwaves W_Statslinearcorrelationtest
killwaves CurrentFilter_Smth, tempwave,STRFs_concatenated_SMth
killwaves NoiseStimulus_Frameprecision
killwaves MeanNeighbourPixelCorr,px1,px2,px3,px4,px5,px6,px7,px8
killwaves ColourLookup, CurrentTrace

end






end