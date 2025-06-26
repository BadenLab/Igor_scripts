#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_ROIPicker()

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

// flags from "OS_Parameters"
variable X_cut = OS_Parameters[%LightArtifact_cut]
variable LineDuration = OS_Parameters[%LineDuration]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
variable/G gFramerate = 1/(nY * LineDuration) // Hz 
variable Total_time = (nF * nX ) * LineDuration
print "Recorded ", total_time, "s @", gframerate, "Hz"
variable xx,yy,ff // initialise counters

make /o/n=(nX,nY) ROIs = 1 // empty ROI wave

// make RoiPicker_image
wave Stack_Ave
duplicate /o Stack_Ave RoiPicker_image
//if (waveexists($"RoiPicker_image")==0)
//	make /o/n=(nX,nY) RoiPicker_image = 0 // Sd projection of InputData
//	make /o/n=(nF) currentwave = 0
//	for (xx=X_cut;xx<nX;xx+=1)
//		for (yy=0;yy<nY;yy+=1)
//			Multithread currentwave[]=InputData[xx][yy][p] // get trace from "reference pixel"
//			Wavestats/Q currentwave
//			RoiPicker_image[xx][yy]=V_Avg
//		endfor
//	endfor
//endif



// Setup Basic waves needed
make /o/n=(1000,2) ROISeeds = NaN
make /o/n=(1000) ActiveROIMarker = 0
make /o/n=(nF) CurrentROITrace = 1

variable/G gDeletionDistance = 10
variable/G gFloodSmooth = 5
variable/G nROIs = 0
variable/G gActiveROI = NaN
variable/G gnFlood_iterations = 10000
variable/G gFloodtolerance_seed = 0.05
variable/G gFloodtolerance = 0.05
variable/G gWheelSensitivity = 10
variable/G gMaxRadius = 20
	
duplicate/o RoiPicker_image RoiPicker_image_smth
Smooth/Dim=0 gFloodSmooth,RoiPicker_image_smth
Smooth/Dim=1 gFloodSmooth,RoiPicker_image_smth
//Differentiate RoiPicker_image_smth
	
// display RoiPicker_image
Display /N=ROIPicker /k=1

Appendimage /l=AnatomyY /b=AnatomyX RoiPicker_image_smth
Appendimage /l=AnatomyY /b=AnatomyX ROIs
Appendtograph /l=AnatomyY /b=AnatomyX ROISeeds[][1] vs ROISeeds[][0]
Appendtograph /l=FunctionY /b=FunctionX CurrentROITrace

ModifyGraph fSize=8,lblPos=47,freePos={0,kwFraction}
ModifyGraph noLabel=2,axThick=0
ModifyGraph mode=3,marker=19,msize=2
ModifyGraph zmrkSize(ROISeeds)=0,zColor(ROISeeds)={ActiveROIMarker,0,1,BlackBody,1}
ModifyGraph axisEnab(AnatomyY)={0.2,1},axisEnab(FunctionY)={0,0.15}
ModifyGraph mode(CurrentROITrace)=0,rgb(CurrentROITrace)=(0,0,0)

String iName= WMTopImageGraph()		// find one top image in the top graph window
Wave w= $WMGetImageWave(iName)	// get the wave associated with the top image.
String/G imageName=nameOfWave(w)

DoUpdate
GetWindow kwTopWin,gsize
ControlBar /L 100 // how much space of the window is dedicated to controls
GetWindow kwTopWin,gsize

////
Button ApplyPress,pos={10,20},size={80,20},proc=RP_Buttons,title="Apply"

Button SmoothUp,pos={10,50},size={80,20},proc=RP_Buttons,title="Up-Smth"
Button SmoothDown,pos={10,80},size={80,20},proc=RP_Buttons,title="Down-Smth"

Button MakeBackUp,pos={10,110},size={80,20},proc=RP_Buttons,title="Make Backup"
Button LoadBackUp,pos={10,140},size={80,20},proc=RP_Buttons,title="Load Backup"

Button FlipContrast,pos={10,170},size={80,20},proc=RP_Buttons,title="Flip Contrast"

string cmd
SetVariable TolVal,pos={10,200},size={90,14}, title="Tol"//,disable=2
sprintf cmd,"SetVariable TolVal,value=%s",GetDataFolder(1)+"gFloodtolerance"
Execute cmd

