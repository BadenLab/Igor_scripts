#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_AveragingSuite_Chopup()


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
// 5 //  check if Averages"N" is there
if (waveexists($"Averages"+Num2Str(Channel))==0)
	print "Warning: Averages wave not yet generated - doing that now..."
	OS_BasicAveraging()
	DoUpdate
endif
// 6 //  check if AverageStack0" is there
if (waveexists($"AverageStack"+Num2Str(Channel))==0)
	print "Warning: AverageStack0 wave not yet generated - please compute that first..."
	abort
endif

variable nPlanes = OS_Parameters[%nPlanes]
variable Triggermode = OS_Parameters[%Trigger_Mode]

variable AverageStack_Chopup = OS_Parameters[%AvgStack_SkipTrig] // every how many triggers to chop
variable AverageStack_FirstPlane = OS_Parameters[%AvgStack_firstplane]

variable AverageStack_SavePlanes = 0
variable AverageStack_SaveDoubleChop = 0

wave AverageStack0
wave Triggertimes_frame

variable ss,pp, xx, yy
variable nX = Dimsize(AverageStack0,0)
variable nY = Dimsize(AverageStack0,1)
variable nF = Dimsize(AverageStack0,2)

variable nSubStacks = Ceil(Triggermode / AverageStack_Chopup)
variable nF_Substacks = Ceil(nF/nSubStacks)

print nSubStacks, "Substacks made with", nF_Substacks, "Frames each"

duplicate /o AverageStack0 AverageStack_process

	
/////////////
		

make /o/n=(nX * nSubStacks, nY, nF_SubStacks) AverageStack0_Chopped = NaN			

			
for (ss=0;ss<nSubStacks;ss+=1)
	variable SubStart = TriggerTimes_Frame[ss*AverageStack_Chopup] - TriggerTimes_Frame[0] 
	string SubStackName = "AverageSubStack_"+Num2Str(ss)
	make /o/n=(nX,nY,nF_SubStacks) TempStack = AverageStack_process[p][q][r+SubStart]
	AverageStack0_Chopped[ss*nX, (ss+1)*nX-1][][]=TempStack[p-(ss*nX)][q][r] // append in X dimension
	duplicate /o TempStack  $SubStackName
endfor


// chop by plane as well, if applicable - this

variable nY_per_plane = nY / nPlanes

make /o/n=(nX * nSubStacks,nY_per_plane,nF_SubStacks * nPlanes) AverageStack0_Chopped_byPlane = NaN
make /o/n=(nX ,nY_per_plane,nF_SubStacks * nPlanes * nSubStacks) AverageStack0_DoubleChopped = NaN
for (pp=0;pp<nPlanes;pp+=1)
	variable Currentplane = pp + (AverageStack_FirstPlane -1)
	if (CurrentPlane > (nPlanes-1))
		CurrentPlane-=nPlanes
	endif
	make /o/n=(nX * nSubStacks,nY_per_plane,nF_SubStacks) TempStack = AverageStack0_Chopped[p][q+CurrentPlane*nY_per_Plane][r]
	AverageStack0_Chopped_byPlane[][][pp*nF_SubStacks,(pp+1)*nF_SubStacks-1]=TempStack[p][q][r-pp*nF_SubStacks]
	for (ss=0;ss<nSubStacks;ss+=1)
		SubStart = TriggerTimes_Frame[ss*AverageStack_Chopup] - TriggerTimes_Frame[0] 
		make /o/n=(nX,nY_per_plane,nF_SubStacks) TempStack2 = TempStack[p+ss*nX][q][r]
		AverageStack0_DoubleChopped[][][pp*nF_SubStacks*nSubStacks+ss*nF_SubStacks,pp*nF_SubStacks*nSubStacks+(ss+1)*nF_SubStacks-1]=TempStack2[p][q][r-(pp*nF_SubStacks*nSubStacks+ss*nF_SubStacks)]
	endfor
	killwaves TempStack2
endfor

if (AverageStack_SavePlanes==1)
	imagesave /s/f/t="tiff" AverageStack0_Chopped_byPlane
endif

if (AverageStack_SaveDoubleChop==1)
	imagesave /s/f/t="tiff" AverageStack0_DoubleChopped
endif

// cleanup
killwaves TempStack

OS_AveragingSuite_Display(nSubStacks)

