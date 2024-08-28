#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

//update 17/03/10: changed PopStats so that it safely ignores NaNs and infs
//update 15/06/10: added PopDisplayAll(popwave)
//update 11/11/10: added PopCorrelate

//populationwave combines many 1D waves to one 2d wave
//x of 1D becomes x of 2D
//use transpose XY to transpose


function PopulationWave(basename, outputname, number, [offset])
string basename, outputname
variable number, offset

variable counter, c2, xdim, timestep, xoffset, popcounter=0
string namestr, xunit, dataunit

if (ParamIsDefault(offset))
	offset = 0
endif

counter = offset
namestr = basename+num2str(counter)

if (waveexists($namestr))
	xdim = dimsize($namestr,0)
	timestep = dimdelta($namestr,0)
	xunit = WaveUnits($namestr,0)
	xoffset = DimOffset($namestr, 0)
	dataunit = WaveUnits($namestr, 1)
else
	print "No such wave: "+namestr
	return - 1
endif

make /o/n=(xdim,number) popwave = 0

do
	namestr = basename+num2str(counter)

	if (waveexists($namestr))
		duplicate /o $namestr, tempwave
		popwave[][popcounter]=tempwave[p]
	else
		print "No such wave: "+namestr
		redimension /n=(-1,popcounter) popwave
		counter = number * 10
	endif
	
	popcounter+=1
	counter+=1
while (counter < number+offset)

setscale /p x,xoffset,timestep,xunit popwave
setscale /p y,offset,1,"Trace #" popwave
setscale d -inf, inf, dataunit popwave
duplicate /o popwave, $outputname
killwaves /z tempwave, popwave

end


//////////////////////////////////////////////////////////////////

function PopX2Traces(PopWave,basename)
wave PopWave
string basename

variable tracenumbers = dimsize(PopWave, 1)
variable xdim = dimsize(PopWave,0)
variable counter, xdelta, xoffset, nameoffset
string name, xlabel, ylabel

xlabel = Waveunits(PopWave, 0)
xdelta = DimDelta(PopWave, 0)
xoffset = DimOffset(PopWave, 0)
ylabel = WaveUnits(PopWave, 1)
variable ydelta = DimDelta(PopWave, 1)
variable yoffset = DimOffset(PopWave, 1)


for (counter=0;counter<tracenumbers;counter+=1)

	make /o/n=(xdim) PXT
	PXT[]=popwave[p][counter]
	name = basename+num2str(counter+yoffset)
	SetScale /P x, xoffset,xdelta,xlabel, PXT
	SetScale /P y, 0,1,ylabel, PXT
	duplicate /o PXT, $name
	
	
endfor

killwaves /z PXT
return tracenumbers
end

//////////////////////////////////////////////////////////////////

function PopY2Traces(PopWave,basename)
wave PopWave
string basename

variable tracenumbers = dimsize(PopWave, 0)
variable xdim = dimsize(PopWave,1)
variable counter
string name

string datalabel = WaveUnits(PoPWave, -1)
string ylabel = WaveUnits(PopWave, 1)
variable ydelta = DimDelta(PopWave, 1)
variable yoffset = DimOffset(PopWave, 1)
string xlabel = Waveunits(PopWave, 0)
variable xdelta = DimDelta(PopWave, 0)
variable xoffset = DimOffset(PopWave, 0)

for (counter=0;counter<tracenumbers;counter+=1)

	make /o/n=(xdim) PYT
	PYT[]=popwave[counter][q]
	SetScale /P x Yoffset,Ydelta,Ylabel, PYT
	Setscale /P y 0,1,Xlabel, PYT
	name = basename+num2str(counter+Xoffset)
	duplicate /o PYT, $name
	
	
endfor

killwaves /z PYT
return tracenumbers
end

////////////////////////////////////////////////////////////////////

Function TraceYFromGraph(graphNameStr, yWaveNameStr)
String graphNameStr, yWaveNameStr

String info=TraceInfo(graphNameStr, yWaveNameStr,0)
String range=StringByKey("YRANGE",Info)
String range1,range2
sscanf range,"[%[0-9,\*]][%[0-9,\*]]",range1,range2 // Scans (twice) for characters 0,1,2,3,4,5,6,7,8,9,comma,asterisk between brackets.Ê 

