#pragma rtGlobals=1		// Use modern global access method.
#include "EqualizeScaling"
#include "ResultsByCoef"
#include "MultiROI"

//Update 20100311: added ROI2cat, coef2cat
//Update 20100418: added CoMbyROI and CoMbyROICP
//Update 20111202: added CoMbyImage


Function ResultsByCoef(data,coef)
wave data, coef

variable ii, points

make /d/o /n=1 Results
points=numpnts(coef)
for (ii=0;ii<points;ii+=1)

results[ii]={data[coef[ii]]}

endfor

SetScale d,-inf,inf,WaveUnits(data,-1) Results

end

///////////////////////////

Function CoMByCoef(CoM, coef)
wave com, coef
variable ii, points
make /d/o/n=(1,2) CbC
points=numpnts(coef)
for (ii=0;ii<points;ii+=1)

	CbC[ii][0]={CoM[coef[ii]][0]}
	CbC[ii][1]={CoM[coef[ii]][1]}

endfor
SetScale d,-inf,inf,WaveUnits(CoM,-1) CbC

end

///////////////////////////

Function ResultsByCat(data,catWave,category)
wave data, catWave
variable category

variable ii, counter=0, points

points=NumPnts(data)
make /d/o /n=1 Results

for (ii=0;ii<points;ii+=1)

	if(catWave[ii]==category)
		results[counter]={data[ii]}
		counter +=1
	endif


endfor

SetScale d,-inf,inf,WaveUnits(data,-1) Results

end

///////////////////////////

Function CoMByLayer(Positions, CoM, Layers)
wave Positions,CoM, Layers

//Layers = {x0, width(x0), x1, width(x1),...xn, width(xn)}

Variable NumLayers = NumPnts(Layers)
Variable NumTerminals=NumPnts(Positions)
Variable ii, jj, counter

Make /d/o/n=(NumTerminals,2,NumLayers/2) CoMPoP=NaN



For(jj=0;jj<NumLayers;jj+=2)
	counter=0
	For(ii=0;ii<numTerminals;ii+=1)

		If((positions[ii] <= Layers[jj] + (Layers[jj+1]/2)) && (positions[ii] >= Layers[jj] - (Layers[jj+1]/2)))
		
			CoMPoP[counter][0][jj]=CoM[ii][0]
			CoMPoP[counter][1][jj]=CoM[ii][1]
		
			Counter +=1
		endif

	EndFor
EndFor
End

///////////////////////////

Function/Wave PopByCat(Pop,catWave,category)
	wave Pop, catWave
	variable category
	
	variable ii, counter=0, points, traces
	
	points=DimSize(Pop,0)
	traces=DimSize(Pop,1)
	make /d/o /n=(points) Results
	
	for (ii=0;ii<traces;ii+=1)
	
		if(catWave[ii]==category)
			results[][counter]={0}				//adding a new row
			results[][counter]=Pop[p][ii]
			counter +=1
		endif
	
	endfor
	
	CopyScaling(Pop,Results)
	
	Return Results
end

///////////////////////////

Function PopByCoef(Pop,Coef)
wave Pop, Coef


variable ii, points, traces

points=DimSize(Pop,0)
traces=NumPnts(Coef)
 
Duplicate /o pop, Results
Redimension /n=(-1,traces) Results

for (ii=0;ii<traces;ii+=1)

		results[][ii]=Pop[p][Coef[ii]]
		
endfor

end

///////////////////////////

Function/Wave CoMByCat(CoM, CatWave,Category)
	wave com, CatWave
	Variable Category
	
	variable ii, points, num, index
	
	points=DimSize(CatWave,0)
	Duplicate/o CoM CbC
	redimension/n=(1,2) CbC
	
	for(ii=0;ii<points;ii+=1)
		index=CatWave[ii]
		
		if(index==category)
			CbC[num][0]={CoM[ii][0]}
			CbC[num][1]={CoM[ii][1]}
			num+=1
		endif
	
	EndFor
	
	
	return CbC

