#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// ORIGINAL
// Bar movements on the screen, verified by eye, from fish perspective:
// 1) Down		0		0,  1			
// 2) Up			4		0, -1
// 3) Down Right	1		0.707, 0.707
// 4) Up Left		5		-0.707, -0.707
// 5) Right		2		1, 0
// 6) Left			6		-1, 0
// 7) Up Right		3		0.707, -0.707
// 8) Down Left	7		-0.707, 0.707
//make /o/n=8 Conditions = {0,4,1,5,2,6,3,7} // Starting "Down", going  anticlockwise


// CHIARAS VERSION
// IS:                Right (0), Left (1), Upright (2), Downleft (3), Up (4), Down (5), UpLeft (6), DownRight (7) 
// BECOMES:  Right (2), Left (6), Upright (3), Downleft (7), Up (4), Down (0), UpLeft (5), DownRight (1) 
// therefore: make /o/n=8 Conditions = {2,6,3,7,4,0,5,1} 


function OS_Bars()

variable Script_version = 2 // 1 is "original for bars", 2 is "Chiara's version"
variable VectorSum_Threshold =0.3
variable RadialHist_Range = 0.2
variable nAngleBins = 16

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
variable Response_start_F= 25 
variable Response_End_F =55
variable X_squish = 100
variable y_squish = 10
make /o/n=8 Conditions = {0,4,1,5,2,6,3,7}
if (Script_version==1)
	Response_start_F= 25 // positions for readout in the actual response trace, in frames
	Response_End_F =55
	X_squish = 100 // for trace visualisation
	y_squish = 10
	make /o/n=8 Conditions = {0,4,1,5,2,6,3,7} // Starting "Down", going  anticlockwise
elseif (Script_version==2) // Chiara's Version
	Response_start_F= 9//25 // positions for readout in the actual response trace, in frames
	Response_End_F =16//55
	X_squish = 40// 100 // for trace visualisation
	y_squish = 0.5//10
	make /o/n=8 Conditions = {2,6,3,7,4,0,5,1} //{0,4,1,5,2,6,3,7} // Starting "Down", going  anticlockwise
endif
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

// compute bar specific things


variable nConditions= Dimsize(Conditions,0)
make /o/n=(nConditions,2) Conditions_Vector = 0
make /o/n=8 dummywaveX = {0,0.707,1,0.707,0,-0.707,-1,-0.707} // sorted order
make /o/n=8 dummywaveY = {1,0.707,0,-0.707,-1,-0.707,0,0.707}
Conditions_Vector[][0]=dummywaveX[p]
Conditions_Vector[][1]=dummywaveY[p]
killwaves dummywaveX,dummywaveY

make /o/n=(nConditions,2) Condition_offsets = Conditions_Vector[p][q]*X_squish // for trace display
Condition_offsets[][1]/=y_squish // y axis compressed 10 fold here




// flags from "OS_Parameters"
variable Display_averages = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration] // NOT USED YET
variable FOV_at_zoom065 = OS_Parameters[%FOV_at_zoom065] * (OS_Parameters[%fullFOVSize]/0.5)

// data handling
string traces_name = "Traces"+Num2Str(Channel)+"_raw"
if (use_znorm==1)
	traces_name = "Traces"+Num2Str(Channel)+"_znorm"
endif
duplicate /o $traces_name InputTraces

wave wParamsNum // Reads data-header
wave CoM
wave ROIs
wave Stack_ave

variable nX = DimSize(ROIs,0)
variable nY = DimSize(ROIs,1)
wave Triggertimes_Frame, Triggertimes, ROIs
variable nFrames = DimSize(InputTraces,0)
variable nROIs = DimSize(InputTraces,1)
variable nTriggers = Dimsize(Triggertimes,0)
variable nTrials= floor(nTriggers/ nConditions)

variable zoom = wParamsNum(30) // extract zoom
variable px_Size = (0.65/zoom * FOV_at_zoom065)/nX // microns


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable rr,cc,tt,ii

make/o/n=(nTriggers) SnippetDurations = Triggertimes_Frame[p+1]-Triggertimes_Frame[p]
wavestats/q SnippetDurations
variable SnippetDuration = round(V_avg) // some snippets do not have the same length so we take the average duration
killwaves SnippetDurations