end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function OS_AveragingSuite_Display(nStimuli)
variable nStimuli

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
// 5 //  check if Averages"N" is there
//if (waveexists($"Averages"+Num2Str(Channel))==0)
	//print "Warning: Averages wave not yet generated - doing that now..."
	//OS_BasicAveraging() - makes it loop if AverageStack0 not jet made...
	//DoUpdate
//endif
// 6 //  check if AverageStack0" is there
if (waveexists($"AverageStack"+Num2Str(Channel))==0)
	print "Warning: AverageStack0 wave not yet generated - please compute that first..."
	abort
endif
// 7 //  check if AverageStack0_DoubleChopped" is there
if (waveexists($"AverageStack0_DoubleChopped")==0)
	print "Warning: AverageStack0_DoubleChopped wave not yet generated - please compute that first..."
	abort
endif

wave AverageStack0_DoubleChopped
variable/G gnLayers = OS_Parameters[%nPlanes]
variable/G gnStimuli = nStimuli//OS_Parameters[%Trigger_Mode]
variable/G gCurrentLayer = 0
variable/G gCurrentStimulus = 0

variable/G gContrastLow = 55500
variable/G gContrastHigh = 57000
variable/G gContrastGain = 3

variable/G gEndlessLoop = 0 
variable/G gLoopStimuli = 1


display /N=MovieViewer /k=1
Appendimage AverageStack0_DoubleChopped
String iName= WMTopImageGraph()		// find one top image in the top graph window
Wave w= $WMGetImageWave(iName)	// get the wave associated with the top image.
String/G imageName=nameOfWave(w)



ControlInfo TimeAxis
ControlInfo kwControlBar

Variable/G gLeftLim=0,gRightLim,gFrame=0
Variable/G gRightLim=(DimSize(w,2)-1)/(gnLayers*gnStimuli)
variable/G gnFrames = gRightLim

GetWindow kwTopWin,gsize
Variable/G gOriginalHeight= V_Height		// we append below original controls (if any)
ControlBar gOriginalHeight+70

GetWindow kwTopWin,gsize

String cmd
// time slider	
Slider TimeAxis,pos={V_left+10,gOriginalHeight+9},size={V_right-V_left-(kImageSliderLMargin+100),16},proc=OS_ExecuteSlider
Slider TimeAxis,limits={0,gRightLim,1},value= 0,vert= 0,ticks=0,side=0,variable=gFrame	
SetVariable TimeVal,pos={V_right-kImageSliderLMargin-85,gOriginalHeight+9},size={100,14}
SetVariable TimeVal,limits={0,INF,1},title="Frames",proc=OS_ExecuteSliderVar
sprintf cmd,"SetVariable TimeVal,value=%s",GetDataFolder(1)+"gFrame"
Execute cmd

// Layer slider	
Slider LayerAxis,pos={V_left+10,gOriginalHeight+29},size={V_right-V_left-(kImageSliderLMargin+100),16},proc=OS_ExecuteSlider
Slider LayerAxis,limits={0,gnLayers-1,1},value= 0,vert= 0,ticks=0,side=0,variable=gCurrentLayer	
SetVariable LayerVal,pos={V_right-kImageSliderLMargin-85,gOriginalHeight+29},size={100,14}
SetVariable LayerVal,limits={0,INF,1},title="Layers",proc=OS_ExecuteSliderVar
sprintf cmd,"SetVariable LayerVal,value=%s",GetDataFolder(1)+"gCurrentLayer"
Execute cmd

// Colour slider	
Slider ColourAxis,pos={V_left+10,gOriginalHeight+49},size={V_right-V_left-(kImageSliderLMargin+100),16},proc=OS_ExecuteSlider
Slider ColourAxis,limits={0,gnStimuli-1,1},value= 0,vert= 0,ticks=0,side=0,variable=gCurrentStimulus	
SetVariable ColourVal,pos={V_right-kImageSliderLMargin-85,gOriginalHeight+49},size={100,14}
SetVariable ColourVal,limits={0,INF,1},title="Stims",proc=OS_ExecuteSliderVar
sprintf cmd,"SetVariable ColourVal,value=%s",GetDataFolder(1)+"gCurrentStimulus"
Execute cmd

// Play
Button PlayMovie, pos={V_right-kImageSliderLMargin+25,gOriginalHeight+9},size={80,18}
Button PlayMovie, title="Play",proc=OS_AutoAdvanceSlider
Checkbox MovieEndless pos={V_right-kImageSliderLMargin+25,gOriginalHeight+29}
Checkbox MovieEndless title="Endless", variable= gEndlessLoop
Checkbox MovieLoopStims pos={V_right-kImageSliderLMargin+25,gOriginalHeight+49}
Checkbox MovieLoopStims title="Loop Stims.", variable= gLoopStimuli


