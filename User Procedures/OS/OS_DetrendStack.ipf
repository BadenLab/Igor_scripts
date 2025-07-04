#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Official ScanM Data Preprocessing Scripts - by Tom Baden    	///
/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Requires raw 3D data in 16 bits with no preprocessing			///
///	Input Arguments - which Channel (0,1,2...?)				     	///
///	e.g. "OS_DetrendStack(0)	"							     	///
///   --> reads wDataCh0,1,2...									///
///   --> for each pixel subtracts heavily smoothed version of itself   	///
///   --> ...and adds its own mean (to avoid going out of range)		///
///	Output is new wave called wDataCh..._detrended				///
/////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_DetrendStack()

printf "Initiating...."
// flags from "OS_Parameters"
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
if (waveexists($"wDataCh0")==0)
	print "Warning: wDataCh0 does not exist... aborting"
	abort
endif

wave OS_Parameters
wave wDataCh0
////

variable nX = DimSize(wDataCh0,0)
variable nY = DimSize(wDataCh0,1)
variable nF = DimSize(wDataCh0,2)

// reducing Trigger array to 2 lines to save memory
if (waveexists($"wDataCh2")==1)
	Print "Reducing Trigger array to just 2 lines..." 
	variable nX_trig = 2
	wave wDataCh2
	make /o/n=(2,Dimsize(wDataCh2,1),Dimsize(wDataCh2,2)) TriggerChannel_reduced = wDataCh2[p][q][r]
	duplicate /o TriggerChannel_reduced wDataCh2 // overwrites the original wDataCh2
	killwaves TriggerChannel_reduced
	print "...done"
else
	print "no triggerchannel found, generating an empty one"
	make /o/n=(3,nY,nF) wDataCh2 = 0
endif

variable Channel = OS_Parameters[%Data_Channel]
variable TriggerChannel = OS_Parameters[%Trigger_Channel] 
variable nSeconds_smooth = OS_Parameters[%Detrend_smooth_window]
variable LightArtifactCut = OS_Parameters[%LightArtifact_cut]
variable nPlanes = OS_Parameters[%nPlanes]
variable SkipDetrend = OS_Parameters[%Detrend_skip]
variable nTimeBin = OS_Parameters[%Detrend_nTimeBin] 
variable LineDuration = OS_Parameters[%LineDuration]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)
string input_name2 = "wDataCh"+Num2Str(TriggerChannel)
string output_name = "wDataCh"+Num2Str(Channel)+"_detrended"
string output_name2 = "wDataCh"+Num2Str(TriggerChannel) // this will overwrite wDataCh2 e.g. - but there is the TriggerData_original backup

variable pp

// multiplane deinterleave and light artifact cut // CURRENTLY DOPESNT DO RED CHANNEL IF EVER NEEDED
if (nPlanes>1)
	print "Deinterleaving", nPlanes, "planes"
	if (waveexists($"TriggerData_original")==0)
		duplicate /o $input_name2 TriggerData_original
		duplicate /o $input_name2 TriggerData
	else
		wave TriggerData_original
		duplicate /o TriggerData_original TriggerData
	endif

	variable nF_true = floor(nF / nPlanes)
	
	make /o/n=(nX, nY*nPlanes, nF_true) InputData_deinterleaved = NaN // DUPLICATE EITHER HERE...
	make /o/n=(nX_trig, nY*nPlanes, nF_true) TriggerData_deinterleaved = NaN 
	for (pp=0;pp<nPlanes;pp+=1)
		Multithread InputData_deinterleaved[][nY*pp,nY*(pp+1)-1][]=wDataCh0[p][q-nY*pp][r*nPlanes+pp]
		Multithread TriggerData_deinterleaved[][nY*pp,nY*(pp+1)-1][]=TriggerData[p][q-nY*pp][r*nPlanes+pp]
	endfor
	
	Duplicate/o TriggerData_deinterleaved TriggerData	
	nY*=nPlanes
	nF=nF_true
	
	make /o/n=(nX, nY, nF_true) InputData = 0 // DUPLICATE ALSO HERE...
	multithread InputData[LightArtifactCut,nX-1][][]=InputData_deinterleaved[nX-1-(p-LightArtifactCut)][q][r]	
	killwaves InputData_deinterleaved, TriggerData_deinterleaved