//// Re-Snippeting original traces (not averages) into individual bar responses //// 
make/o/n=(SnippetDuration, nConditions, nTrials, nROIs) Bar_Individual = 0
make/o/n=(SnippetDuration, nConditions, nROIs) Bar_Averages = 0 
for (rr=0;rr<nRois;rr+=1)
	for (tt=0; tt<nTrials; tt+=1)
		for (cc=0; cc<nConditions; cc+=1)		
		make/o/n=(SnippetDuration) CurrentWave = InputTraces[p+Triggertimes_Frame[nConditions*tt + cc]][rr]
		Bar_Individual[][cc][tt][rr] = CurrentWave[p]
		Bar_Averages[][cc][rr]+= CurrentWave[p]/nTrials
		endfor
	endfor
endfor
killwaves CurrentWave


////Get maxima of snippets/////
make/o/n=(nConditions,nROIs) Bar_Responses = nan
make/o/n=(nConditions+1,nROIs) Bar_Responses_sorted = nan
make/o/n=(nConditions+1,2,nROIs) Bar_Responses_sorted_vector = nan
make/o/n=(nRois) Bar_VectorSum = nan


for (rr=0;rr<nROIs;rr+=1)
	make/o/n=(nConditions) Maximum_Response = 0
	make/o/n=(nConditions) Maximum_Response_sorted = 0	
	for(cc=0;cc<nConditions;cc+=1)
		make/o/n=(SnippetDuration) CurrentWave = Bar_Averages[p][cc][rr]
		Maximum_Response[cc]= WaveMax(CurrentWave,Response_start_F,Response_End_F)
		Maximum_Response_sorted[Conditions[cc]]= WaveMax(CurrentWave,Response_start_F,Response_End_F)
	endfor

	Maximum_Response[]=(Maximum_Response[p]<0)?(0):(Maximum_Response[p]) // eliminate negatives
	Maximum_Response_sorted[]=(Maximum_Response_sorted[p]<0)?(0):(Maximum_Response_sorted[p])
	Wavestats/Q Maximum_Response 
	if (V_Max>0) // if any non-zero ones are left
	  	Maximum_Response/=V_max
		Maximum_Response_sorted/=V_Max
	endif

	Bar_Responses[][rr] = Maximum_Response[p]
	Bar_Responses_sorted[0,nConditions-1][rr] = Maximum_Response_sorted[p]
	Bar_Responses_sorted[nConditions][rr] = Maximum_Response_sorted[0]//extra condition wrap
endfor

setscale x,0,360,"deg." Bar_Responses_sorted

// compute vector version of max responses
for (rr=0;rr<nROIs;rr+=1) 
	make/o/n=(nConditions) CurrentX = 0
	make/o/n=(nConditions) CurrentY = 0	
		
	for(cc=0;cc<nConditions;cc+=1)
		CurrentX[cc] = Bar_Responses_sorted[cc][rr]*Conditions_Vector[cc][0]
		CurrentY[cc] = Bar_Responses_sorted[cc][rr]*Conditions_Vector[cc][1]
	endfor
	variable xSum = sum(CurrentX)
	variable ySum = sum(CurrentY)
	Bar_VectorSum[rr] = sqrt(xSum^2 + ySum^2) 

	Bar_Responses_sorted_vector[0,nConditions-1][0][rr]=CurrentX[p]
	Bar_Responses_sorted_vector[0,nConditions-1][1][rr]=CurrentY[p]	
	Bar_Responses_sorted_vector[nConditions][0][rr]=CurrentX[0]  //extra condition wrap
	Bar_Responses_sorted_vector[nConditions][1][rr]=CurrentY[0]	
endfor

killwaves CurrentWave,CurrentX, CurrentY, Maximum_Response, Maximum_Response_sorted
killwaves InputTraces

/////Get angle of preferred direction////
 
 make /o/n=(2,2,nRois) MeanVectors = 0
 
make/o/n=(nRois) Bar_Angles = 0
make/o/n=(nConditions+1) xValue = 0
make/o/n=(nConditions+1) yValue = 0