// Contrast
SetVariable ContrastLowVal,pos={V_right-kImageSliderLMargin+125,gOriginalHeight+9},size={80,14}
SetVariable ContrastLowVal,limits={-INF,INF,1},title="Low",proc=OS_ExecuteSliderVar
sprintf cmd,"SetVariable ContrastLowVal,value=%s","gContrastLow"
Execute cmd
SetVariable ContrastHighVal,pos={V_right-kImageSliderLMargin+125,gOriginalHeight+29},size={80,14}
SetVariable ContrastHighVal,limits={-INF,INF,1},title="High",proc=OS_ExecuteSliderVar
sprintf cmd,"SetVariable ContrastHighVal,value=%s","gContrastHigh"
Execute cmd

Button AutoContrast, pos={V_right-kImageSliderLMargin+125,gOriginalHeight+49},size={80,18}
Button AutoContrast, title="Auto",proc=OS_ExecuteAutoContrast

ModifyImage $imageName plane=0+(gCurrentLayer*gnStimuli+gCurrentStimulus)*gnFrames
	
WaveStats/Q w
ModifyImage $imageName ctab= {V_min,V_max,,0}	// missing ctb to leave it unchanced.
	
OS_ExecuteAutoContrast("")
	
end


// 
//*******************************************************************************************************
function OS_ExecuteSlider(name, value, event)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved

	NVAR gFrame
	NVAR gCurrentLayer
	NVAR gCurrentStimulus
	NVAR gnStimuli
	NVAR gnFrames
	NVAR gContrastLow
	NVAR gContrastHigh
	SVAR imageName
	ModifyImage  $imageName plane=(gFrame+(gCurrentLayer*gnStimuli+gCurrentStimulus)*gnFrames)	
	ModifyImage $imageName ctab= {gContrastLow, gContrastHigh,Grays,0}	
	return 0				// other return values reserved
end
//*******************************************************************************************************
Function OS_ExecuteSliderVar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		// comment the following line if you want to disable live updates.
		case 3: // Live update
			Variable dval = sva.dval
			OS_ExecuteSlider("",0,0)
			break
	endswitch

	return 0
End
//*******************************************************************************************************
function OS_AutoAdvanceSlider(name)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved
	NVAR gFrame
	NVAR gCurrentLayer
	NVAR gCurrentStimulus
	NVAR gnStimuli
	NVAR gnFrames
	NVAR gContrastLow
	NVAR gContrastHigh
	NVAR gEndlessLoop
	NVAR gLoopStimuli
	
	SVAR imageName
	ModifyImage  $imageName plane=(gFrame+(gCurrentLayer*gnStimuli+gCurrentStimulus)*gnFrames)	
	ModifyImage $imageName ctab= {gContrastLow, gContrastHigh,Grays,0}	
	DoUpdate
	
	Variable Framerate = 20
	Variable ms = 1000 / Framerate
	Variable delay = ms*1000
	Variable start = StopMSTimer(-2)
	do
	while(StopMSTimer(-2) - start < delay)

	gFrame+=1
	if (gFrame>gnFrames-1)
		gFrame = 0
		if (gLoopStimuli==1)
			gCurrentStimulus+=1
			if (gCurrentStimulus>gnStimuli-1)
				gCurrentStimulus = 0
				if (gEndlessLoop==0)
					ModifyImage  $imageName plane=(gFrame+(gCurrentLayer*gnStimuli+gCurrentStimulus)*gnFrames)	
					ModifyImage $imageName ctab= {gContrastLow, gContrastHigh,Grays,0}	
					abort
				endif 
			endif
		else
			if (gEndlessLoop==0)
				ModifyImage  $imageName plane=(gFrame+(gCurrentLayer*gnStimuli+gCurrentStimulus)*gnFrames)	
				ModifyImage $imageName ctab= {gContrastLow, gContrastHigh,Grays,0}	
				abort
			endif
		endif
		
		
		
		
	endif
	
	OS_AutoAdvanceSlider(name )
end


