#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_CallManualRoi()

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
variable Framerate = 1/(nY * LineDuration) // Hz 
variable Total_time = (nF * nX ) * LineDuration
print "Recorded ", total_time, "s @", framerate, "Hz"
variable xx,yy,ff // initialise counters

make /o/n=(nX,nY) ROIs = 1 // empty ROI wave
// make SD average
if (waveexists($"Stack_SD")==0)
	make /o/n=(nX,nY) Stack_SD = 0 // Sd projection of InputData
	make /o/n=(nF) currentwave = 0
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			Multithread currentwave[]=InputData[xx][yy][p] // get trace from "reference pixel"
			Wavestats/Q currentwave
			Stack_SD[xx][yy]=V_SDev
		endfor
	endfor
endif

// display SD wave
Display /k=1 
Appendimage Stack_SD
Appendimage ROIs
ModifyImage ROIs explicit=1,eval={-1,65535,0,0}
ModifyGraph height={Aspect,nY/nX}
WMCreateImageROIPanel() // calls SARFIA Roi generator - if follow that through it gives a wave 

// cleanup
killwaves currentwave,InputData

end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_ApplyManualRoi()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters

// data handling
wave M_ROIMask
variable nX = Dimsize(M_ROIMask,0)
variable nY = Dimsize(M_ROIMask,1)
make /o/n=(nX,nY) ROIs = 1 // empty ROI wave

variable xx,yy,rr

// create proper ROI Mask from M_ROIMask
duplicate /o M_ROIMask ROIbw_sub // make a lookup wave
duplicate /o ROIs ROIs_add
variable nRois = 0
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		if (ROIbw_sub[xx][yy]==0) // ROI are coded as 0, space is coded as 1...
			// here it found a seed
			nRois+=1
			variable RoiValue = (nRois)*(-1)
			ROIs_add[xx][yy]=RoiValue // add it to the ROI wave
			ROIs[xx][yy]=RoiValue // add it to the ROI wave
			do // flood fill that ROI
				if (nY>1)
					Imagestats/Q ROIs
				elseif (nY==1)
					Wavestats/Q ROIs // otherwise gets error from imagestats
				endif
				
				variable ROI_average_before = V_Avg
				// flood fill: note this will always work but if a ROI touches the edge it will report an out of range error.just live with it, otherwise 
				// would need endless set of if clauses
				
				if (nY>1)
					Multithread ROIs_add[0,nX-1][0,nY-1]=((ROIbw_sub[p][q]==0) && ((ROIs[p+1][q]==RoiValue)||(ROIs[p-1][q]==RoiValue)||(ROIs[p][q+1]==RoiValue)||(ROIs[p][q-1]==RoiValue)))?(RoiValue):(ROIs[p][q]) // flood fill
				elseif (nY==1) // no Y dimension in linescan)
					Multithread ROIs_add[0,nX-1][0]=((ROIbw_sub[p][q]==0) && ((ROIs[p+1][q]==RoiValue)||(ROIs[p-1][q]==RoiValue)))?(RoiValue):(ROIs[p][q]) // flood fill
				endif
				ROIs = ROIs_add
				if (nY>1)
					Imagestats/Q ROIs
				elseif (nY==1)
					Wavestats/Q ROIs // otherwise gets error from imagestats
				endif
				
				variable ROI_average_after = V_Avg
				if (ROI_average_before==ROI_average_after) // leaves fill if no more change
					break
				endif			
			while(1)
			ROIbw_sub[][]=(ROIs[p][q]==RoiValue)?(1):(ROIbw_sub[p][q]) // kill that ROI from lookup wave
		endif
	endfor
endfor

// colour in the ROIs
make /o/n=(1) M_Colors
Colortab2Wave Rainbow256
for (rr=0;rr<nRois;rr+=1)
	variable colorposition = 255 * (rr+1)/nRois
	ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
endfor



// cleanup
killwaves ROIbw_sub, ROIs_add,M_Colors

print RoiValue*(-1) ,"ROIs generated manually"


end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_monoPixelApply()

// data handling
wave M_ROIMask
variable nX = Dimsize(M_ROIMask,0)
variable nY = Dimsize(M_ROIMask,1)
make /o/n=(nX,nY) ROIs = 1 // empty ROI wave

variable xx,yy,rr

// make each pixel == 1 ROI
variable nRois = 0

for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)

		if (M_ROIMask[xx][yy]==0) // if its part of the marked region
			ROIs[xx][yy]=-nRois-1
			nRois+=1
		endif
	endfor