end

///////////////////////////

Function/wave ROIByCat(ROIWave,CatWave,Category)
	Wave ROIWave, CatWave
	Variable Category

	variable ii, points, num, index
	points=DimSize(CatWave,0)

	Duplicate/o ROIWave ROIbC 
	FastOP ROIbC=0
	
	for(ii=0;ii<points;ii+=1)
		index=CatWave[ii]
		
		if(index==category)
			MultiThread ROIbC=SelectNumber(ROIWave[p][q]==-ii-1,ROIbC[p][q],-1)
			num+=1
		endif
	
	EndFor


End

///////////////////////////

Function/wave ROI2Cat(ROIWave,CatWave,[Bkgr])
	Wave ROIWave, CatWave
	Variable Bkgr

	if(paramisdefault(Bkgr))
		Bkgr=-1
	endif

	variable ii, points, num, index
	points=DimSize(CatWave,0)

	Duplicate/o ROIWave ROI2C 
	FastOP ROI2C=(Bkgr)
	
	
	
	for(ii=0;ii<points;ii+=1)
		index=CatWave[ii]
		
		MultiThread ROI2C=SelectNumber(ROIWave[p][q]==-ii-1,ROI2C[p][q],index)
		
	
	EndFor


End

///////////////////////////

Function ROIByCoef(ROIWave, coef)
	Wave ROIWave, Coef
	
	variable nCoef, ii, ROINr
		
	nCoef = dimSize(coef,0)
	
	Duplicate /o ROIWave, ROIbCoef
	FastOP ROIbCoef = 0
	
	For(ii=0;ii<nCoef;ii+=1)
	
		ROINr = -coef[ii] - 1
		MatrixOP /o/free loc = equal(ROIWave, ROINr)	//binary mask for current ROI
	
		ROIbCoef+=loc			//binary mask for all ROIs
	
	EndFor
		
		ROIbCoef*=ROIWave		//restore ROI values
		
End

///////////////////////////

Function Coef2Cat(coef,n, val)
	Wave coef
	variable n, val
	
	variable ii, nCoef, wm
	
	wm=WaveMax(Coef)
	
	if(wm>n)
		Print "Error"
		Printf "Increasing n to match max. Coef value to %g\r", wm
		n=wm
	endif
	
	nCoef=DimSize(Coef,0)
	
	Make/o/n=(n) C2C=0
	
	for(ii=0;ii<nCoef;ii+=1)
	
		C2C[Coef[ii]]=val
	
	endfor
	
	
end
	
	
	
///////////////////////////

Function/wave CoMbyROI(CoM, ROI)
	wave CoM, ROI
	
	variable nCoMs, xScale, xOff, yScale, yOff, ii, ROIVal, xPos, yPos
	
	nCoMs=DimSize(CoM,0)
	xScale=DimDelta(ROI,0)
	xOff=DimOffset(ROI,0)
	yScale=DimDelta(ROI,1)
	yOff=DimOffset(ROI,1)
	
	Make /o/n=(nCoMs) w_CoMbyROI
	
	for(ii=0;ii<nCoMs;ii+=1)
	
		xPos = round((CoM[ii][0] - xOff)/xScale)
		yPos = round((CoM[ii][1] - yOff)/yScale)
		
		ROIVal = ROI[xPos][yPos]
		
		if(ROIVal > -1)			
			 w_CoMbyROI[ii]=NaN		//CoM is outside any ROI
		else
			 w_CoMbyROI[ii]=-ROIVal-1
		endif
	
	endfor
	
	return w_CoMbyROI
end

///////////////////////////////////////////////////////////

