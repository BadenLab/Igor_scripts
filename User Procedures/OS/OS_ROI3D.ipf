#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later



function OS_ROI3D()

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
variable nPlanes = OS_Parameters[%nPlanes]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
variable nY_orig = nY/nPlanes
variable yySeed = floor(nY_orig/2)
variable zzSeed = floor(nPlanes/2)
variable xxSeed = floor(nX/2)

variable Framerate = 1/(nY * LineDuration) // Hz 
variable Total_time = (nF * nX ) * LineDuration
print "Recorded ", total_time, "s @", framerate, "Hz"
variable xx,yy,ff,pp,rr // initialise counters

Colortab2Wave Rainbow256
wave M_Colors

// Open globals

variable/G gDeletionDistanceXY = 5
variable/G gDeletionDistanceZ = 2
variable/G gnROIs = 0
variable/G gnROIs_Max = 1000

variable/G gFirstplane = 0

variable/G gCurrentZ = zzSeed
variable/G gPlaneshuffle = 0
variable/G gCurrentF = 0
variable/G gActiveROI = Nan
variable/G gImageSource = 0

variable/G gMarkerSize_Min = 1
variable/G gMarkerSize_Max = 5
variable/G gMarkerSize_XYRange = 5
variable/G gMarkerSize_ZRange = 2

variable/G gROIMode = 0 // 0 = Spheres, 1 = Floodfill...
variable/G gROISeedMute = 0

variable/G gROI_SphereXY = 5
variable/G gROI_SphereZ = 2
variable/G gSphereInflationXY = 1
variable/G gSphereInflationZ = 1
variable/G gInflationSpeed = 0.5
variable/G gMaskThreshold = 0.05 // 0:1
variable/G gnClusterROIs_Max = 20
variable/G gVarExplained_Target = 99 // 0:100

variable/G gClusterSpacePullXY = 1
variable/G gClusterSpacePullZ = 1
variable/G gClusterSpaceWeightPC = 50 // 50 = 50% Space 50% Trace...
variable/G gClusterSpaceSmoothXY = 1
variable/G gClusterSpaceSmoothZ = 1

variable/G gFloodType = 0 // 0 is anatomy, 1 is function

variable/G gSmoothXY = 0
variable/G gSmoothZ = 0

variable/G gROIAlpha_scale = 0.5

variable/G gMouseX
variable/G gMouseY

variable/G gDynamicToleranceFactor = 0.2 // higher is more tolerant
variable/G gFloodtolerance_seed = 0.05
variable/G gFloodtolerance = gFloodtolerance_seed
variable/G gMaxRadiusXY = 50
variable/G gMaxRadiusZ = 5
variable/G gnFlood_iterations = 10000


// make functional Arrays

make /o/n=(gnROIs_Max,3) ROISeeds = NaN
make /o/n=(gnROIs_Max,3) ROISeeds_MarkerSize = NaN

// make Ave average
if (waveexists($"Stack_Ave")==0)
	make /o/n=(nX,nY) Stack_Ave = NaN // Sd projection of InputData
	make /o/n=(nF) currentwave = 0
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			Multithread currentwave[]=InputData[xx][yy][p] // get trace from "reference pixel"
			Wavestats/Q currentwave
			Stack_Ave[xx][yy]=V_Avg
		endfor
	endfor
else
	wave Stack_Ave
endif

// make a 4D version of wData0_detrended
// make 3D versions of Stack_Ave and Correlation_projection
//

make /o/n=(nX,nY_orig,nPlanes,nF) Data4D = NaN
make /o/n=(nX,nY_orig,nPlanes) Data3D = NaN
make /o/n=(nX,nY_orig,nPlanes) DataCorr3D = NaN
make /o/n=(nX,nY_orig,nPlanes) DataQCProj3D = NaN
make /o/n=(nX,nY_orig,nPlanes) ReferenceStack = NaN
make /o/n=(nX,nY_orig,nPlanes) ROIs3D = 1
for (pp=0;pp<nPlanes;pp+=1)

	Multithread Data4D[][][pp][]=InputData[p][q+nY_orig*pp][s]
	Multithread Data3D[][][pp]=Stack_Ave[p][q+nY_orig*pp]
	if (waveexists($"Correlation_projection")==1)
		wave Correlation_projection
		Multithread DataCorr3D[][][pp]=Correlation_projection[p][q+nY_orig*pp]
	else
		DataCorr3D = 0 // just make a dummy wave if it doesnt exist
	endif
	if (waveexists($"QC_projection")==1)
		wave QC_projection
		Multithread DataQCProj3D[][][pp]=QC_projection[p][q+nY_orig*pp]
	else
		DataQCProj3D = 0 // just make a dummy wave if it doesnt exist
	endif
endfor
ReferenceStack[][][]=Data3D[p][q][r] // default is to show the average

if (waveexists($"ROIs")==1)
	wave ROIs
	Imagestats/Q ROIs
	if (V_Min<0) // is there anything in it?
		print "importing existing ROIs..."
		gnROIs = -V_Min
		OS_CoM()
		wave CoM
		for (pp=0;pp<nPlanes;pp+=1)	
			Multithread ROIs3D[][][pp]=ROIs[p][q+nY_orig*pp]
		endfor
	else
		ROIs = 1 // just make an empty wave if not
	endif
endif

if (waveexists($"Correlation_projection")==0)
	print "Correlation_projection does not exist - create one if want that option"
endif

// make and update the  versions
//duplicate /o ROIs3D ROIs3D_Gizmo
//ROIs3D_Gizmo[][][]=(ROIs3D[p][q][r]<0)?(1):(NaN) // all ROIs are 1
//if (NumType(gActiveROI)==0)
//	ROIs3D_Gizmo[][][]=(ROIs3D[p][q][r]==-gActiveROI-1)?(2):(ROIs3D_Gizmo[p][q][r]) // active ROI is 2
//endif
// make GIZMO Scatter version
make /o/n=(nX*nY_orig*nPlanes,3) ROIs3D_GizmoCoordinates = NaN
make /o/n=(nX*nY_orig*nPlanes,4) ROIs3D_GizmoColours = NaN
variable NextPixel = 2
ROIs3D_GizmoCoordinates[0][]=0
ROIs3D_GizmoCoordinates[1][0]=nX
ROIs3D_GizmoCoordinates[1][1]=nY_orig
ROIs3D_GizmoCoordinates[1][2]=nPLanes


if (gNROIs>0)
	for (xx=0;xx<nX;xx+=1)
		for (yy=0;yy<nY_orig;yy+=1)
			for (pp=0;pp<nPlanes;pp+=1)
				if (ROIs3D[xx][yy][pp]<0)
					variable CurrentROI = -ROIs3D[xx][yy][pp]-1
					variable colorposition = 255 * (CurrentROI+1)/gnRois
					
					ROIs3D_GizmoCoordinates[NextPixel][0]=xx
					ROIs3D_GizmoCoordinates[NextPixel][1]=yy
					ROIs3D_GizmoCoordinates[NextPixel][2]=pp
					
					ROIs3D_GizmoColours[NextPixel][0,2]=M_Colors[colorposition][q]/2^16 // need to be 0:1, for stupid reasons
					ROIs3D_GizmoColours[NextPixel][3]=gROIAlpha_scale
					
					NextPixel+=1
				endif
			endfor
		endfor
	endfor
endif
/////////



if (gNROIs>0) // if there is a ROI wave that is to be imported, generate the seeds for it
	for (rr=0;rr<gnROIs;rr+=1)
		variable XSeed = CoM[rr][0]
		variable YSeed = CoM[rr][1]
		variable ZSeed = 0

		for (pp=0;pp<nPlanes;pp+=1)
			if (YSeed>nY_Orig-1)
				YSeed-=nY_Orig
				ZSeed+=1
			endif
		endfor
		ROISeeds[rr][0]=XSeed
		ROISeeds[rr][1]=YSeed
		ROISeeds[rr][2]=ZSeed
	endfor	
endif	

// make display arrays; by default, they show the 3D data 
make /o/n=(gnROIs_Max) ColourMarker = 0

make /o/n=(nX,nY_orig) XYImage = ReferenceStack[p][q][zzSeed]
make /o/n=(nX,nPlanes) XZImage = ReferenceStack[p][yySeed][q]
make /o/n=(nPlanes,nY_orig) YZImage = ReferenceStack[xxSeed][q][p]

make /o/n=(nX,nY_orig) XYROIImage = ROIs3D[p][q][zzSeed]
make /o/n=(nX,nPlanes) XZROIImage = ROIs3D[p][yySeed][q]
make /o/n=(nPlanes,nY_orig) YZROIImage = ROIs3D[xxSeed][q][p]

make /o/n=(nF) DisplayTrace = NaN
make /o/n=(nF) TimePointMarker = NaN

make /o/n=(5,2) XYCross = NaN
XYCross[0][0]=0
XYCross[0][1]=yySeed
XYCross[1][0]=nX-1
XYCross[1][1]=yySeed
XYCross[3][0]=xxSeed
XYCross[3][1]=0
XYCross[4][0]=xxSeed
XYCross[4][1]=nY_orig-1

make /o/n=(5,2) XZCross = NaN
XZCross[0][0]=0
XZCross[0][1]=zzSeed
XZCross[1][0]=nX-1
XZCross[1][1]=zzSeed
XZCross[3][0]=xxSeed
XZCross[3][1]=0
XZCross[4][0]=xxSeed
XZCross[4][1]=nPLanes-1

make /o/n=(5,2) YZCross = NaN
YZCross[0][0]=0
YZCross[0][1]=yySeed
YZCross[1][0]=nPlanes-1
YZCross[1][1]=yySeed
YZCross[3][0]=zzSeed
YZCross[3][1]=0
YZCross[4][0]=zzSeed
YZCross[4][1]=nY_orig-1