endfor

print nRois, "pixels selected as individual ROIs"
// colour in the ROIs
make /o/n=(1) M_Colors
Colortab2Wave Rainbow256
for (rr=0;rr<nRois;rr+=1)
	variable colorposition = 255 * (rr+1)/nRois
	ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
endfor



// cleanup
killwaves M_Colors



end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_CloneSarfiaRoi()

// 1 // check for existing Sarfia Mask from Laplace Operator thing
if (waveexists($"ROIs")==0) // KF 20150310; changed name of preexisting roi mask from MTROIWave to ROIs
	print "Warning: ROIs does not exist - doing nothing..."
else	
	
	wave ROIs
		
	wave OS_Parameters
	// flags from "OS_Parameters"
	variable X_cut = OS_Parameters[%LightArtifact_cut]
	variable LineDuration = OS_Parameters[%LineDuration]
	variable Channel = OS_Parameters[%Data_Channel]
	
	string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
	duplicate /o $input_name InputData
	variable nX = DimSize(InputData,0)
	variable nY = DimSize(InputData,1)
	variable nF = DimSize(InputData,2)
	variable Framerate = 1/(nY * LineDuration) // Hz 
	variable Total_time = (nF * nX ) * LineDuration
	print "Recorded ", total_time, "s @", framerate, "Hz"
	
	variable xx,yy,rr
	
	// make SD average
	make /o/n=(nX,nY) Stack_SD = 0 // Avg projection of InputData
	make /o/n=(nX,nY) ROIs_corrected = 1 // empty ROI wave
	make /o/n=(nF) currentwave = 0
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			Multithread currentwave[]=InputData[xx][yy][p] // get trace from "reference pixel"
			Wavestats/Q currentwave
			Stack_SD[xx][yy]=V_SDev
		endfor
	endfor
	
	// take MTROIWave and work out if it's dimensions are cropped in X axis (e.g. to get rid of light artifact before using the Laplace)
	Variable nX_ROIs = Dimsize(ROIs,0)
	
	// Project MTROIwave onto ROIs with correct x offset
	ROIs_corrected[nX-nX_ROIs,nX-1][]=ROIs[p-(nX-nX_ROIs)][q]
	duplicate/o ROIs_corrected, ROIs
	killwaves ROIs_corrected
	
	// display SD wave
	Display /k=1
	Appendimage Stack_SD
	Appendimage ROIs
	ModifyImage ROIs explicit=1,eval={-1,65535,0,0}
	ModifyGraph height={Aspect,nY/nX}
	
	// colour in the ROIs
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	variable nRois = Wavemin(ROIs)*(-1)
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
	endfor
	
	print "ROIs generated from SARFIA Mask"
		
	// cleanup
	killwaves currentwave,InputData

endif

end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function OS_ROIEdit()

if (waveexists($"ROIs")==0) 
	print "Warning: ROIs does not exist - doing nothing..."