else
	// X-Flip InputStack, but spare the light Artifact
	Duplicate/o wDataCh0 InputData	 // OR STRAIGHT DUPLICATE... (one of these is hard to avoid)
	multithread InputData[LightArtifactCut,nX-1][][]=wDataCh0[nX-1-(p-LightArtifactCut)][q][r]
endif

// make mean and SD images
make /o/n=(nX,nY) Stack_Ave = 0
make /o/n=(nX,nY) Stack_SD = 0
variable xx,yy
for (xx=0; xx<nX; xx+=1)
	for (yy=0; yy<nY; yy+=1)
		make/o/n=(nF) CurrentTrace = InputData[xx][yy][p]
		Wavestats/Q CurrentTrace
		Stack_Ave[xx][yy]=V_Avg
		Stack_SD[xx][yy]=V_SDev
	endfor
endfor	

// detrending
if (SkipDetrend==0)
	print "detrending with", nTimeBin, "frames binned for speed gain factor", nTimeBin
	// calculate size of smoothing window
	variable Framerate = 1/(nY * LineDuration) // Hz
	variable Smoothingfactor = (Framerate * nSeconds_smooth)/nTimeBin
	if (Smoothingfactor>2^15-1) // exception handling - limit smooth function to its largest allowed input
		Smoothingfactor = 2^15-1 
	endif
	
	make /o/n=(nX,nY,ceil(nF/nTimeBin)) SubtractionStack = NaN // this is another temporary DUPLICATE
	Multithread SubtractionStack[][][]=InputData[p][q][r*nTimeBin]
	Smooth/DIM=2 Smoothingfactor, SubtractionStack // This is the slow step
	Multithread InputData[][][]-=SubtractionStack[p][q][r/nTimeBin]-Stack_Ave[p][q]
	killwaves SubtractionStack
else
	print "skipping detrend..."
endif

// cut things
InputData[][][0]=InputData[p][q][1] // copy second frame into 1st to kill frame 1 artifact
make /o/n=(nX-LightArtifactCut,nY) tempimage = Stack_Ave[p+LightArtifactCut][q]
ImageStats/Q tempimage
InputData[0,LightArtifactCut][][]=V_Avg // Clip Light Artifact
Stack_Ave[0,LightArtifactCut][]=V_Avg
make /o/n=(nX-LightArtifactCut,nY) tempimage = Stack_SD[p+LightArtifactCut][q]
ImageStats/Q tempimage
Stack_SD[0,LightArtifactCut][]=V_Avg
killwaves tempimage

// generate output
if (waveexists($output_name)==1)
	killwaves $output_name
endif
rename InputData $output_name

if (nPlanes>1)
	duplicate /o TriggerData $output_name2 // if had to be deinterleaved need to fix trigger data as well
	killwaves TriggerData
endif

// cleanup
killwaves CurrentTrace

// outgoing dialogue
print " complete..."

end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_PreFormat_minimal()

printf "Initiating...."
// flags from "OS_Parameters"
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
if (waveexists($"wDataCh0")==0)
	print "Warning: wDataCh0 does not exist... aborting"
	abort
endif

wave OS_Parameters
wave wDataCh0
////

// reducing Trigger array to 2 lines to save memory
Print "Reducing Trigger array to just 2 lines..." 
variable nX_trig = 2
wave wDataCh2
make /o/n=(2,Dimsize(wDataCh2,1),Dimsize(wDataCh2,2)) TriggerChannel_reduced = wDataCh2[p][q][r]
duplicate /o TriggerChannel_reduced wDataCh2 // overwrites the original wDataCh2
killwaves TriggerChannel_reduced
print "...done"

