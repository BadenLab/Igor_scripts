#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// IMAGE REGISTRATION SCRIPT BY TAKESHI YOSHIMATSU, 2019

function OS_registration_rigiddrift()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif

wave OS_Parameters
// 2 //  check for Detrended Data stack
variable DataChannel = OS_Parameters[%Data_Channel]
if (waveexists($"wDataCh"+Num2Str(DataChannel)+"_detrended")==0)
	print "Warning: wDataCh"+Num2Str(DataChannel)+"_detrended wave not yet generated - doing that now..."
	OS_DetrendStack()
endif
// 2 //  check for Area Mask
if (waveexists($"M_ROIMask")==0)
	print "Make Area Mask first"
else


// get parameters from OS_Table
variable skipN = OS_Parameters[%registration_skipN]	//define in Parameter Table
variable averageplaneN = OS_Parameters[%registration_averageN]	//define in Parameter Table


string input_name1 = "wDataCh"+Num2Str(DataChannel)+"_detrended"
duplicate /o $input_name1 InputData

wave M_ROIMask
duplicate /o M_ROIMask AreaMask
variable nX = Dimsize(AreaMask,0)
variable nY = Dimsize(AreaMask,1)

// Get AreaMask size

variable xx,yy
make /o/n=(nY) currentLine
xx=-1
Do
	xx+=1
	currentLine[]=AreaMask[xx][p]
While (mean(currentLine)==1)
variable cornerX1=xx-1
xx=-1
Do
	xx+=1
	currentLine[]=AreaMask[nX-xx][p]
While (mean(currentLine)==1)
variable cornerX2=nX-xx-1

make /o/n=(nX) currentLine
yy=-1
Do
	yy+=1
	currentLine[]=AreaMask[p][yy]
While (mean(currentLine)==1)
variable cornerY1=yy-1
yy=-1
Do
	yy+=1
	currentLine[]=AreaMask[p][nY-yy]
While (mean(currentLine)==1)
variable cornerY2=nY-yy-1

killwaves currentLine

variable LightArtifact = OS_Parameters[%LightArtifact_cut]
duplicate /o/r=(cornerX1,cornerX2)(cornerY1,cornerY2)  InputData inputArea
duplicate /o/r=(cornerX1,cornerX2)(cornerY1,cornerY2) AreaMask AreaROI


nX = cornerX2-cornerX1+1
nY =cornerY2-cornerY1+1
variable nZ = Dimsize(inputArea,2)

variable registertoPrevious = 0

variable GaussFIlter=1
variable driftlength = 1

variable zz,nn,xxx,yyy,cc,aa
make /o/n=(nX,nY) current_first = 0
make /o/n=(nX,nY) current_plane = 0
make /o/n=(nX,nY) current_second = 0
make /o/n=(nX,nY) current_second_original = 0
make /o/n=(nX-driftlength*2,nY-driftlength*2) current_subtract = 0
make /o/n=(driftlength*2+1,driftlength*2+1) Drift_dif = 0
make /o/n=(ceil(nZ/skipN),2) drift_trace = NaN
drift_trace[0][]=0
variable driftX_total = 0
variable driftY_total = 0
make /o/n=(averageplaneN) current_pix = NaN
make /o/n=(nX,nY) current_average = 0
make /o/n=(nX,nY,nZ) current_Gauss = 0
make /o/n=(nX,nY,averageplaneN) current_averagestack = 0

display /k=1 /w=(20,50,320,300*nY/nX+100)
appendimage current_plane
ModifyGraph height={Aspect,nY/nX}
display /k=1 /w=(340,50,540,150) /n=drift_traceX drift_trace[][0]
ModifyGraph mode=4,marker=8,msize=2
setaxis bottom,0,ceil(nZ/skipN)
display /k=1 /w=(340,180,540,280) /n=drift_traceY drift_trace[][1]
ModifyGraph mode=4,marker=8,msize=2
setaxis bottom,0,ceil(nZ/skipN)

duplicate /o 	inputArea current_Gauss
if (GaussFilter==1)
	for (cc=0;cc<nZ;cc+=1)
		current_Average[][]=inputArea[p][q][cc]
		MatrixFilter/N=(3)/P=1 gauss current_Average
		current_Gauss[][][cc]=current_Average[p][q]
	endfor
endif

for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		current_pix[]=current_Gauss[xx][yy][zz+p]
		current_first[xx][yy]=mean(current_pix)
	endfor
endfor
current_plane[][]=current_first[p][q]
current_plane[0,LightArtifact][]=NaN
imagestats /q current_plane
current_plane[0,LightArtifact][]=V_avg
current_first[0,LightArtifact][]=NaN