else	
	
	variable/G gOpacity = 30 // %
	
	variable/G gX_shift = 0 // pixels
	variable/G gY_shift = 0 // pixels
	
	variable/G gRotate = 0
	
	variable /G gLeftKill = 0
	variable /G gRightkill = 0
	variable /G gTopKill = 0
	variable /G gBottomkill = 0
	
	variable /G gRenumberRois = 1 // default 1
	
	wave ROIs
	wave Stack_Ave
	variable nX = Dimsize(ROIs,0)
	variable nY = Dimsize(ROIs,1)
	variable nROIs = -WaveMin(ROIs)
	
	duplicate /o ROIs ROIs_new
	duplicate /o ROIs ROIs_rot // needed for rotate operation
	
	variable xx,yy,rr
	
	display /k=1
	ModifyGraph width=800, height = 500
	DoUpdate
	ModifyGraph width=0, height = 0
	
	Appendimage /L=ImageY /b=ImageX Stack_Ave
	Appendimage /L=ImageY /b=ImageX ROIs_new
	ModifyGraph fSize=8,axisEnab(ImageY)={0.05,1},axisEnab(ImageX)={0.25,1},freePos(ImageY)={0.2,kwFraction},freePos(ImageX)={0,kwFraction}
		// colour in the ROIs
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		ModifyImage ROIs_new explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2],(gOpacity/100)*(2^16-1)}
	endfor
	
	//
	
	
	String iName= WMTopImageGraph()		// find one top image in the top graph window
	Wave w= $WMGetImageWave(iName)	// get the wave associated with the top image.
	String/G imageName2=nameOfWave(w)
	GetWindow kwTopWin,gsize
	String cmd
	
	SetVariable gOpacity,pos={V_left+20,V_top+20},size={100,14}
	SetVariable gOpacity,limits={0,100,5},title="Opacity",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gOpacity,value=%s",GetDataFolder(1)+"gOpacity"
	Execute cmd
	
	SetVariable gX_shift,pos={V_left+20,V_top+80},size={100,14}
	SetVariable gX_shift,limits={-nX,nX-1,1},title="X-offset",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gX_shift,value=%s",GetDataFolder(1)+"gX_shift"
	Execute cmd
	
	SetVariable gY_shift,pos={V_left+20,V_top+110},size={100,14}
	SetVariable gY_shift,limits={-nX,nX-1,1},title="Y-offset",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gY_shift,value=%s",GetDataFolder(1)+"gY_shift"
	Execute cmd
	
	SetVariable gRotate,pos={V_left+20,V_top+140},size={100,14}
	SetVariable gRotate,limits={-180,180,1},title="Rotate",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gRotate,value=%s",GetDataFolder(1)+"gRotate"
	Execute cmd
	
	SetVariable gLeftKill,pos={V_left+20,V_top+170},size={100,14}
	SetVariable gLeftKill,limits={0,nX-1,1},title="Left Kill",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gLeftKill,value=%s",GetDataFolder(1)+"gLeftKill"
	Execute cmd
	
	SetVariable gRightkill,pos={V_left+20,V_top+200},size={100,14}
	SetVariable gRightkill,limits={0,nX-1,1},title="Right Kill",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gRightkill,value=%s",GetDataFolder(1)+"gRightkill"
	Execute cmd
	
	SetVariable gTopKill,pos={V_left+20,V_top+230},size={100,14}
	SetVariable gTopKill,limits={0,nY-1,1},title="Top Kill",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gTopKill,value=%s",GetDataFolder(1)+"gTopKill"
	Execute cmd
	
	SetVariable gBottomkill,pos={V_left+20,V_top+260},size={100,14}
	SetVariable gBottomkill,limits={0,nY-1,1},title="Bottom Kill",proc=OS_ExecuteVar_ROIEdit
	sprintf cmd,"SetVariable gBottomkill,value=%s",GetDataFolder(1)+"gBottomkill"
	Execute cmd
	
	Button ApplyEdit, pos={V_left+20,V_top+340},size={80,18}
	Button ApplyEdit, title="Apply",proc=OS_ApplyEdit
	
	Button ConfirmEdit, pos={V_left+20,V_top+380},size={80,18}
	Button ConfirmEdit, title="Confirm",proc=OS_ConfirmEdit
	
	Checkbox gRenumberROIs pos={V_left+20,V_top+420}
	Checkbox gRenumberROIs title="Renumber ROIs", variable= gRenumberROIs
		


endif


end