variable output =  str2num(range2)

if(numtype(output)==2)
	return-1
else
	return output
EndIf

End

////////////////////////////////////////////////////////////////////


Function PopWaveFromWindow()

String TNL, trace, first
Variable NumTraces, ii, NumPoints, TraceY, HashPos

string TWName=WinName(0,1,1), Origin

TNL = tracenamelist(TWName,";",1)
NumTraces=ItemsInList(TNL)
First=StringFromList(0,TNL)


HashPos=StrSearch(First,"#",0)
	If(HashPos > 0)
		First=First[0,HashPos-1]		//remove "#n"
	Endif
	

NumPoints=Dimsize($First,0)		//Assume that NumPoints of all traces is the same
Make /o/n=(NumPoints,NumTraces) WinPop
Make /o/t/n=(NumTraces) WinPopOrigins
Setscale /p x,DimOffset($First,0),DimDelta($First,0),WaveUnits($First,0) WinPop
Setscale d,-inf,inf,WaveUnits($First,-1) WinPop

For(ii=0;ii<NumTraces;ii+=1)

	First=StringFromList(ii,TNL)
	TraceY=TraceYFromGraph(TWName,First)
	
	HashPos=StrSearch(First,"#",0)
	If(HashPos > 0)
		First=First[0,HashPos-1]		//remove "#n"
	Endif
	

	If(TraceY > 0)
		Duplicate /o/r=[][TraceY,TraceY] $First calc_Line
		WinPop[][ii]=calc_Line[p]
		WinPopOrigins[ii]=First+"[]["+Num2Str(TraceY)+"]"
	Else
		Duplicate /o $First calc_Line
		WinPop[][ii]=calc_Line[p]
		WinPopOrigins[ii]=First
	EndIf

EndFor


killwaves /z calc_Line
End

////////////////////////////////////////////////////////////////////
Function PopStats(PopWave)
	Wave PopWave
	Variable ii, numTraces, numPoints
	Variable val
	numTraces=Dimsize(PopWave,1)
	numPoints=DimSize(PopWave,0)
	
	Duplicate /o PopWave, W_PopAvg, W_PopSD, W_PopSEM
	Redimension /n=(-1) W_PopAvg, W_PopSD, W_PopSEM
	
	FastOP W_PopAvg = 0
	FastOP W_PopSD = 0
	
	Duplicate/o/free W_PopSD SDCalc
	

	val=ceil(WaveMax(popWave))+1

	
	MatrixOP /o/free tw2a=ReplaceNaNs(popWave,val)				//replace NaN with a value not present in popWave
	MatrixOP /o/free NaNWave=Equal(tw2a,val)					//binary matrix of NaN locations
	MatrixOP /o/free PW2=ReplaceNaNs(popWave,0)				//PopWave with NaN replaced with 0
	MatrixOP /o/free counterWave=sumRows(-NaNWave+1)		//counts total samples per point (excluding NaN)
	
	//sum values
	For(ii=0;ii<numTraces;ii+=1)
	
		//if(numtype(PW2[p][ii]))		//skip if inf
			//continue		
		//else
			W_PopAvg+=PW2[p][ii]
		//endif
	
	EndFor
	
	//divide by the appropriate count
	w_PopAvg=w_PopAvg[p][q]/counterWave[p]
	
	//calculate distances
	For(ii=0;ii<numTraces;ii+=1)
	
		//if(numtype(PW2[p][ii]))		//skip if inf
			//continue
		//else
			MultiThread SDCalc=(PopWave[p][ii]-W_PopAvg[p]) ^2
			MatrixOP/o/free ToAdd=ReplaceNaNs(SDCalc,0)
			MultiThread w_PopSD+=ToAdd
		//endif
		
	EndFor
	
	MultiThread W_PopSD=sqrt(W_PopSD[p][q]*(1/(counterWave[p]-1)))
	MultiThread W_PopSEM=W_PopSD[p][q]/Sqrt(counterWave[p])


End