for (rr=0;rr<nRois;rr+=1)
	
	if (Bar_VectorSum[rr]>VectorSum_Threshold)

		for (cc=0;cc<nConditions;cc+=1)
			xValue[cc] = Bar_Responses_sorted[cc][rr]*Conditions_Vector[cc][0]
			yValue[cc] = Bar_Responses_sorted[cc][rr]*Conditions_Vector[cc][1]
		endfor
		
		xValue[nConditions] = xValue[0]
		yValue[nConditions] = yValue[0]
	
		variable xSum1 = sum(xValue, 0, nConditions-1)
		variable ySum1 = sum(yValue, 0, nConditions-1)
	
		Bar_Angles[rr] = atan2(ySum1, xSum1) + pi
		MeanVectors[1][0][rr] = xSum1/nConditions
		MeanVectors[1][1][rr] = ySum1/nConditions	

		
	else
		Bar_Angles[rr]=NaN
	endif	
	
	
endfor
duplicate/o Bar_Angles, Bar_AnglesDeg
Bar_AnglesDeg=Bar_AnglesDeg*180/pi
duplicate/o Bar_Angles, Bar_AnglesPis
Bar_AnglesPis=Bar_Angles/pi

// display

if (Display_averages==1)
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		// plot vector version
		display /k=1 /l=VectorY /b=VectorX Bar_Responses_sorted_vector[][1][rr] vs Bar_Responses_sorted_vector[][0][rr]
		Appendtograph /l=VectorY /b=VectorX MeanVectors[][1][rr] vs MeanVectors[][0][rr]
		
		ModifyGraph axisEnab(VectorY)={0.05,1},axisEnab(VectorX)={0.05,0.45};DelayUpdate
		ModifyGraph freePos(VectorY)={0,kwFraction},freePos(VectorX)={0,kwFraction}
		
		SetAxis VectorY -1,1;DelayUpdate
		SetAxis VectorX -1,1
		ModifyGraph marker(Bar_Responses_sorted_vector)=19;DelayUpdate
		ModifyGraph msize(Bar_Responses_sorted_vector)=1,lsize=1.5
		ModifyGraph rgb(MeanVectors) = (0,0,0)
	
		// plot individual response version
		for (cc=0;cc<nConditions;cc+=1)
			for (tt=0;tt<nTrials;tt+=1)
				Appendtograph /l=RespY /b=RespX Bar_Individual[][cc][tt][rr]
				string tracename = "Bar_Individual#"+Num2Str(tt+cc*nTrials)
				if (cc==0 && tt==0)
					tracename = "Bar_Individual"
				endif
				ModifyGraph rgb($tracename) = (52000,52000,52000)
				ModifyGraph offset($tracename)={Condition_offsets[Conditions[cc]][0],Condition_offsets[Conditions[cc]][1]}
			endfor
		endfor		

		for (cc=0;cc<nConditions;cc+=1)
			Appendtograph /l=RespY /b=RespX Bar_Averages[][cc][rr]
			tracename = "Bar_Averages#"+Num2Str(cc)
			if (cc==0)
				tracename = "Bar_Averages"
			endif
			ModifyGraph rgb($tracename) = (0,0,0)
			ModifyGraph offset($tracename)={Condition_offsets[Conditions[cc]][0],Condition_offsets[Conditions[cc]][1]}
		endfor		
		•ModifyGraph noLabel(RespY)=2,noLabel(RespX)=2,axThick(RespY)=0,axThick(RespX)=0;DelayUpdate
		•ModifyGraph axisEnab(RespY)={0.05,1},axisEnab(RespX)={0.55,1};DelayUpdate
		•ModifyGraph freePos(RespY)={0.55,kwFraction},freePos(RespX)={0,kwFraction}
		
		
		// global
		ModifyGraph fSize=8
		ModifyGraph width=300,height={Aspect,0.5}
		variable colorposition = 255 * (rr+1)/nRois
		ModifyGraph rgb(Bar_Responses_sorted_vector)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
		ModifyGraph lblPos(VectorY)=47;DelayUpdate
		Label VectorY "\\Z10ROI "+Num2Str(rr)
	
	//	ModifyGraph width=0,height=0
	endfor
	
	display /k=1 
	Appendimage Bar_Responses_sorted
	
	ModifyGraph nticks(left)=(nROIs),fSize=8,axisEnab(left)={0.05,1};DelayUpdate
	ModifyGraph axisEnab(bottom)={0.05,1};DelayUpdate
	Label left "\\Z10ROI";DelayUpdate
	Label bottom "\\Z10Direction (\\U)";DelayUpdate
	SetAxis/A/R left
	ModifyImage Bar_Responses_sorted ctab= {-1,*,BlueBlackRed,0}
	