//*******************************************************************************************************
function OS_Execute_ROIEdit(name, value, event)
	String name			// name of this slider control
	Variable value		// value of slider
	Variable event		// bit field: bit 0: value set; 1: mouse down, //   2: mouse up, 3: mouse moved
	
	NVAR gOpacity
	NVAR gX_shift
	NVAR gY_shift
	
	NVAR gRotate 
	
	NVAR gLeftKill
	NVAR gRightKill
	NVAR gTopKill
	NVAR gBottomKill
	
	wave ROIs_new
	wave ROIs
	variable nX = Dimsize(ROIs,0)
	variable nY = Dimsize(ROIs,1)
	
	wave M_Colors
	variable nROIs = -WaveMin(ROIs)
	variable rr
	
	// rotation
	duplicate /o ROIs ROIs_rot
	
	if (gRotate==0)
	else
		ROIs_rot = 1
		variable RotationAngle_rad = gRotate/180 * pi
		variable xx,yy
		for (xx=0;xx<nX;xx+=1)
			for (yy=0;yy<nY;yy+=1)
				
				// get current original vector
				variable X_from_Centre = xx-nX/2
				variable Y_from_Centre = yy-nY/2
				variable DistFromCentre = sqrt(X_from_Centre^2+Y_from_Centre^2)
				variable StartAngle = atan2(Y_from_Centre,X_from_Centre)
				
				// get new vector (magnitude is unchanged)
				variable TargetAngle = StartAngle + RotationAngle_rad
				
				// convert that to new coordinates
				variable xx_rot = nX/2 + DistFromCentre * cos(TargetAngle)
				variable yy_rot = nY/2 + DistFromCentre * sin(TargetAngle)
				
				if (xx_rot>=0 && xx_rot<nX-1 && yy_rot>=0 && yy_rot<nY-1)
					// apply
					ROIs_rot[xx_rot][yy_rot]=ROIs[xx][yy]	
				endif
			
			
			
			endfor
		endfor
		
	
	
	
	endif
	
	
	// shift operation, using ROIs_rot
	ROIs_new = 1
	if (gX_shift<0 && gY_shift<0)
		ROIs_new[-gX_shift,nX-1][-gY_shift,nY-1]=ROIs_rot[p+gX_shift][q+gY_shift]
	elseif (gX_shift>=0 && gY_shift>=0)
		ROIs_new[0,nX-(1+gX_shift)][0,nY-(1+gY_shift)]=ROIs_rot[p+gX_shift][q+gY_shift]
	elseif (gX_shift>=0 && gY_shift<0)
		ROIs_new[0,nX-(1+gX_shift)][-gY_shift,nY-1]=ROIs_rot[p+gX_shift][q+gY_shift]
	elseif (gX_shift<0 && gY_shift>=0)
		ROIs_new[-gX_shift,nX-1][0,nY-(1+gY_shift)]=ROIs_rot[p+gX_shift][q+gY_shift]
	endif
	
	// kill operations
	if (gLeftKill>0)
		ROIs_new[0,gLeftKill][]=2
	endif
	if (gRightKill>0)
		ROIs_new[nX-(1+gRightKill),nX-1][]=2
	endif
	
	if (gTopKill>0)
		ROIs_new[][nY-(1+gTopKill),nY-1]=2
	endif
	if (gBottomKill>0)
		ROIs_new[][0,gBottomKill]=2
	endif
	ModifyImage ROIs_new eval={2,2^16-1,2^16-1,2^16-1,(gOpacity/100)*(2^16-1)}
	
	
	// recolour ROIs (if needed)
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		ModifyImage ROIs_new explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2],(gOpacity/100)*(2^16-1)}
	endfor

	
	return 0				// other return values reserved
end
//*******************************************************************************************************

Function OS_ExecuteVar_ROIEdit(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		// comment the following line if you want to disable live updates.
		case 3: // Live update
			Variable dval = sva.dval
			OS_Execute_ROIEdit("",0,0)
			break
	endswitch

	return 0
End

//*******************************************************************************************************
function OS_ApplyEdit(name)

	String name			// name of this slider control

	wave ROIs
	wave ROIs_New
	wave M_Colors
	NVAR gOpacity
	NVAR gRenumberROIs
	
	variable nROIs_original = -WaveMin(ROIs)
	variable rr
	
	// set all the "2" values (from cropping) to "1"
	ROIs_New[][]=(ROIs_new[p][q]==2)?(1):(ROIs_New[p][q])
		
	
	
	
	//renumber the ROIs in case any are lost
	variable currentROIcounter
	if (gRenumberROIs==1) // default
		currentROIcounter = 0
		for (rr=0;rr<nROIs_original;rr+=1)
			duplicate /o	ROIs_new tempROIs
			tempROIs[][]=(tempROIs[p][q]==-rr-1)?(1):(0)
			ImageStats/Q tempROIs
			if (V_Max>0) // if this ROI exists
				ROIs_new[][]=(ROIs_new[p][q]==-rr-1)?(-(currentROIcounter+1)):(ROIs_New[p][q])
				currentROICounter+=1
			endif
		endfor
		
		print "nROIs old:", nROIs_original, "nROIs new:", currentROICounter
	else
		currentROIcounter = nROIs_original
	endif

	// recolour ROIs (if needed)
	for (rr=0;rr<currentROICounter;rr+=1)
		variable colorposition = 255 * (rr+1)/currentROICounter
		ModifyImage ROIs_new explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2],(gOpacity/100)*(2^16-1)}
	endfor
	
	// overwrite the original with the current edit
	//duplicate /o ROIs_new ROIs

end
//*******************************************************************************************************
function OS_ConfirmEdit(name)
	String name			// name of this slider control
	OS_ApplyEdit(name)
	

	wave ROIs
	wave ROIs_New
	
	// overwrite the original with the current edit
	duplicate /o ROIs_new ROIs

end



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