cc=0
zz=0
for (zz=0;zz<nZ;zz+=skipN)
	if (zz<nZ-skipN-averageplaneN)
	variable entryZ = zz
	else
	entryZ = nZ-averageplaneN-1
	endif
	for (xx=0;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			current_pix[]=current_Gauss[xx+driftX_total][yy+driftY_total][entryZ+p]
			current_second[xx][yy]=mean(current_pix)
		endfor
	endfor
	current_second[0,LightArtifact][]=NaN

	for (xx=0;xx<driftlength*2+1;xx+=1)
		for (yy=0;yy<driftlength*2+1;yy+=1)
			current_subtract[][]=current_first[p][q] - current_second[p+xx-driftlength][q+yy-driftlength]
			current_subtract[0,LightArtifact+driftlength][]=NaN
			current_subtract[nX-driftlength-1,nX-1][]=NaN
			current_subtract[][0,driftlength-1]=NaN
			current_subtract[][nY-driftlength,nY-1]=NaN
			imagestats /q current_subtract
			Drift_dif[xx][yy]=V_Sdev
		endfor
	endfor
	imagestats /q Drift_dif
	if (registertoPrevious == 1)
		current_first[][]=current_second[p][q]
	endif
	driftX_total+=V_minRowLoc - driftlength
	driftY_total+=V_minColLoc - driftlength
	drift_trace[cc+1][0]=driftX_total
	drift_trace[cc+1][1]=driftY_total
	cc+=1
	current_plane[][]=current_second[p][q]
	current_plane[0,LightArtifact][]=NaN
	imagestats /q current_plane
	current_plane[0,LightArtifact][]=V_avg
	Doupdate
endfor

killwaves current_first, current_first,current_second, current_second_original, current_subtract, Drift_dif, current_averagestack
killwaves current_average,current_pix,current_second_original, current_plane
killwaves inputData,current_Gauss, InputArea
print "total X_drift" + Num2Str(driftX_total)
print "total Y_drift" + Num2Str(driftY_total)

endif

Area_Mask()

end


////////////////////////////////

function Area_Mask()

if (waveexists($"Stack_ave")==0)
	OS_DetrendStack()
endif
wave Stack_Ave
variable nX = Dimsize(Stack_Ave,0)
variable nY = Dimsize(Stack_Ave,1)

display /k=1/W=(50,50,350,350)
appendimage Stack_ave
ModifyGraph height={Aspect,nY/nX}
WMCreateImageROIPanel() 

end

////////////////////////////////

function OS_registration_recover()

wave OPL_Parameters
wave OS_Parameters
variable DataChannel = OS_Parameters[%Data_Channel]
variable DataChannel2 = OS_Parameters[%Data_Channel2]
variable LightArtifact = OS_Parameters[%LightArtifact_cut]
string input_name1 = "wDataCh"+Num2Str(DataChannel)+"_detrended"
string input_name2 = "wDataCh"+Num2Str(DataChannel2)
duplicate /o $input_name1 InputData

smooth_driftTrace()

wave drift_trace_rescale
duplicate /o drift_trace_rescale inputDriftTrace

variable nX = Dimsize(InputData,0)
variable nY = Dimsize(InputData,1)
variable nZ = Dimsize(InputData,2)
make /o/n=(nX,nY) current_second_original = 0
make /o/n=(nX,nY) current_second_original_Ch2 = 0

variable zz
for (zz=1;zz<nZ;zz+=1)
	current_second_original[][]=InputData[p+inputDriftTrace[zz][0]][q+inputDriftTrace[zz][1]][zz]
	InputData[][][zz]=current_second_original[p][q]
	current_second_original[0,LightArtifact][]=NaN
	imagestats /q current_second_original
	current_second_original[0,LightArtifact][]=V_avg
	if (waveexists($input_name2)==1)
		duplicate /o $input_name2 InputData2
		current_second_original_Ch2[][]=InputData2[p+inputDriftTrace[zz][0]][q+inputDriftTrace[zz][1]][zz]
		InputData2[][][zz]=current_second_original_Ch2[p][q]
	endif
	Doupdate
endfor

duplicate /o InputData $input_name1
duplicate /o InputData2 $input_name2
killwaves inputDriftTrace, InputData, InputData2, current_second_original, current_second_original_Ch2

end




////////////////////////////// generate rescaled drift_trace /////////////////////////////////////////
function smooth_drifttrace()

wave OS_Parameters
variable skipN = OS_Parameters[%registration_skipN]	//define in Parameter Table
variable DataChannel = OS_Parameters[%Data_Channel]

wave drift_trace
// median fileter the drift_trace
variable nF = Dimsize(drift_trace,0)
variable xx,yy,cc
variable medianN = 2
make /o/n=(medianN*2+1) currentN
for (yy=0;yy<2;yy+=1)
	for (xx=0;xx<nF-medianN;xx+=1)
		currentN=drift_trace[p+xx][yy]
		for (cc=0;cc<medianN+1;cc+=1)
			wavestats /q currentN
			currentN[V_maxrowLoc]=NaN
		endfor
		drift_trace[xx][yy]=V_max
	endfor
endfor


string input_name1 = "wDataCh"+Num2Str(DataChannel)+"_detrended"
duplicate /o $input_name1 InputData

variable nZ = Dimsize(InputData,2)
make /o/n=(nZ,2) drift_trace_rescale = NaN
variable traceZ = Dimsize(drift_trace,0)

make /o/n=(skipN*floor(nZ/skipN)+1) current_trace = NaN
make /o/n=(nZ-skipN*floor(nZ/skipN)+1) restofTrace = NaN
make /o/n=(nZ) allTrace = NaN


for (cc=0;cc<2;cc+=1)
make /o/n=(traceZ-1) current_driftTrace = drift_trace[p][cc]
make /o/n=(2) restof_driftTrace = drift_trace[p+traceZ-2][cc]
interpolate2 /f=0/I=0/t=1/n=(skipN*floor(nZ/skipN)+1) /Y=current_trace current_driftTrace
interpolate2 /f=0/I=3/t=1/n=(nZ-skipN*floor(nZ/skipN)+1) /Y=restof_trace restof_driftTrace
drift_trace_rescale[0,skipN*floor(nZ/skipN)-1][cc]=current_trace[p]
drift_trace_rescale[skipN*floor(nZ/skipN),nZ][cc]=restof_trace[p-skipN*floor(nZ/skipN)]
allTrace[]=drift_trace_rescale[p][cc]
variable smoothF
if (Dimsize(drift_trace,0)<20)
smoothF = 100
else
smoothF = 10000
endif
smooth smoothF,allTrace
drift_trace_rescale[][cc]=allTrace[p]
endfor

killwaves currentN,current_trace,restof_Trace,allTrace,current_driftTrace,restof_driftTrace

end