//activate hook function below
SetWindow ROIPicker,hook(s)=RP_Hook   

// cleanup


end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function RP_Hook(s)
    STRUCT WMWinHookStruct &s

   
   	
   
    // create reference to required waves
    //wave InputData_RGB
    //NVAR gCurrentLayer
    NVAR gDeletionDistance
    NVAR nROIs
    NVAR gActiveROI 
    NVAR gFloodtolerance
    NVAR gFloodtolerance_seed
    NVAR gWheelSensitivity
    
    wave RoiPicker_image
    wave RoiPicker_image_smth
    wave ROISeeds
    wave ActiveROIMarker
    wave ROIs
   	
   	variable nROIs_Max = Dimsize(ROISeeds,0)
   	variable rr,pp
   	
   	variable kill = 0
   
    // where is the mouse?
    variable xpos =  AxisValFromPixel("", "Bottom", s.mouseLoc.h)
    variable ypos = AxisValFromPixel("", "Left", s.mouseLoc.v) 
    variable xx = round (xpos / DimDelta(RoiPicker_image, 0))
    variable yy =  round (ypos / DimDelta(RoiPicker_image, 0))
    variable maxX = DimSize(RoiPicker_image, 0)
    variable maxY = DimSize(RoiPicker_image, 1)
      
    switch(s.eventCode)   

		case 22: // mouse wheel
			
			variable WheelDir = s.wheelDy/3 // like this goes -1 or 1
			gFloodtolerance*=(100+WheelDir*gWheelSensitivity)/100
			
			ROIs[][]=(ROIs[p][q]==-(gActiveROI+1))?(1):(ROIs[p][q])			
			RP_floodfill(ROISeeds[gActiveROI][0],ROISeeds[gActiveROI][1])
			break
		
			
			
		case 4:     // Mouse is moved
			//
			break
       
        case 3:     // handle left mouse click         
            // prevent error when clicking outside of image
            if (xx >= maxX || yy >= maxY || xx < 0  || yy < 0)
                break
            endif
            
            // reset flood tolerance
            gFloodtolerance=gFloodtolerance_seed
            
            // First check if there is already a nearby cell in XY
            for (rr=0;rr<nROIs_Max;rr+=1)
           		if (NumType(ROISeeds[rr][0])==0) // if already exists
  	         		variable CurrentDistance = sqrt((xx-ROISeeds[rr][0])^2+(yy-ROISeeds[rr][1])^2)
    	       		if (CurrentDistance<gDeletionDistance)
    	      			ROISeeds[rr][]=NaN // kill the ROI seed
    	      			ROIs[][]=(ROIs[p][q]==-(rr+1))?(1):(ROIs[p][q]) // kill the ROI fill
    	      			for (pp=0;pp<2;pp+=1) // Zap NaNs
    	      				make /o/n=(nROIs_max) tempwave = ROISeeds[p][pp]
    	      				WaveTransform zapnans tempwave
      	      				ROISeeds[0,Dimsize(tempwave,0)-1][pp]=tempwave[p]
    	      				ROISeeds[Dimsize(tempwave,0)][pp]=NaN
    	      			endfor
    	      			
    	      			// Re-compute the ROI mask
    	      			duplicate /o ROIs ROIS_temp
    	      			variable killedROI = -(rr+1)
    	      			ROIs[][]=(ROIS_temp[p][q]<killedROI)?(ROIs_temp[p][q]+1):(ROIs_temp[p][q])
    	      			
    	      			
    	      			
    	      			killwaves ROIs_temp
    	      			
    	      			
    	      			
    	      			ActiveROIMarker = 0
						kill = 1
						
           			endif
           		endif
           	endfor
           	
           	/// If still here (no break triggered above), add a new cell
           	for (rr=0;rr<nROIs_max;rr+=1)
            	if (NumType(ROISeeds[rr][0])==0) // if already exists
            	elseif (kill==0)
             	ROISeeds[rr][0]=xx
      				ROISeeds[rr][1]=yy
      				gActiveROI = rr
      				ActiveROIMarker = 0
      				ActiveROIMarker[rr]=1
      			      				
      				// run flood filler
      				RP_floodfill(xx,yy)
      				
            				
      				
					break
				endif
			endfor
			
			/// Get new count of cells across types
			make /o/n=(nROIs_Max) tempwave = ROISeeds[p][0]
			tempwave[]=(NumType(ROISeeds[p][0])==0)?(1):(0)
			WaveStats/Q tempwave
			nROIs=V_Sum
			print "nROIs:", nROIs
			
			// Repaint all the ROIs
			make /o/n=(1) M_Colors
			Colortab2Wave Rainbow256
			for (rr=0;rr<nRois;rr+=1)
				variable colorposition = 255 * (rr+1)/nRois
				ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
			endfor
            

			
		
       	break
           	      
    endswitch
    
    
    switch (s.keycode)
    	case 99: // c key
    		
    		RP_floodfill_grow()
    		    		
    		break
    
    
    endswitch
   
    return 1