if (nPlanes<2)
	XZCross = NaN
	YZCross = NaN
	XZImage = NaN
	YZImage = NaN
	XZROIImage = NaN
	YZROIImage = NaN
endif


// SET up the GIZMO
//NEWGizmo /k=1 /n=RoiPickerGizmo
//
//AppendtoGizmo defaultVoxelGram=ROIs3D_Gizmo
//ModifyGizmo ModifyObject=voxelgram0,objectType=voxelgram,property={ valueUsed,0,1}
//ModifyGizmo ModifyObject=voxelgram0,objectType=voxelgram,property={ valueRGBA,0,1,0.866667,0.866667,0.866667,1.000000}
//ModifyGizmo ModifyObject=voxelgram0,objectType=voxelgram,property={ valueUsed,1,1}
//ModifyGizmo ModifyObject=voxelgram0,objectType=voxelgram,property={ valueRGBA,1,2,1.000000,0.000000,0.000000,1.000000}
//ModifyGizmo ModifyObject=voxelgram0,objectType=voxelgram ,property={mode, 0 } // makes sure it's dots not boxes
//ModifyGizmo ModifyObject=voxelgram0,objectType=voxelgram,property={ tolerance,0.1} // toleance shouldnt be 0
//ModifyGizmo showInfo
//ModifyGizmo zoomMode=1

NEWGizmo /k=1 /n=RoiPickerGizmo
ModifyGizmo zoomMode=1
AppendToGizmo DefaultScatter=ROIs3D_GizmoCoordinates
ModifyGizmo ModifyObject=axes0,objectType=Axes,property={ -1,ticks,0}
ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ Shape,1}
ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ scatterColorType,1}
ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ colorWave,ROIs3D_GizmoColours}
ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ Shape,2}
ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ size,0.1}

// open the interactive panel
variable TopWidth = 50
string cmd

display /k=1 /N=ROIPicker3D 
ControlBar /L 100
ControlBar /T TopWidth
ModifyGraph width=500,height=300