////////////////////////////////////////////////////////////
//For calculating median and percentiles
Function SortPop(pop,[resultname])
	Wave pop
	string resultname
	
	if(paramisdefault(resultname))
		resultname=nameofwave(pop)+"_sort"
	endif
	
	variable npts = dimsize(pop,0), ntraces = dimsize(pop,1), ii, bl
	
	if(ntraces < 1)
		ntraces = 1
	endif
	
	Duplicate /o/free pop, trace, NorPop
	redimension /n=(-1) trace
	Make/free/o Histo

	
	for(ii=0;ii<ntraces;ii+=1)
		trace = pop[p][ii]
		sort trace,trace
		
		NorPop[][ii] =trace[p]
	
	endfor
	
	setscale /i x,0,100,"",NorPop
	Duplicate /o NorPop, $resultname
	
	
End


////////////////////////////////////////////////////////////////////

Function AverageWavesFromWindow(name)
	string name
	
	PopWaveFromWindow()
	Wave WinPop
	
	PopStats(WinPop)
	Wave W_PopAvg, W_PopSD
	
	string newnameavg, newnamesem
	
	AppendtoGraph w_PopAvg
	ModifyGraph lsize(W_PopAvg)=2,rgb(W_PopAvg)=(0,0,0)
	newnameavg = name+"_Avg"
	newnamesem = name+"_SEM"
	Rename W_PopAvg, $newnameavg
	Rename W_PopSEM, $newnamesem
	
	Display $newnameavg
	ErrorBars $newnameavg Y,wave=($newnamesem,$newnamesem)
	//newname = name+"_SEM"
	//Rename W_PopSEM, $newname


End

////////////////////////////////////////////////////////////////////

//Displays all traces of a popwave in a single graph
Function/s PopDisplayAll(popwave)	
	wave popwave
	
	variable nROIs, ii
	string GraphName
	
	nRois=DimSize(popwave,1)
	
	Display
	GraphName=s_Name
	
	for(ii=0;ii<nROIs;ii+=1)
	
		appendtograph popwave[][ii]
	
	endfor
		
	return GraphName
end

////////////////////////////////////////////////////////////////////
//calculates max. normalized cross-covariance  of all traces in Pop and timeshift of maximum
//as well as the complete correlogram
//output: 
//MaxCorr[][][0] - max. normalized cross-covariances
//MaxCorr[][][1] - timeshift (scaled)
//PopCorrelogram - complete normalized cross-covariances of all traces


Function/wave PopCorrelate(Pop,[auto])	
	Wave Pop
	Variable auto	//auto = 1 --> also calculate auto-covariance
	
	if(ParamIsDefault(auto))
		auto=0
	endif
	
	Variable nROI, nPoints, ii, xLoc, yLoc, xSD, ySD, vMax
	
	nROI=DimSize(Pop,1)
	nPOints=DimSize(Pop,0)
	
	Make/o/n=(nROI,nROI,nPoints*2-1) PopCorrelogram = NaN
//	Make/o/n=(nROI,nROI,nPoints) PopCorrelogram = NaN
	Make/o/n=(nROI,nROI,2) MaxCorr = NaN
	setscale/p z,(1-nPoints)*dimdelta(Pop,0),dimdelta(Pop,0),WaveUnits(Pop,0),PopCorrelogram
	
	
	For(ii=0;ii<nROI^2;ii+=1)
	
		xLoc=mod(ii,nROI)
		yLoc=floor(ii/nROI)
		
		if((xLoc==yLoc) &&(!auto))		//no Autocorrelation
			continue
		endif
		
		Duplicate/o/free/r=[][xLoc] Pop, xWave
		Duplicate/o/free/r=[][yLoc] Pop, yWave, testw
		redimension/n=(-1) xWave, yWave, testw
		wavestats/q/m=2 xWave
		xSD=V_sdev
		
		wavestats/q/m=2 yWave
		ySD=V_sdev
		
		Correlate/nodc xWave, yWave
		
		
		yWave/=xSD*ySD*(numpnts(xWave)-1)	//normalise
		
		
		
		
		MultiThread PopCorrelogram[xLoc][yLoc][]=yWave[r]
		WaveStats/q/m=1 yWave
		MaxCorr[xLoc][yLoc][0]=v_Max
		MaxCorr[xLoc][yLoc][1]=v_MaxLoc
	
	
	
	EndFor

	
	
	Return MaxCorr
End
	
	