variable nPlanes = OS_Parameters[%nPlanes]
variable LightArtifactCut = OS_Parameters[%LightArtifact_cut]

// data handling
variable nX = DimSize(wDataCh0,0)
variable nY = DimSize(wDataCh0,1)
variable nF = DimSize(wDataCh0,2)
variable pp

// multiplane deinterleave ONLY
if (nPlanes>1)
	// ... either deinterleave wDataCh0, and then rename wDataCh0_detrended + do same for Triggers
	print "Deinterleaving", nPlanes, "planes"
	if (waveexists($"TriggerData_original")==0)
		duplicate /o wDataCh2 TriggerData_original
		duplicate /o wDataCh2 TriggerData
	else
		wave TriggerData_original
		duplicate /o TriggerData_original TriggerData
	endif

	variable nF_true = floor(nF / nPlanes)
	
	make /o/n=(nX, nY*nPlanes, nF_true) InputData_deinterleaved = NaN // DUPLICATE EITHER HERE...
	make /o/n=(nX_trig, nY*nPlanes, nF_true) TriggerData_deinterleaved = NaN 
	for (pp=0;pp<nPlanes;pp+=1)
		Multithread InputData_deinterleaved[][nY*pp,nY*(pp+1)-1][]=wDataCh0[p][q-nY*pp][r*nPlanes+pp]
		Multithread TriggerData_deinterleaved[][nY*pp,nY*(pp+1)-1][]=TriggerData[p][q-nY*pp][r*nPlanes+pp]
	endfor
	
	Duplicate/o TriggerData_deinterleaved TriggerData	
	killwaves TriggerData_deinterleaved
	nY*=nPlanes
	nF=nF_true
	
	if (waveexists($"wDataCh0_detrended")==1)
		print "WARNING: wDataCh0_detrended already exists... no change implemented"
	else
		print "wDataCh0_detrended built as deinterleaved version of wDataCh0"
		rename InputData_deinterleaved wDataCh0_detrended
	endif
	
else
	// ... Or literaly just rename wDataCh0
	if (waveexists($"wDataCh0_detrended")==1)
		print "WARNING: wDataCh0_detrended already exists... aborted"
		abort
	else
		print "wDataCh0 renamed to wDataCh0_detrended"
		rename wDataCh0 wDataCh0_detrended
	endif
endif

wave wDataCh0_detrended

// make mean and SD images
make /o/n=(nX,nY) Stack_Ave = 0
make /o/n=(nX,nY) Stack_SD = 0
variable xx,yy
for (xx=0; xx<nX; xx+=1)
	for (yy=0; yy<nY; yy+=1)
		make/o/n=(nF) CurrentTrace = wDataCh0_detrended[xx][yy][p]
		Wavestats/Q CurrentTrace
		Stack_Ave[xx][yy]=V_Avg
		Stack_SD[xx][yy]=V_SDev
	endfor
endfor	

// cut things
make /o/n=(nX-LightArtifactCut,nY) tempimage = Stack_Ave[p+LightArtifactCut][q]
ImageStats/Q tempimage
Stack_Ave[0,LightArtifactCut][]=V_Avg
make /o/n=(nX-LightArtifactCut,nY) tempimage = Stack_SD[p+LightArtifactCut][q]
ImageStats/Q tempimage
Stack_SD[0,LightArtifactCut][]=V_Avg
killwaves tempimage

///

killwaves CurrentTrace
print "done that"

// generate output (wDataCh0_detrended is already dealt with above here)

if (nPlanes>1)
	duplicate /o TriggerData wDataCh2 // if had to be deinterleaved need to fix trigger data as well
	killwaves TriggerData
endif

// outgoing dialogue
print " complete..."

end
	

	
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_SaveRawAsTiff()

printf "Saving PreProc Stack as Tiff..."

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

// data handling
string output_name = "wDataCh"+Num2Str(Channel)+"_detrended"
imagesave /s/f/t="tiff" $output_name

// outgoing dialogue
print " complete..."

end

// 