//*******************************************************************************************************
function OS_ExecuteAutoContrast(name)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved

	NVAR gFrame
	NVAR gCurrentLayer
	NVAR gCurrentStimulus
	NVAR gnStimuli
	NVAR gnFrames
	NVAR gContrastLow
	NVAR gContrastHigh
	NVAR gContrastGain
	
	SVAR imageName

	Duplicate /o $ImageName TempStack
	variable nX = Dimsize(TempStack,0)
	variable nY = Dimsize(TempStack,1)
	
	gContrastGain+=1
	if (gContrastGain>10)
		gContrastGain = 1
	endif
	
	make /o/n=(nX,nY) tempimage = TempStack[p][q][(gFrame+(gCurrentLayer*gnStimuli+gCurrentStimulus)*gnFrames)]	
	ImageStats/Q tempimage
	gContrastLow = V_Min
	gContrastHigh = V_Avg + V_SDev * gContrastGain
	Killwaves TempImage, TempStack
	
	OS_ExecuteSlider(name, value, event)
end

//*******************************************************************************************************
function OS_Average_RGBMontage()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
// 2 //  check if AverageStack0" is there
if (waveexists($"AverageStack0")==0)
	print "Warning: AverageStack0 wave not yet generated - please compute that first..."
	abort
endif

if (waveexists($"QC_projection")==0)
	print "Warning: QC_projection wave not found..."
	abort
endif

//
variable ff,xx,yy,rr
//


variable/G gImage1Start = 0
variable/G gImage1Duration = 20
variable/G gImage2Start = 20
variable/G gImage2Duration = 20
variable/G gImage3Start = 40
variable/G gImage3Duration = 20
variable/G gContrastEq = 0.4
variable/G gContrast_Zeroclip = 0.04
variable/G gContrastMask = 1
variable/G gRGBeq = 7
variable/G gRGB_Zeroclip = 10000
variable/G gRGBMask = 1
variable/G gUse01Eq = 0
variable /G gnF_baseline = 0

wave AverageStack0
wave Stack_Ave
wave QC_projection



duplicate /o Stack_Ave Stack_Ave_01
imagestats/Q Stack_Ave_01
Stack_Ave_01-=V_Min
Stack_Ave_01/=V_Max-V_Min

duplicate /o Stack_Ave_01 tempimage
Stack_Ave_01=sqrt(tempimage[p][q])

variable nX = Dimsize(AverageStack0,0)
variable nY = Dimsize(AverageStack0,1)
variable nF = Dimsize(AverageStack0,2)

make /o/n=(nF,3) MarkerTrace = 0
if (gImage1Start+gImage1Duration>nF-1)
	gImage1Duration=nF-gImage1Start-1
endif
if (gImage2Start+gImage2Duration>nF-1)
	gImage2Duration=nF-gImage2Start-1
endif
if (gImage3Start+gImage3Duration>nF-1)
	gImage3Duration=nF-gImage3Start-1
endif

MarkerTrace[gImage1Start,gImage1Start+gImage1Duration][0] = 1
MarkerTrace[gImage2Start,gImage2Start+gImage2Duration][1] = 1
MarkerTrace[gImage3Start,gImage3Start+gImage2Duration][2] = 1
make /o/n=(nX,nY,3) Activity_Images = 0
make /o/n=(nX,nY) Reference_Image = 0
make /o/n=(nX,nY) Contrast_Image = 0

// ReferenceIMage
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1) 
		make /o/n=(nF) Tempwave = AverageStack0[xx][yy][p]
		Reference_Image[xx][yy]=WaveMin(Tempwave)
	endfor
endfor

// make a 0:1 equalised version of Average Stack as an option for the below
duplicate /o AverageStack0 AverageStack0_01eq
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		make /o/n=(nF) tempwave = AverageStack0[xx][yy][p]
		Wavestats/Q Tempwave
		AverageStack0_01eq[xx][yy][]-=V_Min
		AverageStack0_01eq[xx][yy][]/=V_Max-V_Min
	endfor
endfor
	
if (gUse01Eq==0)
	// image 1
	for (ff=gImage1Start;ff<gImage1Start+gImage1Duration;ff+=1)
		Activity_Images[][][0]+=AverageStack0[p][q][ff]/gImage1Duration
	endfor
	// image 2
	for (ff=gImage2Start;ff<gImage2Start+gImage2Duration;ff+=1)
		Activity_Images[][][1]+=AverageStack0[p][q][ff]/gImage2Duration
	endfor
	// image 3
	for (ff=gImage3Start;ff<gImage3Start+gImage3Duration;ff+=1)
		Activity_Images[][][2]+=AverageStack0[p][q][ff]/gImage3Duration
	endfor
	Activity_Images[][][]-=Reference_Image[p][q]
	make /o/n=(nX,nY*2) TempImage = 0
	Tempimage[][0,nY-1]=Activity_Images[p][q][0]
	Tempimage[][nY,nY*2-1]=Activity_Images[p][q-nY][1]
	ImageStats/Q Tempimage
	Activity_Images/=V_Max