// ROI control
string helpstring = "This will kill all the ROIs\rCannot be undone!"
Button ROIKill,pos={10,-40+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Kill ROIs", help={helpstring}

helpstring = "This switches ROI seeds On/Off\r(to adjust the visibility of ROIs, use alpha below)"
Button ROISeedToggle,pos={10,-10+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Toggle Seeds" , help={helpstring} 
SetVariable AlphaVal,pos={10,20+TopWidth},size={80,14}, title="Alpha"//,disable=2
sprintf cmd,"SetVariable AlphaVal,value=%s",GetDataFolder(1)+"gROIAlpha_scale"
Execute cmd

helpstring = "Shuffles the top/bottom planes to the bottom/top of the stack, respectively"
Button PlaneShuffleUp,pos={10,70+TopWidth},size={35,20},proc=ROI3D_Buttons,title="Pl.+", help={helpstring}
Button PlaneShuffleDown,pos={50,70+TopWidth},size={35,20},proc=ROI3D_Buttons,title="Pl.-", help={helpstring}

helpstring = "Mean projection; can be smoothed with XY/Z buttons below..."
Button AvePress,pos={10,100+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Mean", help={helpstring}
helpstring = "Correlation projection; can be smoothed with XY/Z buttons below...\r(if blank, compute it first via the main panel)"
Button CorrPress,pos={10,130+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Corr.", help={helpstring}
helpstring = "QC projection; can be smoothed with XY/Z buttons below...\r(if blank, compute it first via the main panel)"
Button QCPress,pos={10,160+TopWidth},size={80,20},proc=ROI3D_Buttons,title="QC-Proj..", help={helpstring}
helpstring = "Seed mode - select a single pixel to compute its correlation in time\rto all other pixels; can be smoothed with XY/Z buttons below..."
Button SeedPress,pos={10,190+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Seed", help={helpstring} 

helpstring = "XY/Z smooth buttons for the above projection options"
Button XYSmoothUp,pos={10,240+TopWidth},size={35,20},proc=ROI3D_Buttons,title="XY+", help={helpstring}
Button XYSmoothDown,pos={50,240+TopWidth},size={35,20},proc=ROI3D_Buttons,title="XY-", help={helpstring}
Button ZSmoothUp,pos={10,270+TopWidth},size={35,20},proc=ROI3D_Buttons,title="Z+", help={helpstring}
Button ZSmoothDown,pos={50,270+TopWidth},size={35,20},proc=ROI3D_Buttons,title="Z-", help={helpstring}

helpstring = "Place a ROI-sphere and control its size with AWSD buttons"
Button SphereMode,pos={10,320+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Spheres", help={helpstring}
helpstring = "Place a ROI-sphere, control its size with AWSD buttons, and keep adding more spheres...\rfinish ROI by clicking this button again"
Button PaintMode,pos={10,350+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Paint", help={helpstring}

helpstring = "Place a ROI and floodfill based on displayed image brightness; control the fill with AWSD buttons"
Button FillModeAnatomy,pos={10,400+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Flood-Anat.", help={helpstring} 
helpstring = "Place a ROI and floodfill based temporal correlation to the seed pixel; control the fill with AWSD buttons"
Button FillModeFunction,pos={10,430+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Flood-Func.", help={helpstring} 

SetVariable TolVal,pos={10,460+TopWidth},size={80,14}, title="Tol"//,disable=2
sprintf cmd,"SetVariable TolVal,value=%s",GetDataFolder(1)+"gDynamicToleranceFactor"
Execute cmd

helpstring = "Combines paint mode and anatomical floodfill mode - controls as above"
Button FloodPaintMode,pos={10,490+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Flood-paint" , help={helpstring} 

helpstring = "places ROIs by clustering single pixel time traces - for control, see command prompt history"
Button ClusterMode,pos={10,540+TopWidth},size={80,20},proc=ROI3D_Buttons,title="Cluster mode", help={helpstring}  

SetVariable ThreshVal,pos={10,570+TopWidth},size={80,14}, title="Mask"//,disable=2
sprintf cmd,"SetVariable ThreshVal,value=%s",GetDataFolder(1)+"gMaskThreshold"
Execute cmd

SetVariable nClustVal,pos={10,600+TopWidth},size={80,14}, title="nCl."//,disable=2
sprintf cmd,"SetVariable nClustVal,value=%s",GetDataFolder(1)+"gnClusterROIs_Max"
Execute cmd

SetVariable ClusterSmoothXYVal,pos={10,630+TopWidth},size={80,14}, title="Sm-XY"//,disable=2
sprintf cmd,"SetVariable ClusterSmoothXYVal,value=%s",GetDataFolder(1)+"gClusterSpaceSmoothXY"
Execute cmd

SetVariable ClusterSmoothZVal,pos={10,660+TopWidth},size={80,14}, title="Sm-Z"//,disable=2
sprintf cmd,"SetVariable ClusterSmoothZVal,value=%s",GetDataFolder(1)+"gClusterSpaceSmoothZ"
Execute cmd

SetVariable ClusterPullXYVal,pos={10,690+TopWidth},size={80,14}, title="Sp-XY"//,disable=2
sprintf cmd,"SetVariable ClusterPullXYVal,value=%s",GetDataFolder(1)+"gClusterSpacePullXY"
Execute cmd

SetVariable ClusterPullZVal,pos={10,720+TopWidth},size={80,14}, title="Sp-Z"//,disable=2
sprintf cmd,"SetVariable ClusterPullZVal,value=%s",GetDataFolder(1)+"gClusterSpacePullZ"
Execute cmd

SetVariable ClusterSpaceW,pos={10,750+TopWidth},size={80,14}, title="SpaceW"//,disable=2
sprintf cmd,"SetVariable ClusterSpaceW,value=%s",GetDataFolder(1)+"gClusterSpaceWeightPC"
Execute cmd


Slider FrameAxis,pos={130,20},size={600,16},proc=ROI3D_ExecuteSlider
Slider FrameAxis,limits={0,nF-1,1},value= 0,vert=0,ticks=1,side=0,variable=gCurrentF	

// Append things

Appendimage /l=ImageY /b=ImageX XYImage
Appendimage /l=ImageZ /b=ImageX XZImage
Appendimage /l=ImageY /b=ImageZ2 YZImage


Appendimage /l=ImageY /b=ImageX XYROIImage
Appendimage /l=ImageZ /b=ImageX XZROIImage
Appendimage /l=ImageY /b=ImageZ2 YZROIImage

AppendtoGraph /l=ImageY /b=ImageX ROISeeds[][1] vs ROISeeds[][0]
AppendtoGraph /l=ImageZ /b=ImageX ROISeeds[][2] vs ROISeeds[][0]
AppendtoGraph /l=ImageY /b=ImageZ2 ROISeeds[][1] vs ROISeeds[][2]


Appendtograph /l=ImageY /b=ImageX XYCross[][1] vs XYCross[][0]
Appendtograph /l=ImageZ /b=ImageX XZCross[][1] vs XZCross[][0]
Appendtograph /l=ImageY /b=ImageZ2 YZCross[][1] vs YZCross[][0]

Appendtograph /l=TraceY /b=TraceX DisplayTrace
Appendtograph /l=Trace2Y /b=TraceX TimePointMarker

Appendimage /l=FullImageY /b=FullImageX Stack_Ave
Appendimage /l=FullImageY /b=FullImageX ROIs

ModifyGraph axisEnab(ImageY)={0.5,1},axisEnab(ImageX)={0,0.5},axisEnab(ImageZ)={0.25,0.45},axisEnab(ImageZ2)={0.55,0.75}
ModifyGraph axisEnab(FullImageX)={0.8,1}
ModifyGraph axisEnab(TraceY)={0,0.2}, axisEnab(TraceX)={0,0.75}
ModifyGraph axisEnab(Trace2Y)={0,0.2}

for (rr=0;rr<gnRois;rr+=1)
	colorposition = 255 * (rr+1)/gnRois
	ModifyImage XYROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
	ModifyImage XZROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
	ModifyImage YZROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
	ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
endfor

ModifyGraph fSize=8,noLabel=1,axThick=0,lblPos=30,freePos={0,kwFraction}

ModifyGraph mode(ROISeeds)=3,marker(ROISeeds)=8,mode(ROISeeds#1)=3,marker(ROISeeds#1)=8,mode(ROISeeds#2)=3,marker(ROISeeds#2)=8
ModifyGraph mrkThick(ROISeeds)=1.5,mrkThick(ROISeeds#1)=1.5,mrkThick(ROISeeds#2)=1.5
ModifyGraph zColor(ROISeeds)={ColourMarker,0,1,BlackBody,1}
ModifyGraph zColor(ROISeeds#1)={ColourMarker,0,1,BlackBody,1}
ModifyGraph zColor(ROISeeds#2)={ColourMarker,0,1,BlackBody,1}

ModifyGraph zmrkSize(ROISeeds)={ROISeeds_MarkerSize[*][2],0,5,0,5}
ModifyGraph zmrkSize(ROISeeds#1)={ROISeeds_MarkerSize[*][1],0,5,0,5}
ModifyGraph zmrkSize(ROISeeds#2)={ROISeeds_MarkerSize[*][0],0,5,0,5}

ModifyGraph rgb(DisplayTrace)=(0,0,0),mode(TimePointMarker)=3,marker(TimePointMarker)=10,msize(TimePointMarker)=10
ModifyGraph noLabel(TraceY)=2,noLabel(TraceX)=2,noLabel(Trace2Y)=2

DoUpdate
ModifyGraph width=0,height=0

// Hook function
SetWindow ROIPicker3D,hook(s)=ROI3DHook  



end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function ROI3DHook(rhook)
    STRUCT WMWinHookStruct &rhook
  
    // create reference to required waves
    wave ReferenceStack
    wave Data4D
    wave Data3D
    wave DataCorr3D
    wave DataQCProj3D
    wave ROIs3D
    wave ROIs
    wave XYImage
    wave XZImage
    wave YZImage
    
    wave XYROIImage
    wave XZROIImage
    wave YZROIImage

	NVAR gROIMode
    
    wave XYCross
    wave XZCross
    wave YZCross
    
    wave ROISeeds
    wave ROISeeds_MarkerSize
    
    wave M_Colors
    wave ColourMarker
    NVAR gROIAlpha_Scale
    
    NVAR gROI_SphereXY
    NVAR gROI_SphereZ
       
    NVAR gMarkerSize_Max
    NVAR gMarkerSize_Min
    NVAR gMarkerSize_XYRange
    NVAR gMarkerSize_ZRange
    
    NVAR gCurrentZ
    NVAR gCurrentF
    NVAR gDeletionDistanceXY
    NVAR gDeletionDistanceZ
    NVAR gnROIs
    NVAR gNROIs_Max
    NVAR gActiveROI 
    NVAR gROISeedMute
    
    NVAR gFloodtolerance
    NVAR gFloodtolerance_seed
    NVAR gDynamicToleranceFactor
    
    NVAR gFillMode
    
    NVAR gSphereInflationXY
    NVAR gSphereInflationZ
    
    NVAR gMouseX
    NVAR gMouseY
   	
   	variable nX = Dimsize(Data4D,0)
   	variable nY = Dimsize(Data4D,1)
    variable nZ = Dimsize(Data4D,2)
   	variable nF = Dimsize(Data4D,3)
    	
   	variable rr,pp
   	
   	variable kill = 0

   
    // where is the mouse?
    variable xpos =  AxisValFromPixel("", "Bottom", rhook.mouseLoc.h)
    variable ypos = AxisValFromPixel("", "Left", rhook.mouseLoc.v) 
    variable xx = round (xpos / DimDelta(XYImage, 0))
    variable yy =  round (ypos / DimDelta(XYImage, 0))
    variable maxX = DimSize(XYImage, 0)
    variable maxY = DimSize(XYImage, 1)
    
  	gMouseX = xx
   	gMouseY = yy
      
    switch(rhook.eventCode)    

		case 22: // mouse wheel
			gCurrentZ+=rhook.wheelDy/3 // wheel goes through planes
			if (gCurrentZ<0)
				gCurrentZ = 0
			endif
			if (gCurrentZ>nZ-1)
				gCurrentZ=nZ-1
			endif
			
			Multithread XYImage = ReferenceStack[p][q][gCurrentZ]//[gCurrentF]
			Multithread XYROIImage = ROIs3D[p][q][gCurrentZ] 			
						
			if (gROISeedMute==0)
				ROISeeds_MarkerSize[][2]=((gMarkerSize_ZRange-abs(ROISeeds[p][2]-gCurrentZ))/gMarkerSize_ZRange)*gMarkerSize_Max
				ROISeeds_MarkerSize[][2]=(ROISeeds_MarkerSize[p][2]<gMarkerSize_Min)?(gMarkerSize_Min):(ROISeeds_MarkerSize[p][2])
			endif
			
			XZCross[0][1]=gCurrentZ
			XZCross[1][1]=gCurrentZ
			YZCross[3][0]=gCurrentZ
			YZCross[4][0]=gCurrentZ
			
			if (nZ<2)
				XZCross = NaN
				YZCross = NaN
				XZImage = NaN
				YZImage = NaN
				XZROIImage = NaN
				YZROIImage = NaN
			endif
			
			break
		
			
			
		case 4:     // Mouse is moved
			// prevent error when move outside of image
            if (xx >= maxX || yy >= maxY || xx < 0  || yy < 0)
                break
            endif
            
                       
            
            
		    Multithread XZImage = ReferenceStack[p][yy][q]//[gCurrentF]
			Multithread YZImage = ReferenceStack[xx][q][p]//[gCurrentF]
			Multithread XZROIImage = ROIs3D[p][yy][q]
			Multithread YZROIImage = ROIs3D[xx][q][p]
			
							
			if (gROISeedMute==0)
				ROISeeds_MarkerSize[][0]=((gMarkerSize_XYRange-abs(ROISeeds[p][0]-xx))/gMarkerSize_XYRange)*gMarkerSize_Max
				ROISeeds_MarkerSize[][1]=((gMarkerSize_XYRange-abs(ROISeeds[p][1]-yy))/gMarkerSize_XYRange)*gMarkerSize_Max
				ROISeeds_MarkerSize[][0,1]=(ROISeeds_MarkerSize[p][q]<gMarkerSize_Min)?(gMarkerSize_Min):(ROISeeds_MarkerSize[p][q])
			endif
			
			XYCross[0][1]=yy
			XYCross[1][1]=yy
			XYCross[3][0]=xx
			XYCross[4][0]=xx
			XZCross[3][0]=xx
			XZCross[4][0]=xx
			YZCross[0][1]=yy
			YZCross[1][1]=yy
			
			if (nZ<2) // if only 1 layer
				XZCross = NaN
				YZCross = NaN
				XZImage = NaN
				YZImage = NaN
				XZROIImage = NaN
				YZROIImage = NaN
			endif
			
			break
       
        case 3:     // handle left mouse click         
            // prevent error when clicking outside of image
            if (xx >= maxX || yy >= maxY || xx < 0  || yy < 0)
                break
            endif
            
            // reset flood tolerance
            gFloodtolerance=gFloodtolerance_seed
             
            if (gROIMode>1 && NumType(gActiveROI)==0) // if in one of the paint mode and there is an active ROI, dont do the below
            else
            
	            // First check if there is aklready a nearby cell in XY
	            if (gnROIs>0)
		            for (rr=0;rr<gnROIs;rr+=1)
		           		if (NumType(ROISeeds[rr][0])==0) // if already exists
		  	         		variable CurrentDistanceXY = sqrt((xx-ROISeeds[rr][0])^2+(yy-ROISeeds[rr][1])^2) // only xy foir now !!!!
		  	         		variable CurrentDistanceZ = abs(gCurrentZ-ROISeeds[rr][2])
		  	         		
		  	         		
		    	       		if (CurrentDistanceXY<gDeletionDistanceXY && CurrentDistanceZ<gDeletionDistanceZ)
		    	      			ROISeeds[rr][]=NaN
		    	      			ROISeeds_MarkerSize[rr][]=NaN
								ROIs3D[][][]=(ROIs3D[p][q][r]==-rr-1)?(1):(ROIs3D[p][q][r])
								ROIs[][]=(ROIs[p][q]==-rr-1)?(1):(ROIs[p][q])
		    	      			for (pp=0;pp<3;pp+=1) // Zap NaNs
		    	      				make /o/n=(gnROIs_Max) tempwave = ROISeeds[p][pp]
		    	      				WaveTransform zapnans tempwave
		    	      				if (Dimsize(tempwave,0)>0)
		      	      					ROISeeds[0,Dimsize(tempwave,0)-1][pp]=tempwave[p]
		      	      				endif
		      	      			endfor
		   	      				ColourMarker=0
		   	      				gActiveROI=NaN
		    	      			killwaves tempwave
								kill = 1
								ROI3D_UpdateROIs()
		           			endif
		           		endif
		           	endfor
	           	endif

	           	/// If still here (no break triggered above), add a new cell
	           	for (rr=0;rr<gnROIs_Max;rr+=1)
	            	if (NumType(ROISeeds[rr][0])==0) // if already exists
	            	elseif (kill==0)
	             		ROISeeds[rr][0]=xx
	      				ROISeeds[rr][1]=yy
	      				ROISeeds[rr][2]=gCurrentZ
	      				gActiveROI=rr
	      				gSphereInflationXY=1
	      				gSphereInflationZ=1
	      				print "Active ROI:", gActiveROI
						break
					endif
				endfor
			endif
			
			//update the markers
			if (gROISeedMute==0)
				ROISeeds_MarkerSize[][2]=((gMarkerSize_ZRange-abs(ROISeeds[p][2]-gCurrentZ))/gMarkerSize_ZRange)*gMarkerSize_Max
				ROISeeds_MarkerSize[][2]=(ROISeeds_MarkerSize[p][2]<gMarkerSize_Min)?(gMarkerSize_Min):(ROISeeds_MarkerSize[p][2])
				ROISeeds_MarkerSize[][0]=((gMarkerSize_XYRange-abs(ROISeeds[p][0]-xx))/gMarkerSize_XYRange)*gMarkerSize_Max
				ROISeeds_MarkerSize[][1]=((gMarkerSize_XYRange-abs(ROISeeds[p][1]-yy))/gMarkerSize_XYRange)*gMarkerSize_Max
				ROISeeds_MarkerSize[][0,1]=(ROISeeds_MarkerSize[p][q]<gMarkerSize_Min)?(gMarkerSize_Min):(ROISeeds_MarkerSize[p][q])
			endif
			
		
			
			/// Get new count of cells across types
			make /o/n=(gnROIs_Max) tempwave = ROISeeds[p][0]
			tempwave[]=(NumType(ROISeeds[p][0])==0)?(1):(0)
			WaveStats/Q tempwave
			gnROIs=V_Sum
			
			
			// MarkerColours
			
			ColourMarker=0
			ColourMarker[gActiveROI]=1
			if (kill==1) // update the ROI colours...
				for (rr=0;rr<gnRois;rr+=1)
					variable colorposition = 255 * (rr+1)/gnRois
					ModifyImage XYROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2],  (2^16-1)*gROIAlpha_scale}
					ModifyImage XZROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
					ModifyImage YZROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
					ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
				endfor
				Multithread XYROIImage = ROIs3D[p][q][gCurrentZ] 
				Multithread XZROIImage = ROIs3D[p][gMouseY][q]
				Multithread YZROIImage = ROIs3D[gMouseX][q][p]
				
					
			endif
			
			if (kill==0)
				variable SeedBrightness = ReferenceStack[gMouseX][gMouseY][gCurrentZ]
				// dynamic tolerance finder
				duplicate /o ReferenceStack ReferenceStack_temp
				Smooth /DIM=0 1, ReferenceStack_temp
				Smooth /DIM=1 1, ReferenceStack_temp
				Smooth /DIM=2 1, ReferenceStack_temp
				variable SeedBrightness_smth = ReferenceStack_temp[gMouseX][gMouseY][gCurrentZ]
				killwaves ReferenceStack_temp
				if (gFillMode==0) // anatomy fill
					gFloodtolerance_seed = (abs(SeedBrightness-SeedBrightness_smth)/SeedBrightness)*gDynamicToleranceFactor
				else
					gFloodtolerance = gDynamicToleranceFactor
				endif
			
				ROI3D_Add() // actualy add the ROI
			endif
			
			if (nZ<2)
				XZCross = NaN
				YZCross = NaN
				XZImage = NaN
				YZImage = NaN
				XZROIImage = NaN
				YZROIImage = NaN
			endif
			
       		break
           	      
    endswitch

    // KEYBOARD
    
     	
     switch (rhook.keycode)   
    	case 119: // w key
    		ROI3D_ModROI(0)
    		break
    	case 115: // s key
    		ROI3D_ModROI(1)
    		break
    	case 97: // a key
    		ROI3D_ModROI(2)
    		break
    	case 100: // d key
    		ROI3D_ModROI(3)
    		break
    		
    	case 101: // e key
    		ROI3D_Run(1)
    		break
    	
    	case 113: // q key
    		ROI3D_Run(-1)
    		break
    		

	
	
	
	
	
	
	endswitch
   
    return 1
End

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////


Function ROI3D_Buttons(buttonz) : ButtonControl
	STRUCT WMButtonAction &buttonz

	NVAR gROIMode
	NVAR gActiveROI
	NVAR gFloodType
	NVAR gDynamicToleranceFactor
	wave ColourMarker

	switch( buttonz.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (buttonz.ctrlName)
				case "AvePress":
					print "Anatomical Average"
					ROI3D_ImageSource(0)
					break
											
				case "CorrPress":
					print "Local Activity Correlation"
					ROI3D_ImageSource(2)
					break
					
				case "QCPress":
					print "QC-Projection"
					ROI3D_ImageSource(3)
					break
				
				case "SeedPress":
					print "Seed Mode"
					print "select a pixel to begin..."
					gROIMode=5
					gActiveROI = NaN
					ColourMarker = NaN
					break	
					
				case "PlaneShuffleUp":
					print "shuffling bottom plane to the top"
					ROI3D_PlaneShuffle(-1)
					break
				case "PlaneShuffleDown":
					print "shuffling top plane to the bottom"
					ROI3D_PlaneShuffle(1)
					break
					
				case "XYSmoothUp":
					ROI3D_Smooth(1)
					break
					
				case "XYSmoothDown":
					ROI3D_Smooth(2)
					break
					
				case "ZSmoothUp":
					ROI3D_Smooth(3)
					break
					
				case "ZSmoothDown":
					ROI3D_Smooth(4)
					break
					
				case "SphereMode":
					gROIMode=0
					print "Sphere Mode"
					print "Select pixel to place a ROI-sphere"
					print "Control with AWSD keys"
					break
					
				case "FillModeAnatomy":
					gROIMode=1
					gFloodType=0 // Anatomy
					gDynamicToleranceFactor = 0.2 // set starting tol to 0.2
					print "Floodfill Mode: Anatomy"
					print "Select pixel to place start the flood-fill"
					print "Control with AWSD keys"
					break
					
				case "FillModeFunction":
					gROIMode=1
					gFloodType=1 // Function
					gDynamicToleranceFactor = 0.9 // set starting tol to 0.9
					print "Floodfill Mode: Function"
					print "Select pixel to place start the flood-fill"
					print "Control with AWSD keys"
					break
					
				case "PaintMode":
					gROIMode=2
					gActiveROI = NaN
					ColourMarker = NaN
					print "Paint Mode"
					print "Select pixel to place/add a ROI-sphere"
					print "click butotn again to accept"
					break
					
				case "FloodPaintMode":
					gROIMode=3
					gActiveROI = NaN
					ColourMarker = NaN
					print "Flood-Paint Mode"
					break
					
				case "ClusterMode":
					gROIMode=4
					print "Cluster Mode"
					print "Selects all pixels based on brighness minimum (Mask)"
					print "and optionally clusters them all based on function and"
					print "their xyz position"
					print "Active parameters:"
					print "Mask: fraction of pixels included"
					print "nCl: number of clusters seeded"
					print "Sm-XY/Z: SpaceSmooth before ind pixel traces are extracted (increases spatial coherence)"
					print "Sp-XY/Z: Adjusts XY and Z positional accuracy for clustering (increases spatial coherence)"
					print "SpaceW: relative weighting of spatial position vs function (in %)"
					print "i.e. 50 means 50:50 Space/Function; 10 means 10/90 Space:function etc..."
				
					ROI3D_MakeROIMask() // straight to Mask Maker
					ROI3D_ClusterMask()
					gActiveROI = 0
					ROI3D_Add() 
					ROI3D_UpdateROIs()				
					
					break
				
				
					
				case "ROIKill":
					ROI3D_KillROIs()
					print "Killed all ROIs"
					break
					
				case "ROISeedToggle":
					ROI3D_SeedToggle()
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


function ROI3D_ExecuteSlider(name, value, event)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved

	wave Data4D
	wave XZImage
	wave YZImage
	wave XYImage
	wave TimePointMarker

	wave XYCross
	wave XZCross
	wave YZCross

	wave XZROIImage
	wave YZROIImage
		

	NVAR gCurrentZ
	NVAR gCurrentF

	variable nX = Dimsize(Data4D,0)
	variable nY = Dimsize(Data4D,1)
	variable nZ = Dimsize(Data4D,2)

	Multithread XZImage = Data4D[p][nY/2][q][gCurrentF]
	Multithread YZImage = Data4D[nX/2][q][p][gCurrentF]
	Multithread XYImage = Data4D[p][q][gCurrentZ][gCurrentF]
	
	TimePOintMarker=NaN
	TimePointMarker[gCurrentF]=1

	XYCross[0][1]=nY/2
	XYCross[1][1]=nY/2
	XYCross[3][0]=nX/2
	XYCross[4][0]=nX/2
	XZCross[3][0]=nX/2
	XZCross[4][0]=nX/2
	YZCross[0][1]=nY/2
	YZCross[1][1]=nY/2
	
	if (nZ<2)
		XZCross = NaN
		YZCross = NaN
		XZImage = NaN
		YZImage = NaN
		XZROIImage = NaN
		YZROIImage = NaN
	endif


	
	return 0				// other return values reserved
end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////


function ROI3D_ImageSource(source)
variable source



wave ReferenceStack
wave Data3D
wave Data4D
wave DataCorr3D
wave DataQCProj3D
wave XZImage
wave YZImage
wave XYImage

wave XZCross
wave YZCross
wave XZROIImage
wave YZROIImage


NVAR gSmoothXY
NVAR gSmoothZ
NVAR gImageSource 
NVAR gCurrentZ

gImageSource=source

variable nX = Dimsize(ReferenceStack,0)
variable nY = Dimsize(ReferenceStack,1)
variable nZ = Dimsize(ReferenceStack,2)

if (source==0)
	ReferenceStack[][][]=Data3D[p][q][r]
	
elseif (source==1)
	ReferenceStack[][][]=Data4D[p][q][r]
elseif (source==2)	
	ReferenceStack[][][]=DataCorr3D[p][q][r]
elseif (source==3)	
	ReferenceStack[][][]=DataQCProj3D[p][q][r]
endif

ReferenceStack[][][]=(NumType(ReferenceStack[p][q][r])==0)?(ReferenceStack[p][q][r]):(0) // kill NaNs, Infs etc


if (gSmoothXY>0)
	Smooth /DIM=0 gSmoothXY, ReferenceStack
	Smooth /DIM=1 gSmoothXY, ReferenceStack
endif
if (gSmoothZ>0)
	Smooth /DIM=2 gSmoothZ, ReferenceStack
endif

Multithread XZImage = ReferenceStack[p][nY/2][q]//[gCurrentF]
Multithread YZImage = ReferenceStack[nX/2][q][p]//[gCurrentF]
Multithread XYImage = ReferenceStack[p][q][gCurrentZ]//[gCurrentF]

if (nZ<2)
	XZCross = NaN
	YZCross = NaN
	XZImage = NaN
	YZImage = NaN
	XZROIImage = NaN
	YZROIImage = NaN
endif

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function ROI3D_Add()

NVAR gMouseX
NVAR gMouseY

NVAR gROIMode

NVAR gActiveROI
NVAR gCurrentZ
NVAR gROI_SphereXY
NVAR gROI_SphereZ
NVAR gSphereInflationXY
NVAR gSphereInflationZ
NVAR gnROIs
NVAR gROIAlpha_scale

NVAR gPlaneshuffle

NVAR gFloodtolerance
NVAR gMaxRadiusXY
NVAR gMaxRadiusZ
NVAR gnFlood_iterations

NVAR gSmoothXY
NVAR gSmoothZ

NVAR gFloodType // 0 = Anatomy, 1 = function


wave ROISeeds
wave ROIs3D
wave ROIs
wave Data4D

wave XYROIImage 
wave XZROIImage 
wave YZROIImage
wave ReferenceStack
wave DisplayTrace

variable nX = Dimsize(ROIs3D,0)
variable nY_Orig = Dimsize(ROIs3D,1)
variable nPlanes = Dimsize(ROIs3D,2)
variable nF = Dimsize(Data4D,3)

variable SeedX = ROISeeds[gActiveROI][0]
variable SeedY = ROISeeds[gActiveROI][1]
variable SeedZ = ROISeeds[gActiveROI][2]

variable rr,pp,xx,yy,zz,ff

// Kill the Active ROI, unless in a paint mode (2,3)
if (gROIMode>1 && gROIMode<5)
else
	ROIs3D[][][]=(ROIs3D[p][q][r]==-gActiveROI-1)?(1):(ROIs3D[p][q][r]) // kill active ROI
endif
ROIs[][]=(ROIs[p][q]==-gActiveROI-1)?(1):(ROIs[p][q])


///// SPHERE MODE //////////////
if (gROIMode==0) // Sphere Mode
	// Add A Spherical ROI
	Duplicate /o ROIs3D Temp3D
	Temp3D = 0
	Temp3D[SeedX][SeedY][SeedZ]=1
	variable XYSmooth = gROI_SphereXY*gSphereInflationXY
	variable ZSmooth = gROI_SphereZ*gSphereInflationZ
	if (XYSmooth>1)
		Smooth /DIM=0 XYSmooth, Temp3D
		Smooth /DIM=1 XYSmooth, Temp3D
	endif
	if (ZSmooth>1)
		Smooth /DIM=2 ZSmooth, Temp3D
	endif
	
	variable PeakVal = Temp3D[SeedX][SeedY][SeedZ]
	
	ROIs3D[][][]=(ROIs3D[p][q][r]==-gActiveROI-1)?(1):(ROIs3D[p][q][r]) // kill the ROI if it already exists (i.e. it's just an update)
	ROIs3D[][][]=(Temp3D[p][q][r]>PeakVal/3)?(-gActiveROI-1):(ROIs3D[p][q][r])
	killwaves Temp3D
endif
///// PAINT MODE //////////////
if (gROIMode==2) // PAINT MODE
	// Add A Spherical ROI
	Duplicate /o ROIs3D Temp3D
	Temp3D = 0
	
	Temp3D[gMouseX][gMouseY][gCurrentZ]=1
	XYSmooth = gROI_SphereXY*gSphereInflationXY
	ZSmooth = gROI_SphereZ*gSphereInflationZ
	if (XYSmooth>1)
		Smooth /DIM=0 XYSmooth, Temp3D
		Smooth /DIM=1 XYSmooth, Temp3D
	endif
	if (ZSmooth>1)
		Smooth /DIM=2 ZSmooth, Temp3D
	endif
	PeakVal = Temp3D[gMouseX][gMouseY][gCurrentZ]
	Temp3D[][][]=(Temp3D[p][q][r]>PeakVal/3 || ROIs3D[p][q][r]==-gActiveROI-1)?(1):(0)
	
	ROIs3D[][][]=(Temp3D[p][q][r]>0)?(-gActiveROI-1):(ROIs3D[p][q][r])
	killwaves Temp3D
endif


///// FLOODFILL MODE //////////////
if (gROIMode==1) // Flood Fill Mode

	ROIs3D[SeedX][SeedY][SeedZ]=-(gActiveROI+1)
	variable SeedBrightness = ReferenceStack[SeedX][SeedY][SeedZ]
	variable CurrentX = SeedX
	variable CurrentY = SeedY
	variable CurrentZ = SeedZ
	
	if (gFloodType==1) // if Function mode; 0 is anatomy (quick),; 1 is function
		make /o/n=(nX,nY_orig,nPlanes) CorrReference_temp = NaN // make empty Correlation Stack
		duplicate /o Data4D Data4D_temp
		if (gSmoothXY>0)
			Smooth /DIM=0 gSmoothXY, Data4D_temp
			Smooth /DIM=1 gSmoothXY, Data4D_temp
		endif
		if (gSmoothZ>0)
			Smooth /DIM=2 gSmoothZ, Data4D_temp
		endif
		make /o/n=(nF) TempReference = Data4D[SeedX][SeedY][SeedZ][p]
		make /o/n=(nF) TempTarget = NaN
		make /o/n=(2) W_StatsLinearCorrelationTest = NaN
	endif
	
	for (ff=0;ff<gnFlood_iterations;ff+=1)
		
		// only allow 1 step in cardinal direction x y or z
		variable RandomStepType = floor(abs(Enoise(6))) // number from 0 to 5
		variable RandomStepX = 0
		variable RandomStepY = 0
		variable RandomStepZ = 0
		if (RandomStepType==0)
			RandomStepX = 1
		elseif (RandomStepType==1)
			RandomStepX = -1
		elseif (RandomStepType==2)
			RandomStepY = 1
		elseif (RandomStepType==3)
			RandomStepY = -1
		elseif (RandomStepType==4)
			RandomStepZ = 1
		elseif (RandomStepType==5)
			RandomStepZ = -1
		endif
		
		CurrentX+=RandomStepX
		CurrentY+=RandomStepY
		CurrentZ+=RandomStepZ
		
		if (CurrentX<0)
			CurrentX=0
			RandomStepX=0
		endif
		if (CurrentX>nX-1)
			CurrentX=nX-1
			RandomStepX=0
		endif
		if (CurrentY<0)
			CurrentY=0
			RandomStepY=0
		endif
		if (CurrentY>nY_Orig-1)
			CurrentY=nY_Orig-1
			RandomStepY=0
		endif
		if (CurrentZ<0)
			CurrentZ=0
			RandomStepZ=0
		endif
		if (CurrentZ>nPlanes-1)
			CurrentZ=nPlanes-1
			RandomStepZ=0
		endif
	
		variable CurrentRadiusXY = sqrt((SeedX-CurrentX)^2+(SeedY-CurrentY)^2)
		variable CurrentRadiusZ = abs(CurrentZ-SeedZ)
		variable NewBrightness = ReferenceStack[CurrentX][CurrentY][CurrentZ]
		
		// ANATOMY MODE
		if (gFloodType==0) // anatomy mode
			if (CurrentRadiusXY<gMaxRadiusXY && CurrentRadiusZ<gMaxRadiusZ && NewBrightness/SeedBrightness>(1-gFloodtolerance) && ROIs3D[CurrentX][CurrentY][CurrentZ] > 0) // >0 means it's 1 (nothing) or 2 (current)
				ROIs3D[CurrentX][CurrentY][CurrentZ]=2
			else
				CurrentX-=RandomStepX // go back to previous
				CurrentY-=RandomStepY
				CurrentZ-=RandomStepZ	
			endif
		endif
		/// FUNCTION MODE
		if(gFloodType==1) // function mode
			variable NewCorrelation = CorrReference_temp[CurrentX][CurrentY][CurrentZ]
			if (NumType(NewCorrelation)==2) // if that value is not yet computed...
				Multithread TempTarget[]=Data4D_temp[CurrentX][CurrentY][CurrentZ][p]
				StatsLinearCorrelationTest/Q TempTarget, TempReference
				CorrReference_temp[CurrentX][CurrentY][CurrentZ]=W_StatsLinearCorrelationTest[1] // ... add it
				NewCorrelation=CorrReference_temp[CurrentX][CurrentY][CurrentZ] // ...and allocate it
			endif
					
			if (NewCorrelation>gFloodtolerance && ROIs3D[CurrentX][CurrentY][CurrentZ] > 0) // if correlated enough, and not bumping into existing ROI
				ROIs3D[CurrentX][CurrentY][CurrentZ]=2 // add it
			else
				CurrentX-=RandomStepX // go back to previous
				CurrentY-=RandomStepY
				CurrentZ-=RandomStepZ	
			endif
		endif	
	endfor
	if(gFloodType==1)
		print "Current correlation threshold", gFloodtolerance
	endif
	ROIs3D[][][]=(ROIs3D[p][q][r]==2)?(-(gActiveROI+1)):(ROIs3D[p][q][r]) // apply the ROI	
endif

///// FLOODPAINT MODE //////////////
if (gROIMode==3) // Flood Paint Mode
	
	// overwrite the local seed
	SeedX = gMouseX
	SeedY = gMouseY
	SeedZ = gCurrentZ
	
	ROIs3D[][][]=(ROIs3D[p][q][r]==-gActiveROI-1)?(2):(ROIs3D[p][q][r]) // set active ROI to 2, if exists
	ROIs3D[SeedX][SeedY][SeedZ]=2 // set seed to 2
	
	
	SeedBrightness = ReferenceStack[SeedX][SeedY][SeedZ]
	CurrentX = SeedX
	CurrentY = SeedY
	CurrentZ = SeedZ
	
	for (ff=0;ff<gnFlood_iterations;ff+=1)
		
		// only allow 1 step in cardinal direction x y or z
		RandomStepType = floor(abs(Enoise(6))) // number from 0 to 5
		RandomStepX = 0
		RandomStepY = 0
		RandomStepZ = 0
		if (RandomStepType==0)
			RandomStepX = 1
		elseif (RandomStepType==1)
			RandomStepX = -1
		elseif (RandomStepType==2)
			RandomStepY = 1
		elseif (RandomStepType==3)
			RandomStepY = -1
		elseif (RandomStepType==4)
			RandomStepZ = 1
		elseif (RandomStepType==5)
			RandomStepZ = -1
		endif
		
		CurrentX+=RandomStepX
		CurrentY+=RandomStepY
		CurrentZ+=RandomStepZ
		
		if (CurrentX<0)
			CurrentX=0
			RandomStepX=0
		endif
		if (CurrentX>nX-1)
			CurrentX=nX-1
			RandomStepX=0
		endif
		if (CurrentY<0)
			CurrentY=0
			RandomStepY=0
		endif
		if (CurrentY>nY_Orig-1)
			CurrentY=nY_Orig-1
			RandomStepY=0
		endif
		if (CurrentZ<0)
			CurrentZ=0
			RandomStepZ=0
		endif
		if (CurrentZ>nPlanes-1)
			CurrentZ=nPlanes-1
			RandomStepZ=0
		endif
	
		CurrentRadiusXY = sqrt((SeedX-CurrentX)^2+(SeedY-CurrentY)^2)
		CurrentRadiusZ = abs(CurrentZ-SeedZ)
		NewBrightness = ReferenceStack[CurrentX][CurrentY][CurrentZ]
		
		if (CurrentRadiusXY<gMaxRadiusXY && CurrentRadiusZ<gMaxRadiusZ && NewBrightness/SeedBrightness>(1-gFloodtolerance) && ROIs3D[CurrentX][CurrentY][CurrentZ] > 0) // >0 means it's 1 (nothing) or 2 (current)
			ROIs3D[CurrentX][CurrentY][CurrentZ]=2
		else
			CurrentX-=RandomStepX // go back to previous
			CurrentY-=RandomStepY
			CurrentZ-=RandomStepZ	
		endif
	endfor
	
	ROIs3D[][][]=(ROIs3D[p][q][r]==2)?(-gActiveROI-1):(ROIs3D[p][q][r]) // apply the ROI	

	
endif

///// CLUSTER MODE //////////////
if (gROIMode==4) // Cluster Mode

	//print "making ROI mask..."
	//ROI3D_MakeROIMask()
		
endif

///// SEED-Corr Mode //////////////
if (gROIMode==5) // Seed Correlation Mode

	duplicate /o Data4D Data4D_temp
	if (gSmoothXY>0)
	Smooth /DIM=0 gSmoothXY, Data4D_temp
		Smooth /DIM=1 gSmoothXY, Data4D_temp
	endif
	if (gSmoothZ>0)
		Smooth /DIM=2 gSmoothZ, Data4D_temp
	endif
	
	make /o/n=(nF) TempReference = Data4D[SeedX][SeedY][SeedZ][p]
	make /o/n=(nF) TempTarget = NaN
	make /o/n=(2) W_StatsLinearCorrelationTest = NaN
	variable TimeCounter = 0
	printf "computing..."
	for (xx=0;xx<nX;xx+=1)
		for (yy=0;yy<nY_Orig;yy+=1)	
			for (pp=0;pp<nPlanes;pp+=1)	
				Multithread TempTarget[]=Data4D_temp[xx][yy][pp][p]
				StatsLinearCorrelationTest/Q TempTarget, TempReference
				ReferenceStack[xx][yy][pp]=W_StatsLinearCorrelationTest[1]
			endfor
		endfor
		TimeCounter+=1/nX
		if (TimeCounter>=0.1)
			TimeCOunter-=0.1
			printf "#"
		endif
	endfor
	print "done..."

	wave XZImage
	wave YZImage
	wave XYImage
	
	Multithread XZImage = ReferenceStack[p][SeedY][q]//[gCurrentF]
	Multithread YZImage = ReferenceStack[SeedX][q][p]//[gCurrentF]
	Multithread XYImage = ReferenceStack[p][q][SeedZ]//[gCurrentF]

	//
	killwaves TempReference, TempTarget,W_StatsLinearCorrelationTest,Data4D_temp
	ROISeeds[gActiveROI]=NaN

endif


ROI3D_UpdateROIs()


end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function ROI3D_ModROI(inputvalue)
variable inputvalue // 0 w, 1 s, 2 a, 3 d (awsd)

NVAR gSphereInflationXY
NVAR gSphereInflationZ
NVAR gInflationSpeed
NVAR gROI_SphereXY
NVAR gROI_SphereZ
NVAR gActiveROI
NVAR gFloodtolerance
NVAR gFloodType

wave ROIs3D
wave XYROIImage
wave XZROIImage
wave YZROIImage

NVAR gMouseX
NVAR gMouseY
NVAR gCurrentZ


NVAR gROIMode

if (gROIMOde==0) // Sphere Mode
	if (inputvalue==0) // up
		gSphereInflationXY*=1+gInflationSpeed
	elseif (inputvalue==1) // down
		gSphereInflationXY*=1-gInflationSpeed
	elseif (inputvalue==3) // left
		gSphereInflationZ*=1+gInflationSpeed
	elseif (inputvalue==2) // right
		gSphereInflationZ*=1-gInflationSpeed
	endif
	
	if (gSphereInflationXY<0.2)
		gSphereInflationXY=0.2
	endif
	
	if (gSphereInflationZ<0.2)
		gSphereInflationZ=0.2
	endif
	if (NumType(gActiveROI)==0) // if a ROI is active
		ROI3D_Add() // apply it (otherwise "just" updates the radius
	endif
endif
///
if (gROIMOde==2) // Paint Mode
	if (inputvalue==0) // up
		gSphereInflationXY*=1+gInflationSpeed
	elseif (inputvalue==1) // down
		gSphereInflationXY*=1-gInflationSpeed
	elseif (inputvalue==3) // left
		gSphereInflationZ*=1+gInflationSpeed
	elseif (inputvalue==2) // right
		gSphereInflationZ*=1-gInflationSpeed
	endif
	
	if (gSphereInflationXY<0.2)
		gSphereInflationXY=0.2
	endif
	
	if (gSphereInflationZ<0.2)
		gSphereInflationZ=0.2
	endif
	
	if (NumType(gActiveROI)==0) // if a ROI is active
		ROI3D_Add() // apply it (otherwise "just" updates the radius
	endif
endif
///

if (gROIMOde==1) // FloodFill Mode
	variable Changefactor = 0.1
	if (gFloodType==0)// anatomy
		Changefactor = 0.1
	elseif (gFloodType==1)
		 Changefactor = 0.02
	endif

	if (inputvalue==0) // up
		
		gFloodtolerance*=1+Changefactor
		if (NumType(gActiveROI)==0) // if a ROI is active
			ROI3D_Add() // apply it (otherwise "just" updates the tol
		endif
	elseif (inputvalue==1) // down
		gFloodtolerance*=1-Changefactor
		if (NumType(gActiveROI)==0) // if a ROI is active
			ROI3D_Add() // apply it (otherwise "just" updates the tol
		endif

	elseif (inputvalue>1) // ROIGrowth
		duplicate /o ROIs3D ROIs3D_temp
		ROIs3D_temp[][][]=(ROIs3D[p][q][r]==-(gActiveROI+1))?(1):(0)
		ROIs3D[][][]=(ROIs3D_temp[p][q][r]==1)?(2):(ROIs3D[p][q][r])
		
		if (inputvalue==3) // xy
			Smooth/DIM=0 1, ROIs3D_temp
			Smooth/DIM=1 1, ROIs3D_temp
		elseif (inputvalue==2) // z
			Smooth/DIM=2 1, ROIs3D_temp
		endif
		ROIs3D[][][]=(ROIs3D_temp[p][q][r]>0 && ROIs3D[p][q][r]>0)?(-(gActiveROI+1)):(ROIs3D[p][q][r])		
	
		ROI3D_UpdateROIs()
		
	endif

endif

if (gROIMOde==3) // FloodPaint Mode
	if (inputvalue==0) // up
		gFloodtolerance*=1.1
		if (NumType(gActiveROI)==0) // if a ROI is active
			ROI3D_Add() // apply it (otherwise "just" updates the tol
		endif
	elseif (inputvalue==1) // down
		gFloodtolerance*=0.9
		if (NumType(gActiveROI)==0) // if a ROI is active
			ROI3D_Add() // apply it (otherwise "just" updates the tol
		endif
	elseif (inputvalue>1) // ROIGrowth
		duplicate /o ROIs3D ROIs3D_temp
		ROIs3D_temp[][][]=(ROIs3D[p][q][r]==-(gActiveROI+1))?(1):(0)
		ROIs3D[][][]=(ROIs3D_temp[p][q][r]==1)?(2):(ROIs3D[p][q][r])
		
		if (inputvalue==3) // xy
			Smooth/DIM=0 1, ROIs3D_temp
			Smooth/DIM=1 1, ROIs3D_temp
		elseif (inputvalue==2) // z
			Smooth/DIM=2 1, ROIs3D_temp
		endif
		ROIs3D[][][]=(ROIs3D_temp[p][q][r]>0 && ROIs3D[p][q][r]>0)?(-(gActiveROI+1)):(ROIs3D[p][q][r])		
	
		
		
	endif

endif

if (gROIMOde==4) // Cluster Mode

endif

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function ROI3D_UpdateROIs()

NVAR gPlaneshuffle
NVAR gActiveROI
NVAR gCurrentZ
NVAR gMouseX
NVAR gMouseY
NVAR gnROIs
NVAR gROIAlpha_Scale
NVAR gROIMOde 

wave ROIs
wave ROIs3D
wave Data4D
wave ROIs3D_GizmoCoordinates
wave ROIs3D_GizmoColours

wave XYROIImage
wave XZROIImage
wave YZROIImage 
wave M_Colors
wave DisplayTrace
wave ROISeeds

variable nX = Dimsize(ROIs3D,0)
variable nY_Orig = Dimsize(ROIs3D,1)
variable nPlanes = Dimsize(ROIs3D,2)


variable pp,xx,yy,zz,rr

//Update the expanded ROI wave needed by the other scripts
for (pp=0;pp<nPlanes;pp+=1)
	variable sourceplane = pp
	variable targetplane = pp+gPlaneshuffle
	if (targetplane>nPlanes-1)
		targetplane-=nPLanes
	endif
	if (targetplane<0)
		targetplane+=nPLanes
	endif
	Multithread ROIs[][sourceplane*nY_Orig,(sourceplane+1)*nY_Orig-1]=ROIs3D[p][q-nY_orig*sourceplane][targetplane]
endfor

imagestats/Q ROIs
if (V_Min<0)
	gnRois=-V_Min
else
	gnROIs=0
endif


if (gROIMOde==4)
	// SORT OUT THE SEEDS
	OS_CoM()
		wave CoM
	for (rr=0;rr<gnROIs;rr+=1)
		variable XSeed = CoM[rr][0]
		variable YSeed = CoM[rr][1]
		variable ZSeed = 0
	
		for (pp=0;pp<nPlanes;pp+=1)
			if (YSeed>nY_orig-1)
				YSeed-=nY_orig
				ZSeed+=1
			endif
		endfor
		ROISeeds[rr][0]=XSeed
		ROISeeds[rr][1]=YSeed
		ROISeeds[rr][2]=ZSeed
	endfor	
endif	



// update the display ROIs
XYROIImage = ROIs3D[p][q][gCurrentZ] 
if (gMouseY>=0 && gMouseY <=nY_Orig-1)
	XZROIImage = ROIs3D[p][gMouseY][q]
endif
if (gMouseX>=0 && gMouseX <=nX-1)
	YZROIImage = ROIs3D[gMouseX][q][p]
endif

for (rr=0;rr<gnRois;rr+=1)
	variable colorposition = 255 * (rr+1)/gnRois
	ModifyImage XYROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2],  (2^16-1)*gROIAlpha_scale}
	ModifyImage XZROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
	ModifyImage YZROIImage explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
	ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2], (2^16-1)*gROIAlpha_scale}
endfor

// update the Display Trace
Displaytrace=0
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY_orig;yy+=1)
		for (zz=0;zz<nPlanes;zz+=1)
			if (ROIs3D[xx][yy][zz]==-gActiveROI-1)
				DisplayTrace[]+=Data4D[xx][yy][zz][p]
			endif
		endfor
	endfor
endfor

// update the GIZMO versions
//duplicate /o ROIs3D ROIs3D_Gizmo
//ROIs3D_Gizmo[][][]=(ROIs3D[p][q][r]<0)?(1):(NaN) // all ROIs are 1
//if (NumType(gActiveROI)==0)
//	ROIs3D_Gizmo[][][]=(ROIs3D[p][q][r]==-gActiveROI-1)?(2):(ROIs3D_Gizmo[p][q][r]) // active ROI is 2
//endif

// update GIZMO Scatter version
variable NextPixel = 2 // start at 2 coz 0 and 1 are 0,0,0 and max max max, for autoscaling
ROIs3D_GizmoCoordinates[2,nX*nY_Orig*nPlanes-1][]=NaN
ROIs3D_GizmoColours[2,nX*nY_Orig*nPlanes-1][]=NaN
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY_orig;yy+=1)
		for (pp=0;pp<nPlanes;pp+=1)
			if (ROIs3D[xx][yy][pp]<0)
				variable CurrentROI = -ROIs3D[xx][yy][pp]-1
				colorposition = 255 * (CurrentROI+1)/gnRois
				
				ROIs3D_GizmoCoordinates[NextPixel][0]=xx
				ROIs3D_GizmoCoordinates[NextPixel][1]=yy
				ROIs3D_GizmoCoordinates[NextPixel][2]=pp
				
				ROIs3D_GizmoColours[NextPixel][0,2]=M_Colors[colorposition][q]/2^16 // need to be 0:1, for stupid reasons
				ROIs3D_GizmoColours[NextPixel][3]=gROIAlpha_scale
				
				NextPixel+=1
			endif
		endfor
	endfor
endfor


end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function ROI3D_PlaneShuffle(upOrDown)
variable UpOrDOwn // -1 or 1

NVAR gPlaneshuffle


wave Data4D
wave Data3D
wave DataCorr3D
wave DataQCProj3D
wave ReferenceStack
wave ROIs3D

wave InputData
wave Correlation_Projection
wave Stack_Ave

variable nX = Dimsize(Data4D,0)
variable nY = Dimsize(Data4D,1)
variable nPlanes = Dimsize(Data4D,2)
variable nF = Dimsize(Data4D,3)

variable nY_inflated = nY*nPlanes
variable pp

// update planeshuffle parameter
gPlaneshuffle+=UpOrDOwn
if (gPlaneshuffle<0)
	gPlaneshuffle=nPlanes-1
endif
if (gPlaneshuffle>nPlanes-1)
	gPlaneshuffle=0
endif

print "Current TopFrame:,", gPlaneshuffle

// Reshuffle all 3/4D stacks
duplicate /o Data4D Data4D_temp
duplicate /o Data3D Data3D_temp
duplicate /o DataCorr3D DataCorr3D_temp
duplicate /o DataQCProj3D DataQCProj3D_temp
duplicate /o ReferenceStack ReferenceStack_temp
duplicate /o ROIs3D ROIs3D_temp

for (pp=0;pp<nPlanes;pp+=1)
	variable SourcePlane = pp
	variable targetplane = pp+upOrDown
	if (targetplane<0)
		targetplane = nPLanes-1
	endif
	if (targetplane>nPlanes-1)
		targetplane = 0
	endif	
	//reshuffle all 3/4D waves
	Multithread Data4D[][][targetplane][]=Data4D_temp[p][q][SourcePlane][s]
	Multithread Data3D[][][targetplane]=Data3D_temp[p][q][SourcePlane]
	Multithread DataCorr3D[][][targetplane]=DataCorr3D_temp[p][q][SourcePlane]
	Multithread DataQCProj3D[][][targetplane]=DataQCProj3D_temp[p][q][SourcePlane]
	Multithread ReferenceStack[][][targetplane]=ReferenceStack_temp[p][q][SourcePlane]
	Multithread ROIs3D[][][targetplane]=ROIs3D_temp[p][q][SourcePlane]

endfor
killwaves Data4D_temp,Data3D_temp,DataCorr3D_temp,ReferenceStack_temp,ROIs3D_temp

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////


function ROI3D_Smooth(inputval)
variable inputval // 1,2 XY, 3,4 Z

NVAR gSmoothXY
NVAR gSmoothZ
NVAR gImageSource
NVAR gMouseX
NVAR gMouseY
NVAR gCurrentZ

wave ReferenceStack
wave Data3D
wave Data4D
wave DataCorr3D
wave DataQCProj3D
wave XZImage
wave YZImage
wave XYImage


if (inputval==1)
	gSmoothXY+=1
elseif (inputval==2)
	gSmoothXY-=1
elseif (inputval==3)
	gSmoothZ+=1
elseif (inputval==4)
	gSmoothZ-=1
endif

if (gSmoothXY<0)
	gSmoothXY=0
endif
if (gSmoothZ<0)
	gSmoothZ=0
endif

if (gImageSource==0)
	ReferenceStack[][][]=Data3D[p][q][r]
elseif (gImageSource==1)
	ReferenceStack[][][]=Data4D[p][q][r]
elseif (gImageSource==2)	
	ReferenceStack[][][]=DataCorr3D[p][q][r]
elseif (gImageSource==3)	
	ReferenceStack[][][]=DataQCProj3D[p][q][r]
endif

if (gSmoothXY>0)
	Smooth /DIM=0 gSmoothXY, ReferenceStack
	Smooth /DIM=1 gSmoothXY, ReferenceStack
endif
if (gSmoothZ>0)
	Smooth /DIM=2 gSmoothZ, ReferenceStack
endif

Multithread XZImage = ReferenceStack[p][gMouseY][q]//[gCurrentF]
Multithread YZImage = ReferenceStack[gMouseX][q][p]//[gCurrentF]
Multithread XYImage = ReferenceStack[p][q][gCurrentZ]//[gCurrentF]

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

Function ROI3D_Run(inputval)
variable inputval // -1 or 1

wave Data4D
wave XZImage
wave YZImage
wave XYImage
wave TimePointMarker


variable nF = Dimsize(Data4D,3)

NVAR gCurrentF
NVAR gMouseX
NVAR gMouseY
NVAR gCurrentZ


gCurrentF+=inputval
if (gCurrentF<0)
	gCurrentF=0
endif
if (gCurrentF>nF-1)
	gCurrentF=nF-1
endif

Multithread XZImage = Data4D[p][gMouseY][q][gCurrentF]
Multithread YZImage = Data4D[gMouseX][q][p][gCurrentF]
Multithread XYImage = Data4D[p][q][gCurrentZ][gCurrentF]
TimePOintMarker=NaN
TimePointMarker[gCurrentF]=1

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////


function ROI3D_KillROIs()

NVAR gNROIs
NVAR gActiveROI

wave ROIs
wave ROISeeds
wave ROIs3D

variable nX = Dimsize(ROIs3D,0)
variable nY_Orig = Dimsize(ROIs3D,1)
variable nPlanes = Dimsize(ROIs3D,2)


wave XYROIImage
wave XZROIImage
wave YZROIImage

wave ROIs3D_GizmoCoordinates
wave ROIs3D_GizmoColours

wave DisplayTrace

gnROIs = 0
gActiveROI = NaN
ROIs = 1
ROIs3D = 1
ROISeeds = NaN

XYROIImage = NaN
XZROIImage = NaN
YZROIImage = NaN
DisplayTrace = NaN

ROIs3D_GizmoCoordinates[2,nX*nY_Orig*nPlanes-1][]=NaN
ROIs3D_GizmoColours[2,nX*nY_Orig*nPlanes-1][]=NaN


end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function ROI3D_SeedToggle()

NVAR gROISeedMute
wave ROISeeds_MarkerSize

if (gROISeedMute==0)
	gROISeedMute=1
	ROISeeds_MarkerSize = NaN
	print "ROIs muted"
else
	gROISeedMute=0
	ROISeeds_MarkerSize = 1
	print "ROIs unmuted"
endif

end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function ROI3D_MakeROIMask()

NVAR gMaskThreshold

wave ReferenceStack
wave ROIs3D
wave ROISeeds
wave ROISeeds_MarkerSize

variable nX = Dimsize(ReferenceStack,0)
variable nY = Dimsize(ReferenceStack,1)
variable nZ = Dimsize(ReferenceStack,2)
variable nP = nX*nY*nZ

variable xx,yy,zz

// get brightness hist
duplicate /o ReferenceStack TempStack
Redimension /n=(nP) Tempstack // 1D
Sort/R TempStack, TempStack // rank it
variable ThresholdBrightness = TempStack[floor(nP*gMaskThreshold)] // get brightness value at threshold (e.g. 0.2 = 20% from Max)
duplicate /o ReferenceStack ROIMask3D
Multithread ROIMask3D[][][]=(ReferenceStack[p][q][r]>ThresholdBrightness)?(-1):(1) // overwrite ROIs

// overwrite the ROIs
Duplicate /o ROIMask3D ROIs3D 
ROISeeds=NaN
ROISeeds_MarkerSize=NaN

//
killwaves TempStack
end

//////////////////////////////////////////////////////////////////////////////
// ************************************************************************ //
//////////////////////////////////////////////////////////////////////////////

function ROI3D_ClusterMask()

NVAR gMaskThreshold
NVAR gnClusterROIs_Max 
NVAR gVarExplained_Target
NVAR gnROIs

NVAR gClusterSpacePullXY // for actual Clustering
NVAR gClusterSpacePullZ
NVAR gClusterSpaceWeightPC

NVAR gClusterSpaceSmoothXY // for traces
NVAR gClusterSpaceSmoothZ


wave ROIMask3D
wave Data4D
wave ROIs3D
wave ROISeeds

variable nX = Dimsize(ROIMask3D,0)
variable nY = Dimsize(ROIMask3D,1)
variable nZ = Dimsize(ROIMask3D,2)
variable nF = Dimsize(Data4D,3)

variable gSpaceWeight = gClusterSpaceWeightPC/100
variable gTraceWeight = 1-gSpaceWeight

variable nP = Floor((nX*nY*nZ)*gMaskThreshold)

variable xx,yy,zz,cv,rr,pp

// traces and space components
make /o/n=(nF,nP) AllPixTraces_temp = NaN
make /o/n=(3,nP) AllPixXYZ_temp = NaN
make /o/n=(nF) tempwave = NaN

// traces SpaceSmooth
duplicate /o Data4D Data4D_temp
if (gClusterSpaceSmoothXY>0)
	print "XY-Space Smoothing:", gClusterSpaceSmoothXY
	Smooth /DIM=0 gClusterSpaceSmoothXY, Data4D_temp
	Smooth /DIM=1 gClusterSpaceSmoothXY, Data4D_temp
endif
if (gClusterSpaceSmoothZ>0)
	print "Z-Space Smoothing:", gClusterSpaceSmoothZ	
	Smooth /DIM=2 gClusterSpaceSmoothZ, Data4D_temp
endif

variable NextPix = 0
make /o/n=(nX,nP) ClusterTemp_X = 0
make /o/n=(nY,nP) ClusterTemp_Y = 0
make /o/n=(nZ,nP) ClusterTemp_Z = 0
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		for (zz=0;zz<nZ;zz+=1)
			if (ROIMask3D[xx][yy][zz]==-1)
				tempwave[]=Data4D_temp[xx][yy][zz][p]
				WaveStats/Q tempwave
				tempwave-=V_Avg
				tempwave/=V_SDev
				Multithread AllPixTraces_temp[][NextPix]=tempwave[p] // z norm version
				AllPixXYZ_temp[0][NextPix]=xx
				AllPixXYZ_temp[1][NextPix]=yy
				AllPixXYZ_temp[2][NextPix]=zz
				
				
				ClusterTemp_X[xx][NextPix]=1
				ClusterTemp_Y[yy][NextPix]=1
				if (nZ>1)
					ClusterTemp_Z[zz][NextPix]=1
				endif
				NextPix+=1
			endif
		endfor
	endfor
endfor
killwaves Data4D_temp

if (gClusterSpacePullXY>0)
	Smooth /DIM=0 gClusterSpacePullXY, ClusterTemp_X
	Smooth /DIM=0 gClusterSpacePullXY, ClusterTemp_Y
endif
if (gClusterSpacePullZ>0)
	Smooth /DIM=0 gClusterSpacePullZ, ClusterTemp_Z
endif
make /o/n=(nX+nY+nZ,nP) ClusterTemp_XYZ = NaN
ClusterTemp_XYZ[0,nX-1][]=ClusterTemp_X[p][q]
ClusterTemp_XYZ[nX,nX+nY-1][]=ClusterTemp_Y[p-nX][q]
ClusterTemp_XYZ[nX+nY,nX+nY+nZ-1][]=ClusterTemp_Z[p-(nX+nY)][q]
killwaves ClusterTemp_X, ClusterTemp_Y,ClusterTemp_Z

// PCA transform things

PCA /CVAR /SCMT /SRMT AllPixTraces_temp // Traces...
wave M_C // has the loadings in M_C[0][]; M_C[1][] etc
wave M_R // has the PCs, in M_R[][0]; M_R[][1] etc.
wave W_CumulativeVAR
variable nPCs_traces = 3 // default if all else fails
for (cv=0;cv<Dimsize(W_CumulativeVAR,0);cv+=1)
	if (W_CumulativeVAR[cv]>gVarExplained_Target) // look for 99%
		nPCs_traces = cv
		cv = Dimsize(W_CumulativeVAR,0)
	endif
endfor
make /o/n=(nPCs_traces) W_NonCumulativeVar_traces = NaN
W_NonCumulativeVar_traces[0]=W_CumulativeVAR[0]
W_NonCumulativeVar_traces[1,nPCs_traces-1]=W_CumulativeVAR[p]-W_CumulativeVAR[p-1]
print "PCA using", nPCs_traces, "trace components at weight ", gTraceWeight
make /o/n=(nPCs_traces,nP) PCLoadings4Clustering_Traces = M_C[p][q] * W_NonCumulativeVar_Traces[p] * gTraceWeight // scaled by Variance Explained...

PCA /CVAR /SCMT /SRMT ClusterTemp_XYZ // Space...
variable nPCs_Space = 3 // default if all else fails
for (cv=0;cv<Dimsize(W_CumulativeVAR,0);cv+=1)
	if (W_CumulativeVAR[cv]>gVarExplained_Target) // look for 99%
		nPCs_Space = cv
		cv = Dimsize(W_CumulativeVAR,0)
	endif
endfor
make /o/n=(nPCs_Space) W_NonCumulativeVar_space = NaN
W_NonCumulativeVar_space[0]=W_CumulativeVAR[0]
W_NonCumulativeVar_space[1,nPCs_Space-1]=W_CumulativeVAR[p]-W_CumulativeVAR[p-1]
print "PCA using", nPCs_Space, "space components at weight", gSpaceWeight
make /o/n=(nPCs_Space,nP) PCLoadings4Clustering_Space = M_C[p][q] * W_NonCumulativeVar_Space[p] * gSpaceWeight // scaled by Variance Explained...

make /o/n=(nPCs_traces+nPCs_Space,nP) PCLoadings4Clustering_All = NaN
PCLoadings4Clustering_All[0,nPCs_traces-1][]=PCLoadings4Clustering_Traces[p][q]
PCLoadings4Clustering_All[nPCs_traces,nPCs_traces+nPCs_space-1][]=PCLoadings4Clustering_Space[p-nPCs_traces][q]

// cluster
KMeans /NCLS=(gnClusterROIs_Max) /OUT=2 PCLoadings4Clustering_All

// apply clusters to the ROIs


wave W_KMMembers
gnROIs = WaveMax(W_KMMembers)+1
nextPix = 0
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		for (zz=0;zz<nZ;zz+=1)
			if (ROIMask3D[xx][yy][zz]==-1)
				ROIs3D[xx][yy][zz]=-(W_KMMembers[NextPix]+1)
				NextPix+=1
			endif
		endfor
	endfor
endfor
print WaveMax(W_KMMembers)+1, "nClusters allocated"

// Kill clusters with fewer than continuous pixels
// NOT YET IMPLEMENTED
 


// 
killwaves tempwave
killwaves W_CumulativeVAR, W_NonCumulativeVar_traces
killwaves PCLoadings4Clustering_Traces, AllPixXYZ_temp, AllPixTraces_temp
killwaves PCLoadings4Clustering_Space, PCLoadings4Clustering_all, ClusterTemp_XYZ

end