Function CoMbyROICP()

	string BaseName, PlayerName, PlayerImageName
	variable nDilate=0, nCols, ii
	
	
	Prompt BaseName, "Select the base ROI wave", popup, WaveList("*",";","DIMS:2")
	Prompt PlayerName, "Select the players ROI or CoM wave", popup, WaveList("*",";","DIMS:2")
	Prompt PlayerImageName, "Select the players image wave", popup, "_none_;"+WaveList("*",";","DIMS:2")
	Prompt nDilate, "Dilate the base ROI?"
	
	doPrompt "CoM by ROI" BaseName, PlayerName, PlayerImageName, nDilate
	
	if(v_flag)		//clicked "Cancel"
		return -1
	endif
	
	wave BaseWave=$BaseName
	wave PlayerWave=$PlayerName
	
	nCols=DimSize(PlayerWave,1)
	
	if(nCols==2)
		Wave CoMWave=PlayerWave
	elseif(stringmatch(PlayerImageName, "_none_"))
		GeometricCenter(PlayerWave)
		wave  CoMWave = :GeoC
	else
		wave ImageWave=$PlayerImageName
		CenterOfMass_custom(ImageWave, PlayerWave)
		wave CoMWave = :CoM	
	endif
	
	if(nDilate)
	
		Duplicate/o BaseWave, input
	
		For(ii=0;ii<=nDilate;ii+=1)
	
			wave output=MorphROI(input, 1)
			
			input=output
			
			killwaves/z output
	
		EndFor
		
		Wave ROIWave=input
	else
		Wave ROIWave=BaseWave
	endif
	
	wave result= CoMbyROI(CoMWave, ROIWave)
	
	edit result
	
end



/////////////////////////////////////////////////////////

Function CoMsByClusters(CoM, Clusters, [BaseName])
	Wave CoM, Clusters
	string BaseName
	
	if (ParamIsDefault(BaseName))
		BaseName = "CoM"
	endif
	
	variable nCoM, nClusters, ii, counted, jj, kk=0
	String CoMName

	nCoM = numpnts(CoM) 
	nClusters = WaveMax(Clusters)
	
	
	For(ii=0;ii<nClusters;ii+=1)
		kk=0
		CoMName = BaseName + Num2Str(ii)
		
		MatrixOP/o/free Counter = equal(Clusters, ii)
		counted = sum(Counter)
		
		Make /o/free/n=(counted,2) NewCoM
		
		For(jj=0;jj<nCoM;jj+=1)
			
			if(Clusters[jj]==ii)
				NewCoM[kk][]=CoM[jj][q]
				kk+=1
			endif
		
		EndFor
		
		Duplicate/o NewCoM, $CoMName
	EndFor
	
	
End

////////////////////////////////////////////////////////

Function/wave CoMbyImage(CoM, Image,[resultname])		//Returns the pixel value of Image for each CoM. Multithreaded
	Wave CoM, Image
	String ResultName
	
	Variable nCoM, xDelta, yDelta, xOff, yOff
	
	If(ParamIsDefault(ResultName))
		ResultName="CbI"
	Endif
	
	xDelta=DimDelta(Image,0)
	yDelta=DimDelta(Image,1)
	xOff=DimOffset(Image,0)
	yOff=DimOffset(Image,1)
	
	nCoM = DimSize(CoM,0)
	
	Make/o/free/n=(nCoM) CbI2
	
	MultiThread CbI2 = CbI_Worker(CoM, Image, p, xDelta, yDelta, xOff, yOff)
	
	Duplicate/o CbI2 $ResultName
	
	Return $ResultName
End

//Worker function for CoMByImage
Threadsafe Static Function CbI_Worker(CoM,Image,ii, xDelta, yDelta, xOff, yOff)
	Wave CoM, Image
	Variable ii, xDelta, yDelta, xOff, yOff
	
	Variable Result, xpnt, ypnt

	
	xpnt=round((CoM[ii][0]-xOff)/xDelta)
	ypnt=round((CoM[ii][1]-yOff)/yDelta)

	Result=Image[xpnt][ypnt]
	
	Return Result
End