else
	// image 1
	for (ff=gImage1Start;ff<gImage1Start+gImage1Duration;ff+=1)
		Activity_Images[][][0]+=AverageStack0_01eq[p][q][ff]/gImage1Duration
	endfor
	// image 2
	for (ff=gImage2Start;ff<gImage2Start+gImage2Duration;ff+=1)
		Activity_Images[][][1]+=AverageStack0_01eq[p][q][ff]/gImage2Duration
	endfor
	// image 3
	for (ff=gImage3Start;ff<gImage3Start+gImage3Duration;ff+=1)
		Activity_Images[][][2]+=AverageStack0_01eq[p][q][ff]/gImage3Duration
	endfor
endif

if (gImage1Duration==0)
	Activity_Images[][][0]=0
endif
if (gImage2Duration==0)
	Activity_Images[][][1]=0
endif
if (gImage3Duration==0)
	Activity_Images[][][2]=0
endif

Contrast_Image[][]=(Activity_Images[p][q][0]-Activity_Images[p][q][1])/(Activity_Images[p][q][0]+Activity_Images[p][q][1]) // contrast uses R and G only

if (gContrastMask==1)
	Contrast_Image[][]*=QC_projection[p][q]
endif
Contrast_Image[][][] = (Contrast_Image[p][q][r]>-gContrast_Zeroclip && Contrast_Image[p][q][r]<gContrast_Zeroclip)?(0):(Contrast_Image[p][q][r])




// RGB
make /o/n=(nX,nY,3) Activity_RGB = 0
Activity_RGB[][][0] = Activity_Images[p][q][0]*2^16 * gRGBeq
Activity_RGB[][][1] = Activity_Images[p][q][1]*2^16 * gRGBeq
Activity_RGB[][][2] = Activity_Images[p][q][2]*2^16 * gRGBeq
if (gRGBMask==1)
	Activity_RGB[][]*=QC_projection[p][q]
endif
Activity_RGB[][][] = (Activity_RGB[p][q][r]>2^16-1)?(2^16-1):(Activity_RGB[p][q][r])
Activity_RGB[][][] = (Activity_RGB[p][q][r]<gRGB_Zeroclip)?(0):(Activity_RGB[p][q][r])



// make framewise ROI trace averages
wave Averages0
variable nROIs = Dimsize(Averages0,1)
variable nP = Dimsize(Averages0,0)
Duplicate/O Averages0,Averages0_frameWise
Resample/DOWN=(nP/nF) Averages0_frameWise
Setscale/p x,0,1,"",Averages0_frameWise

killwaves TempImage, Tempwave

// zero all averages based on first X frames - shifting
if (gnF_baseline>0)
	make /o/n=(gnF_baseline) tempwave = NaN
	for (rr=0;rr<nROIs;rr+=1)
		tempwave[]=Averages0_frameWise[p][rr]
		WaveStats/Q tempwave
		Averages0_frameWise[][rr]-=V_Min
	endfor
	killwaves tempwave
endif

//
display /k=1

Appendimage/G=1 /l=ImageY1 /b=ImageX1 Activity_Images
Appendimage/G=1 /l=ImageY1 /b=ImageX2 Activity_Images
Appendimage/G=1 /l=ImageY1 /b=ImageX3 Activity_Images

Appendimage /l=ImageY2 /b=ImageX1 Contrast_Image
Appendimage /l=ImageY2 /b=ImageX2 Activity_RGB
Appendimage /l=ImageY2 /b=ImageX3 QC_projection

ModifyImage Activity_Images#1 plane=1 
ModifyImage Activity_Images#2 plane=2

Appendtograph /l=MarkerY /b=ActivityX MarkerTrace[][0], MarkerTrace[][1], MarkerTrace[][2]
for (rr=0;rr<nROIs;rr+=1)
	Appendtograph /l=ActivityY /b=ActivityX Averages0_frameWise[][rr]
endfor

