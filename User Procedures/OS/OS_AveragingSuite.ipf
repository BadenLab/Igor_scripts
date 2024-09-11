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

//variable nY_per_plane = nY / nPlanes
//make /o/n=(nX * nSubStacks,nY_per_plane,nF_SubStacks * nPlanes) AverageStack0_Chopped_byPlane = NaN
//make /o/n=(nX ,nY_per_plane,nF_SubStacks * nPlanes * nSubStacks) AverageStack0_DoubleChopped = NaN
//for (pp=0;pp<nPlanes;pp+=1)
//	variable Currentplane = pp + (AverageStack_FirstPlane -1)
//	if (CurrentPlane > (nPlanes-1))
//		CurrentPlane-=nPlanes
//	endif
//	make /o/n=(nX * nSubStacks,nY_per_plane,nF_SubStacks) TempStack = AverageStack0_Chopped[p][q+CurrentPlane*nY_per_Plane][r]
//	AverageStack0_Chopped_byPlane[][][pp*nF_SubStacks,(pp+1)*nF_SubStacks-1]=TempStack[p][q][r-pp*nF_SubStacks]
//	for (ss=0;ss<nSubStacks;ss+=1)
//		SubStart = TriggerTimes_Frame[ss*AverageStack_Chopup] - TriggerTimes_Frame[0] 
//		make /o/n=(nX,nY_per_plane,nF_SubStacks) TempStack2 = TempStack[p+ss*nX][q][r]
//		AverageStack0_DoubleChopped[][][pp*nF_SubStacks*nSubStacks+ss*nF_SubStacks,pp*nF_SubStacks*nSubStacks+(ss+1)*nF_SubStacks-1]=TempStack2[p][q][r-(pp*nF_SubStacks*nSubStacks+ss*nF_SubStacks)]
//	endfor
//	killwaves TempStack2
//endfor

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

variable/G gEndlessLoop = 1 
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
