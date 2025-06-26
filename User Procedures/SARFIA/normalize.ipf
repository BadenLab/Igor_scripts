#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

//Update 24/02/2010: added /c flag to histogram in normalizepop
//Update 20/04/2010: renamed normalize to normalise to avoid naming conflict
//Update 03/01/2011: added CopyScales to normalise

function/wave IACPnormalize(sourcewave, targetwave)

	wave sourcewave
	string targetwave
	
	variable bl
	
	Make/o/free Histo
	Histogram /b=3 SourceWave, Histo
	wavestats /q/m=1 histo
	bl = v_maxloc
	
	duplicate /o/free sourcewave, calcwave
	calcwave = sourcewave / bl - 1
	
	duplicate /o calcwave, $targetwave
	
	wave w=$targetwave
	return w
end

//////////////////////////////////////////////////////

function/wave rectify(sourcewave, targetwave, [direction])

	wave sourcewave
	string targetwave
	variable direction
	
	if(paramisdefault(direction))
		direction=1
	elseif(direction >= 0)
		direction=1
	else
		direction = -1
	endif
	
	variable dims
	
	duplicate/o/free sourcewave, wv_calc
	
	
	dims = wavedims(wv_calc)
	
	if (dims == 1)
		MultiThread wv_calc = SelectNumber((wv_calc[p])*direction<0,wv_calc[p],0)	
	elseif (dims==2)
		MultiThread wv_calc = SelectNumber((wv_calc[p][q])*direction<0,wv_calc[p][q],0)	
	elseif (dims==3)
		MultiThread wv_calc = SelectNumber((wv_calc[p][q][r])*direction<0,wv_calc[p][q][r],0)	
	elseif(dims==4)
		MultiThread wv_calc = SelectNumber((wv_calc[p][q][r][s])*direction<0,wv_calc[p][q][r][s],0)		
	else
		DoAlert 0, "Rectify: Wave seems to have no data."
	endif
	
	duplicate /o wv_calc, $targetwave 
	wave w=$targetwave
	
	//print direction
	return w
end

//////////////////////////////////////////////////////

//function NormalizePop(sourcewave, targetwave)		//normalizes in the X dimension by the average
//
//wave sourcewave
//string targetwave
//
//variable xdim, ydim, counter = 0
//duplicate /o sourcewave, calcwave
//
//
//xdim = dimsize(sourcewave, 0)
//ydim = dimsize(sourcewave, 1)
//
//do
//	imagestats /m=1/g={0,xdim-1,counter,counter} sourcewave
//	if(v_flag==-1)
//		DoAlert 0, "Imagestats in function NormalizePop failed. Please check the code."
//		return -1
//	endif
//	
//		calcwave[][counter] = sourcewave[p][counter] / v_avg - 1
//
//
//counter +=1
//while (counter<ydim)
//
//duplicate /o calcwave, $targetwave 
//killwaves /z calcwave
//end

///////////////////////////////////////////////////
Function/Wave normalise(wv, from, to, [name])
	wave wv
	variable from, to
	string name
	
	if (paramisdefault(name))
		name = nameofwave(wv)+"_nor"
	endif
	
	
	MatrixOP/o/free norwv = scale(wv,from,to)
	duplicate /o norwv, $name

	wave w=$name
	CopyScales wv, w
	return w
end

///////////////////////////////////////////////////

Function/Wave NormalizePop(pop,resultname,[BaseLineWave])		//normalizes by the mode, which is closer to the actual "baseline"
	Wave pop
	string resultname
	variable BaseLineWave
	
	variable npts = dimsize(pop,0), ntraces = dimsize(pop,1), ii, bl
	string BLName=ResultName+"_BL"
	
	if(ParamIsDefault(BaseLineWave))
		BaseLineWave=0
	endif
	
	if(ntraces < 1)
		ntraces = 1
	endif
	
	Duplicate /o/free pop, trace, NorPop
	redimension /n=(-1) trace
	Make/free/o Histo
	Make/o/n=(ntraces)/free w_BL
	
	for(ii=0;ii<ntraces;ii+=1)
		trace = pop[p][ii]
		
		Histogram /c/b=3 trace, Histo
		wavestats /q/m=1 histo
		bl = v_maxloc
		
		NorPop[][ii] = (trace[p] - bl) / bl 
		w_bl[ii]=bl
	
	endfor
	
	Duplicate /o NorPop, $resultname
	if(BaseLineWave)
		Duplicate/o w_bl, $BLName
	endif
	
	Wave w=$ResultName
	Return w
End

////////////////////////////////////////////

Function/Wave BaseLineFromNor(Pop,NorPop,[ResultName])
	Wave Pop, NorPop
	String ResultName
	
	if(ParamIsDefault(ResultName))
		ResultName=NameOfWave(Pop)+"_BL"
	endif
	
	Variable YDim=DimSize(Pop,1),ii
	if(YDim==0)
		YDim=1
	endif
	
	Make/o/free/n=(YDim) w_BL=NaN
	
	For(ii=0;ii<YDim;ii+=1)
		w_BL[ii]=pop[0][ii]/(NorPop[0][ii]+1)
	
	EndFor
	
	Duplicate/o w_BL $ResultName
	Wave w=$ResultName
	Return w
End
	
	
////////////////////////////////////////////

Function/wave NormalizePoPByInterval(Pop,start,stop)					//performs normalization based on a specified baseline interval
	Wave pop
	Variable start, stop													//start and stop are scaled numbers (i.e. seconds)
	
	Duplicate/o/free Pop NormPop
	
	Variable nROIs=DimSize(Pop,1), ii, startP, stopP
	
	StartP = round((start - DimOffset(Pop, 0))/DimDelta(Pop,0))		//calculate point from scaled position
	StopP = round((stop - DimOffset(Pop, 0))/DimDelta(Pop,0))
	
	
	For(ii=0;ii<nROIs;ii+=1)
	
		ImageStats/g={startP,stopP,ii,ii}/m=1 Pop
		
		NormPop[][ii]=(Pop[p][ii]-v_avg)/v_avg	
	
	EndFor
	
	
	String ResultName = NameOfWave(pop)+"_iNor"
	Duplicate/o NormPop $ResultName
	
	Return $Resultname
End