ModifyGraph fSize=8,noLabel=2,lblPos=47,freePos={0,kwFraction}
ModifyGraph axThick=0
ModifyGraph axisEnab(ImageY1)={0.7,1},axisEnab(ActivityY)={0.03,0.30},axisEnab(ActivityX)={0.1,0.95}
ModifyGraph axisEnab(ImageY2)={0.35,0.65}
ModifyGraph axisEnab(ImageX1)={0.1,0.35},axisEnab(ImageX2)={0.4,0.65}, axisEnab(ImageX3)={0.7,0.95}
ModifyGraph rgb=(0,0,0,(2^16-1)/sqrt(nROIs)) // opacity of traces are scaled by sqrt(nROIs)
ModifyGraph axisEnab(MarkerY)={0.03,0.3}
ModifyGraph mode(MarkerTrace)=7,hbFill(MarkerTrace)=2,mode(MarkerTrace#1)=7,hbFill(MarkerTrace#1)=2,mode(MarkerTrace#2)=7,hbFill(MarkerTrace#2)=2

ModifyGraph rgb(MarkerTrace)=(65535,49151,49151),rgb(MarkerTrace#1)=(49151,65535,49151),rgb(MarkerTrace#2)=(49151,53155,65535)
ModifyImage Contrast_Image ctab= {-gContrastEq,gContrastEq,RedWhiteGreen,1}

ModifyImage Activity_Images ctab= {*,*,Red,0};DelayUpdate
ModifyImage Activity_Images#1 ctab= {*,*,Green,0}
ModifyImage Activity_Images#2 ctab= {*,*,Blue,0}

ModifyGraph width=500,height={Aspect,0.7}

//
// Trigger box	

	
	String iName= WMTopImageGraph()		// find one top image in the top graph window
	Wave w= $WMGetImageWave(iName)	// get the wave associated with the top image.
	String/G imageName2=nameOfWave(w)
	GetWindow kwTopWin,gsize
	String cmd
	
	SetVariable gImage1Start,pos={V_left+20,V_top+20},size={100,14}
	SetVariable gImage1Start,limits={0,nF-1,1},title="rStart",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gImage1Start,value=%s",GetDataFolder(1)+"gImage1Start"
	Execute cmd
	
	SetVariable gImage1Duration,pos={V_left+20,V_top+45},size={100,14}
	SetVariable gImage1Duration,limits={0,nF-(gImage1Start+1),1},title="rF",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gImage1Duration,value=%s",GetDataFolder(1)+"gImage1Duration"
	Execute cmd
	
	SetVariable gImage2Start,pos={V_left+20,V_top+90},size={100,14}
	SetVariable gImage2Start,limits={0,nF-1,1},title="gStart",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gImage2Start,value=%s",GetDataFolder(1)+"gImage2Start"
	Execute cmd
	
	SetVariable gImage2Duration,pos={V_left+20,V_top+115},size={100,14}
	SetVariable gImage2Duration,limits={0,nF-(gImage2Start+1),1},title="gF",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gImage2Duration,value=%s",GetDataFolder(1)+"gImage2Duration"
	Execute cmd
	
	SetVariable gImage3Start,pos={V_left+20,V_top+160},size={100,14}
	SetVariable gImage3Start,limits={0,nF-1,1},title="bStart",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gImage3Start,value=%s",GetDataFolder(1)+"gImage3Start"
	Execute cmd
	
	SetVariable gImage3Duration,pos={V_left+20,V_top+185},size={100,14}
	SetVariable gImage3Duration,limits={0,nF-(gImage3Start+1),1},title="bF",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gImage3Duration,value=%s",GetDataFolder(1)+"gImage3Duration"
	Execute cmd
	
	SetVariable gContrastEq,pos={V_left+20,V_top+260},size={100,14}
	SetVariable gContrastEq,limits={0,1,0.05},title="Eq.",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gContrastEq,value=%s",GetDataFolder(1)+"gContrastEq"
	Execute cmd
	
	SetVariable gContrastMask,pos={V_left+20,V_top+285},size={100,14}
	SetVariable gContrastMask,limits={0,1,1},title="Mask",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gContrastMask,value=%s",GetDataFolder(1)+"gContrastMask"
	Execute cmd
	
	SetVariable gContrast_Zeroclip,pos={V_left+20,V_top+310},size={100,14}
	SetVariable gContrast_Zeroclip,limits={0,1,0.02},title="0-Clip",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gContrast_Zeroclip,value=%s",GetDataFolder(1)+"gContrast_Zeroclip"
	Execute cmd
	
	SetVariable gRGBeq,pos={V_left+20,V_top+360},size={100,14}
	SetVariable gRGBeq,limits={0,50,0.5},title="RGB-Eq.",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gRGBeq,value=%s",GetDataFolder(1)+"gRGBeq"
	Execute cmd
	
	SetVariable gRGBMask,pos={V_left+20,V_top+385},size={100,14}
	SetVariable gRGBMask,limits={0,1,1},title="Mask",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gRGBMask,value=%s",GetDataFolder(1)+"gRGBMask"
	Execute cmd
	
	SetVariable gRGB_Zeroclip,pos={V_left+20,V_top+410},size={100,14}
	SetVariable gRGB_Zeroclip,limits={0,2^16-1,1000},title="0-Clip",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gRGB_Zeroclip,value=%s",GetDataFolder(1)+"gRGB_Zeroclip"
	Execute cmd
	
	
	SetVariable gUse01Eq,pos={V_left+20,V_top+450},size={100,14}
	SetVariable gUse01Eq,limits={0,1,1},title="0-1 norm.",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gUse01Eq,value=%s",GetDataFolder(1)+"gUse01Eq"
	Execute cmd
	
	SetVariable gnF_baseline,pos={V_left+20,V_top+490},size={100,14}
	SetVariable gnF_baseline,limits={0,nF-1,1},title="base_nF",proc=OS_ExecuteVar_RGB
	sprintf cmd,"SetVariable gnF_baseline,value=%s",GetDataFolder(1)+"gnF_baseline"
	Execute cmd
	
	
	
	
	

end

//*******************************************************************************************************
function OS_Execute_RGB(name, value, event)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved
	
	NVAR gImage1Start
	NVAR gImage1Duration
	NVAR gImage2Start
	NVAR gImage2Duration
	NVAR gImage3Start
	NVAR gImage3Duration
	NVAR gContrastEQ
	NVAR gCOntrast_ZeroClip
	NVAR gContrastMask
	NVAR gRGBeq
	NVAR gRGBMask
	NVAR gRGB_Zeroclip
	NVAR gUse01Eq
	NVAR gnF_baseline
	
	//SVAR imageName2
	//ModifyImage  $imageName2 plane=(gCurrentTrigger)	
	
	wave AverageStack0
	wave AverageStack0_01eq
	wave Activity_Images
	Activity_Images = 0
	wave Reference_Image
	wave Contrast_Image
	wave Stack_Ave_01
	wave QC_projection
	wave Averages0
	wave Averages0_frameWise
	
	variable nX = Dimsize(AverageStack0,0)
	variable nY = Dimsize(AverageStack0,1)
	variable nF = Dimsize(AverageStack0,2)
	variable ff

	make /o/n=(nF,3) MarkerTrace = 0
	if (gImage1Start+gImage1Duration>nF-1)
		gImage1Duration=nF-gImage1Start-1
	endif
	if (gImage2Start+gImage2Duration>nF-1)
		gImage2Duration=nF-gImage2Start-1
	endif
	if (gImage3Start+gImage3Duration>nF-1)
		gImage3Duration=nF-gImage3Start-1
	endif
	MarkerTrace[gImage1Start,gImage1Start+gImage1Duration][0] = 1
	MarkerTrace[gImage2Start,gImage2Start+gImage2Duration][1] = 1
	MarkerTrace[gImage3Start,gImage3Start+gImage3Duration][2] = 1
	
	if (gUse01Eq==0)
		// image 1
		for (ff=gImage1Start;ff<gImage1Start+gImage1Duration;ff+=1)
			Activity_Images[][][0]+=AverageStack0[p][q][ff]/gImage1Duration
		endfor
		// image 2
		for (ff=gImage2Start;ff<gImage2Start+gImage2Duration;ff+=1)
			Activity_Images[][][1]+=AverageStack0[p][q][ff]/gImage2Duration
		endfor
		// image 3
		for (ff=gImage3Start;ff<gImage3Start+gImage3Duration;ff+=1)
			Activity_Images[][][2]+=AverageStack0[p][q][ff]/gImage3Duration
		endfor
		Activity_Images[][][]-=Reference_Image[p][q]
		make /o/n=(nX,nY*2) TempImage = 0
		Tempimage[][0,nY-1]=Activity_Images[p][q][0]
		Tempimage[][nY,nY*2-1]=Activity_Images[p][q-nY][1]
		ImageStats/Q Tempimage
		Activity_Images/=V_Max
	else
		// image 1
		for (ff=gImage1Start;ff<gImage1Start+gImage1Duration;ff+=1)
			Activity_Images[][][0]+=AverageStack0_01eq[p][q][ff]/gImage1Duration
		endfor
		// image 2
		for (ff=gImage2Start;ff<gImage2Start+gImage2Duration;ff+=1)
			Activity_Images[][][1]+=AverageStack0_01eq[p][q][ff]/gImage2Duration
		endfor
		// image 3
		for (ff=gImage3Start;ff<gImage3Start+gImage3Duration;ff+=1)
			Activity_Images[][][2]+=AverageStack0_01eq[p][q][ff]/gImage3Duration
		endfor
	endif

	if (gImage1Duration==0)
		Activity_Images[][][0]=0
	endif
	if (gImage2Duration==0)
		Activity_Images[][][1]=0
	endif
	if (gImage3Duration==0)
		Activity_Images[][][2]=0
	endif
	
	
	Contrast_Image[][]=(Activity_Images[p][q][0]-Activity_Images[p][q][1])/(Activity_Images[p][q][0]+Activity_Images[p][q][1]) // only R vs G
	if (gContrastMask==1)
		Contrast_Image[][]*=QC_projection[p][q]
	endif
	Contrast_Image[][][] = (Contrast_Image[p][q][r]>-gContrast_Zeroclip && Contrast_Image[p][q][r]<gContrast_Zeroclip)?(0):(Contrast_Image[p][q][r])


	make /o/n=(nX,nY,3) Activity_RGB = 0
	Activity_RGB[][][0] = Activity_Images[p][q][0]*2^16 * gRGBeq
	Activity_RGB[][][1] = Activity_Images[p][q][1]*2^16 * gRGBeq
	Activity_RGB[][][2] = Activity_Images[p][q][2]*2^16 * gRGBeq
	if (gRGBMask==1)
		Activity_RGB[][]*=QC_projection[p][q]
	endif
	Activity_RGB[][][] = (Activity_RGB[p][q][r]>2^16-1)?(2^16-1):(Activity_RGB[p][q][r])
	Activity_RGB[][][] = (Activity_RGB[p][q][r]<gRGB_Zeroclip)?(0):(Activity_RGB[p][q][r])
	killwaves TempImage
	
	ModifyImage Contrast_Image ctab= {-gContrastEq,gContrastEq,RedWhiteGreen,1}
	
	// zero all averages based on first X frames - shifting
	if (gnF_baseline>0)
		variable rr
		make /o/n=(gnF_baseline) tempwave = NaN
		for (rr=0;rr<Dimsize(Averages0_frameWise,1);rr+=1)
			tempwave[]=Averages0_frameWise[p][rr]
			WaveStats/Q tempwave
			Averages0_frameWise[][rr]-=V_Min
		endfor
		killwaves tempwave
	else
		variable nP = Dimsize(Averages0,0)
		Duplicate/O Averages0,Averages0_frameWise
		Resample/DOWN=(nP/nF) Averages0_frameWise
		Setscale/p x,0,1,"",Averages0_frameWise
	endif
	
	return 0				// other return values reserved
end
//*******************************************************************************************************
Function OS_ExecuteVar_RGB(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		// comment the following line if you want to disable live updates.
		case 3: // Live update
			Variable dval = sva.dval
			OS_Execute_RGB("",0,0)
			break
	endswitch

	return 0
End

//*******************************************************************************************************

Function OS_ROIPLotter(index)
variable index

wave Snippets0
wave Averages0
wave StimMarker

variable nLoops = Dimsize(Snippets0,1)
variable ll

display /k=1 /l=StimY StimMarker
•ModifyGraph mode(StimMarker)=5,hbFill(StimMarker)=2,rgb(StimMarker)=(56797,56797,56797)
•ModifyGraph fSize(StimY)=8,noLabel(StimY)=2,axThick(StimY)=0,freePos(StimY)={0,kwFraction}


for (ll=0;ll<nLoops;ll+=1)
	string SnippetName = "Snippets0#"+Num2Str(ll)

	if (ll==0)
		SnippetName = "Snippets0"
	endif
	Appendtograph Snippets0[][ll][index]
	ModifyGraph rgb($SnippetName)=(0,0,0,19661)
endfor

Appendtograph Averages0[][index]
ModifyGraph lsize(Averages0)=1.5,rgb(Averages0)=(0,0,0)

•ModifyGraph fSize=8,axisEnab(bottom)={0.05,1},axisEnab(left)={0.05,1}

Label left "\\Z10ROI "+Num2Str(index)
end