endif


// Additional display stuff quickly hacked in
display /k=1
Appendimage Stack_ave
Appendimage ROIs
duplicate /o MeanVectors MeanVectors_inflated
MeanVectors_inflated*=100
make /o/n=(1) M_Colors
Colortab2Wave Rainbow256

for (rr=0;rr<nROIs;rr+=1)
	//colorposition = 255 * (rr+1)/nRois
	colorposition = 255 * (Bar_AnglesPis[rr])/2
	
	if (Bar_VectorSum[rr]>VectorSum_Threshold)
		ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
	else
		ModifyImage ROIs explicit=1,eval={-rr-1,30000,30000,30000}
	endif
	
	
	Appendtograph MeanVectors_inflated[][1][rr] vs MeanVectors_inflated[][0][rr]	
	tracename = "MeanVectors_inflated#"+Num2Str(rr)
	if (rr==0)
		  tracename = "MeanVectors_inflated"
	endif
	ModifyGraph offset($tracename)={(CoM[rr][0]-nY/2)*px_size,(CoM[rr][1]-nX/2)*px_size}
	ModifyGraph rgb($tracename) = (M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
endfor
ModifyGraph lsize=1.5
ModifyGraph height={Aspect,1}

// histogram of angles
•Make/N=(nAngleBins+1)/O Bar_AnglesPis_Hist;DelayUpdate
•Histogram/B={0-1/nAngleBins,2/nAngleBins,nAngleBins+1} Bar_AnglesPis,Bar_AnglesPis_Hist;DelayUpdate

Bar_AnglesPis_Hist[0]+=Bar_AnglesPis_Hist[nAngleBins] // loop 
Bar_AnglesPis_Hist[nAngleBins]=Bar_AnglesPis_Hist[0]

//•Display /k=1 Bar_AnglesPis_Hist
//•ModifyGraph fSize(left)=8,axisEnab(left)={0.05,1},axisEnab(bottom)={0.05,1};DelayUpdate
Bar_AnglesPis_Hist/=nROIs // normalise by ALL ROIs (ncluding non DS ones)
//•Label left "\\Z10Fraction of all ROIs";DelayUpdate
//•Label bottom "\\Z10Preferred Direction"
//•ModifyGraph mode=5,hbFill=5,rgb=(0,0,0)
//•SetAxis bottom 0,2
//SetAxis left 0,*
// radial
display /k=1 
make /o/n=(2) plotdummy = 0
Appendtograph plotdummy vs plotdummy
ModifyGraph zero=1,fSize=8,axisEnab(left)={0.05,1},axisEnab(bottom)={0.08,1};DelayUpdate
SetAxis left -RadialHist_Range,RadialHist_Range;DelayUpdate
SetAxis bottom -RadialHist_Range,RadialHist_Range
ModifyGraph height={Aspect,1}
ShowTools/A arrow

for (cc=0;cc<nAngleBins;cc+=1)

	variable x1 = -1 * Bar_AnglesPis_Hist[cc] *  cos(((cc-0.5)/nAngleBins)*2*pi)
	variable y1 = -1* Bar_AnglesPis_Hist[cc] *  sin(((cc-0.5)/nAngleBins)*2*pi)
	variable x2 = -1 * Bar_AnglesPis_Hist[cc] *  cos(((cc+0.5)/nAngleBins)*2*pi)
	variable y2 = -1 * Bar_AnglesPis_Hist[cc] *  sin(((cc+0.5)/nAngleBins)*2*pi)
	
	colorposition = 255 * (cc/nAngleBins)
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 3,fillfgc= (M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]);DelayUpdate
	DrawPoly 0,0,1,1,{0,0,x1,y1,x2,y2,0,0}
endfor

HideTools/A


end