End

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function RP_floodfill(xx_seed,yy_seed)
variable xx_seed,yy_seed

NVAR gFloodtolerance
NVAR gnFlood_iterations
NVAR gActiveROI
NVAR gMaxRadius

wave RoiPicker_image_smth
wave ROIs
wave CurrentROITrace
wave InputData

if (waveexists($"InputData")==1) // gets killed when using other OS functions, so recovers it here if needed
	wave InputData
else
	string input_name = "wDataCh0_detrended"
	duplicate /o $input_name InputData
endif


variable rr,ff
variable SeedBrightness = RoiPicker_image_smth[xx_seed][yy_seed]
variable CurrentX = xx_seed
variable CurrentY = yy_seed

variable nX = Dimsize(InputData,0)
variable nY = Dimsize(InputData,1)
variable nF = Dimsize(InputData,2)
variable xx,yy

ROIs[xx][yy]=-(gActiveROI+1)


for (ff=0;ff<gnFlood_iterations;ff+=1)
	variable RandomStepX = Round(Enoise(1.33))
	variable RandomStepY = Round(Enoise(1.33))
	
	CurrentX+=RandomStepX
	CurrentY+=RandomStepY
	variable CurrentRadius = sqrt((xx_seed-CurrentX)^2+(yy_seed-CurrentY)^2)
	
	if (CurrentRadius<gMaxRadius)
		variable NewBrightness = RoiPicker_image_smth[CurrentX][CurrentY]
		
		if (NewBrightness>SeedBrightness*(1+gFloodtolerance) && ROIs[CurrentX][CurrentY] > 0) // >0 means it's 1 (nothing) or 2 (current)
			
					
			ROIs[CurrentX][CurrentY]=2
		else
			CurrentX-=RandomStepX // go back to previous
			CurrentY-=RandomStepY	
		endif
	endif
endfor

ROIs[][]=(ROIs[p][q]==2)?(-(gActiveROI+1)):(ROIs[p][q]) // apply the ROI

// Grab that current trace
CurrentROITrace=0
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		if (ROIs[xx][yy]==-(gActiveROI+1))
			CurrentROITrace+=InputData[xx][yy][p]
		endif
	endfor
endfor

end

 
//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
/////////////////////////////////////////////////////////////////////////////


function RP_floodfill_grow()
NVAR gActiveROI

wave ROIs
duplicate /o ROIs ROIs_temp
ROIs_temp[][]=(ROIs[p][q]==-(gActiveROI+1))?(1):(0)
ROIs[][]=(ROIs_temp[p][q]==1)?(2):(ROIs[p][q])
Smooth/DIM=0 1, ROIs_temp
Smooth/DIM=1 1, ROIs_temp
ROIs[][]=(ROIs_temp[p][q]>0 && ROIs[p][q]>0.5)?(-(gActiveROI+1)):(ROIs[p][q])
killwaves ROIs_temp

// Grab that current trace
wave InputData
wave CurrentROITrace
variable nX = Dimsize(InputData,0)
variable nY = Dimsize(InputData,1)
variable nF = Dimsize(InputData,2)
variable xx,yy
CurrentROITrace=0
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		if (ROIs[xx][yy]==-(gActiveROI+1))
			CurrentROITrace+=InputData[xx][yy][p]
		endif
	endfor
endfor


end
  
 
//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////    				
      				

Function RP_Buttons(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (ba.ctrlName)
				case "ApplyPress":
					print "Maving movie..."
					RP_Apply()
					
					break
					
				case "SmoothUP":
					RP_Smooth(1.2)
					break
					
				case "SmoothDown":
					RP_Smooth(0.8)
					break
					
				case "MakeBackup":
					RP_Backup(1)
					break

				case "LoadBackup":
					RP_Backup(0)
					break
					
				case "FlipContrast":
					RP_FlipContrast()
					break

				endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function RP_FlipContrast()

	wave RoiPicker_image
	RoiPicker_image*=-1
	wave RoiPicker_image_smth
	RoiPicker_image_smth*=-1
end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function RP_Smooth(upOrDown)
variable UpOrDown

wave RoiPicker_image
duplicate/o RoiPicker_image RoiPicker_image_smth

NVAR gFloodSmooth
gFloodSmooth*=upOrDown

if (gFloodSmooth<1)
	gFloodsmooth=1
endif

if (gFloodSmooth>1)
	Smooth/Dim=0 gFloodSmooth,RoiPicker_image_smth
	Smooth/Dim=1 gFloodSmooth,RoiPicker_image_smth
endif
print "Smoothing:", gFloodsmooth

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function RP_Backup(commandVar) // 0 Load, 1 Make, -1 Kill
variable commandVar

wave ROIs
wave ROISeeds

if (commandVar==1) // make
	if (waveexists($"ROIs_RPBackup")==1)
		print "backup already exists, delete it first!"
		print "- ROIs_RPBackup"
		print "- ROISeeds_RPBackup"
	else
		duplicate /o ROIs ROIs_RPBackup
		duplicate /o ROISeeds ROISeeds_RPBackup
		print "ROIs backed up"
	endif
	
elseif (commandVar==0) // load
	if (waveexists($"ROIs_RPBackup")==1 && waveexists($"ROISeeds_RPBackup")==1)
		duplicate /o ROIs_RPBackup ROIs
		duplicate /o ROISeeds_RPBackup ROISeeds
		print "backup restored"
	endif
endif

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////


function RP_Apply()

variable save_stuff = 0
variable decaytau = 5 // higher = slower
variable SD_Min = 4
variable SpikeROISmooth = 10 // space

OS_TracesandTriggers() // get the traces
OS_EventFinder() // get the events
if (waveexists($"InputData")==1) // gets killed when using other OS functions, so recovers it here if needed
	wave InputData
else
	string input_name = "wDataCh0_detrended"
	duplicate /o $input_name InputData
endif

variable nX = Dimsize(InputData,0)
variable nY = Dimsize(InputData,1)
variable nF = Dimsize(InputData,2)
wave Traces0_znorm
wave ROIs
wave ROIPicker_image
NVAR nROIs
variable rr,xx,yy

// make decay function
make /o/n=(100) decay = e^(-(1/decaytau) * x)
make /o/n=(nF) tempwave = NaN

duplicate /o Traces0_znorm Traces0_znorm_convolved
for (rr=0;rr<nROIs;rr+=1)
	Multithread tempwave = traces0_znorm[p][rr]
	Convolve/A decay, tempwave
	Multithread Traces0_znorm_convolved[][rr]=tempwave[p]
endfor	

// make the movie
make /o/n=(nX,nY,nF) OutputMovie_spikes = 0
make /o/n=(nX,nY,nF) OutputMovie_anatomy = ROIPicker_image[p][q]

for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		if (ROIs[xx][yy]<1) // if there is something
			variable CurrentROI = (ROIs[xx][yy]*-1)-1
			OutputMovie_spikes[xx][yy][]=Traces0_znorm_convolved[r-50][CurrentROI]
		endif
	endfor
endfor

// smooth and kick out negatives
Smooth/Dim=0 SpikeROISmooth, OutputMovie_spikes
Smooth/Dim=1 SpikeROISmooth, OutputMovie_spikes
Multithread OutputMovie_spikes[][][]=(OutputMovie_spikes[p][q][r]<SD_Min)?(NaN):(OutputMovie_spikes[p][q][r])


// save the movie
if (save_stuff==1)
	imagesave /s/f/t="tiff" OutputMovie_spikes
	imagesave /s/f/t="tiff" OutputMovie_anatomy
endif

RP_MovieWindow()

killwaves Traces0_znorm_convolved, tempwave

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function RP_MovieWindow()

variable /G gCurrentTimePoint = 0

NVAR gFramerate

variable nTraces = 8
variable SD_Max = 30 // brightness of spike movie
variable/G gDisplayTime = 5 // s
variable RandomPicker = 0.1

wave Traces0_znorm
wave ROIPicker_image
wave OutputMovie_spikes

variable nX = Dimsize(OutputMovie_spikes,0)
variable nY = Dimsize(OutputMovie_spikes,1)
variable nF = Dimsize(OutputMovie_spikes,2)
variable nROIs = Dimsize(Traces0_znorm,1)


variable rr,tt,pp

// Grab event times if they exist // get that by runing the events script
if (waveexists($"PeakTimes0")==1)
	wave PeakTimes0
else // else make up an empty one
	make /o/n=(1000,nROIs) PeakTimes0 = NaN
endif
duplicate /o PeakTimes0 RasterPLot
RasterPLot[][]=(NumType(PeakTimes0[p][q])==0)?(1):(NaN)

make /o/n=(nF) SpikeJustNow = 0
for (rr=0;rr<nROIs;rr+=1)
	for (pp=0;pp<Dimsize(RasterPLot,0);pp+=1)
		if (RasterPLot[pp][rr]==1)
			variable CurrentTimePoint = PeakTimes0[pp][rr]*gFrameRate
			SpikeJustNow[CurrentTimePoint]+=1
		endif
	endfor
	


endfor


// make a display version of the spikes movie
make /o/n=(nX,nY) CurrentSpikeImage = OutputMovie_spikes[p][q][gCurrentTimePoint]

///

// make a transparency-enabled colour lookup map

variable nColourentries = 256
make /o/n=(nColourentries,4) Red_transparent = 0
Red_transparent[][0]=2^16-1 // red channel to full power
Red_transparent[][3]=(x/nColourentries)*2^16-1 // transparency channel is modulated


// pick some traces

make /o/n=(nROIs) PeakAmplitudes = NaN
for (rr=0;rr<nROIs;rr+=1)
	make /o/n=(nF) tempwave = Traces0_znorm[p][rr]
	PeakAmplitudes[rr]=WaveMax(tempwave)
endfor
killwaves tempwave
make /o/n=(nROIs) ROIRanking = x
if (randompicker>0)
	PeakAmplitudes*=Enoise(RandomPicker) // mix the order up a tad
endif
Sort/R PeakAmplitudes, ROIRanking
killwaves PeakAmplitudes

make /o/n=(nTraces) DisplayROIs = ROIRanking[p]//round(Enoise(nROIs/2))+nROIs/2
make /o/n=(nF) zeromarker = 0
zeromarker[gCurrentTimePoint]=1
setscale/p x,0,1/gFramerate,"s" Traces0_znorm, zeromarker

display /N=MovieViewer /k=1

ControlBar /T 40 // how much space of the window is dedicated to controls
GetWindow kwTopWin,gsize

Button PlayMovie,pos={1100,10},size={80,20},proc=RP_MovieButtons,title="Play"

Slider TimeAxis,pos={20,15},size={1000,20},proc=RP_TimeSlider
Slider TimeAxis,limits={0,nF-1,1},value= 0,vert= 0,ticks=1,side=0,variable=gCurrentTimePoint	

Appendimage /l=imageY /b=imageX ROIPicker_image
Appendimage /l=imageY /b=imageX CurrentSpikeImage
ModifyImage CurrentSpikeImage ctab= {0,SD_Max,Red_transparent,0}

ModifyGraph width=1500,height=400
DoUpdate
ModifyGraph width=0,height=0

// traces
Appendtograph /l=ZeroMarkerY /b=TracesX ZeroMarker 
for (tt=0;tt<nTraces;tt+=1)
	variable startplot = tt*(1/nTraces)
	variable endplot = Startplot+1/nTraces-0.02
	string CurrentYAxis = "TraceY"+Num2Str(tt)
	Appendtograph /l=$CurrentYAxis /b=TracesX Traces0_znorm[][DisplayROIs[tt]] 
	ModifyGraph axisEnab($CurrentYAxis)={startplot,endplot}
endfor
ModifyGraph mode(zeromarker)=6

// rasterplot
Appendtograph /l=ZeroMarkerY /b=RasterX ZeroMarker 
for (rr=0;rr<nROIs;rr+=1)
	variable YOffset = rr
	string tracename = "RasterPlot#"+Num2Str(rr)
	if (rr==0)
		tracename = "RasterPlot"
	endif
	Appendtograph /l=RasterY /b=RasterX RasterPLot[][rr] vs PeakTimes0[][rr]
	ModifyGraph mode($tracename)=3,marker($tracename)=19,msize($tracename)=1.5
	ModifyGraph offset($tracename)={0,rr}
endfor
ModifyGraph mode(zeromarker#1)=6

ModifyGraph fSize=8,noLabel=2,axThick=0,lblPos=47,freePos={0,kwFraction}
ModifyGraph axisEnab(imageX)={0,0.4},axisEnab(RasterX)={0.45,0.7},axisEnab(TracesX)={0.75,1}
SetAxis TracesX gCurrentTimePoint/gFramerate-gDisplayTime/3,gCurrentTimePoint/gFramerate+2*(gDisplayTime/3)
SetAxis RasterX gCurrentTimePoint/gFramerate-gDisplayTime/3,gCurrentTimePoint/gFramerate+2*(gDisplayTime/3)
ModifyGraph rgb=(0,0,0)

ModifyGraph noLabel(imageX)=1,noLabel(TracesX)=1,noLabel(RasterX)=1,lblPos(imageX)=30,lblPos(TracesX)=30,lblPos(RasterX)=30;DelayUpdate
Label imageX "\\Z10Anatomy + Thresholded activity";DelayUpdate
Label TracesX "\\Z10Some randomly selected cells";DelayUpdate
Label RasterX "\\Z10All Cells"


end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function RP_TimeSlider(name, value, event)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved

	NVAR gCurrentTimePoint
	NVAR gFrameRate
	NVAR gDisplayTime

	wave OutputMovie_spikes
	wave CurrentSpikeImage
	wave Zeromarker
	
	Multithread CurrentSpikeIMage[][]=OutputMovie_spikes[p][q][gCurrentTimePoint]
	
	
	ZeroMarker[]=0
	ZeroMarker[gCurrentTimePoint]=1
	
	SetAxis TracesX gCurrentTimePoint/gFramerate-gDisplayTime/3,gCurrentTimePoint/gFramerate+2*(gDisplayTime/3)
	SetAxis RasterX gCurrentTimePoint/gFramerate-gDisplayTime/3,gCurrentTimePoint/gFramerate+2*(gDisplayTime/3)
	
	return 0				// other return values reserved
end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////    				
      				
Function RP_MoviePlay()


NVAR gCurrentTimePoint
NVAR gFrameRate
NVAR gDisplayTime

wave OutputMovie_spikes
wave CurrentSpikeImage
wave Zeromarker
wave SpikeJustNow
variable nF = Dimsize(OutputMovie_spikes,2)

// make a click
Make/B/O/N=2 ClickSound = 0	// 8 bit samples
ClickSound[1]=1
SetScale/P x,0,1e-4,ClickSound	
duplicate ClickSound ClickSoundScaled

variable ff
//gCurrentTimePoint = 0
for (ff=0;ff<nF;ff+=1)
	gCurrentTimePoint+=1
	Multithread CurrentSpikeIMage[][]=OutputMovie_spikes[p][q][gCurrentTimePoint]
	ZeroMarker[]=0
	ZeroMarker[gCurrentTimePoint]=1
	SetAxis TracesX gCurrentTimePoint/gFramerate-gDisplayTime/3,gCurrentTimePoint/gFramerate+2*(gDisplayTime/3)
	SetAxis RasterX gCurrentTimePoint/gFramerate-gDisplayTime/3,gCurrentTimePoint/gFramerate+2*(gDisplayTime/3)
	
	
	
	ClickSoundScaled = ClickSound*SpikeJustNow[ff] * 50
	PlaySound ClickSoundScaled

	
	DoUpdate
endfor



end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////  


Function RP_MovieButtons(ba2) : ButtonControl
	STRUCT WMButtonAction &ba2

	switch( ba2.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (ba2.ctrlName)
				case "PlayMovie":
					
					RP_MoviePlay()
					break
					


				endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End