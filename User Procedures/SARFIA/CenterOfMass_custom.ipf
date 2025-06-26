#pragma rtGlobals=1		// Use modern global access method.

//Update 08062011: Added dimoffset if image to CoM
//Update 27062011: Added function CoMDistances2
//Update 20052014: Added CenterOfMass3D

//////////////////////////////////////////////////////////////////
//																			//
//	CenterOfMass(image,ROI) calculates the center of mass for ROIs			//
//	based on the image. The ROI wave endcodes the number of ROIs with		//
//	increasing negative numbers; 1 is outside of ROIs						//
//																			//
//	ShortestDistance(func, relX, relY) calculates the shortest distance 		//
//	between a function func (1D wave) and a point. The wave has to be		//
//	scaled, as have the points.												//
//																			//
//	ShortestDistance2(xfunc,yfunc, relX, relY) works as above, only			//
//	that the input is yfunc vs xfunc. Waves and points have to be scaled.		//
//																			//
//	DrawCoMNumbers(CoMWave, bgimg, WindowName, [fontsize])			//
//	Draws the ROI numbers as stored in COMWave at the position of 			//
//	the center of mass in WindowName. bgimg is needed to get the dimensions	//
//	of the background image, which should be displayed in WindowName.		//
//	Fontsize is optional and useful for very large images, as fonts don't		//
//	scale when the image size is changed.										//
//																			//
//	CoMDistances(CoM, [index]) calculates the (scaled) distances between	//
//	all CoMs in wave CoM and returns the result as the matrix DistanceMatrix//
//	The optional parameter index can be used to spexify the layer of a 		//
//	compound CoM wave (as returned by the operation ComByLayer.			// 
//																			//
//	DistanceMatrix2Column (DistanceMatrix) puts all distances of the 		//
//	distancematrix DistanceMatrix in a single column of the wave DM2C, 		//
//	so that these date can be used for a histogram etc.							//
//																			//
// 	GeometricCenter (ROI) calculates the geometric center for ROIs in the 		//
// 	MultiROI ROI wave ROI. The result will be stored in the two-dimenasional 	//
// 	wave GeoC. GeoC[][0] contains the scaled X data, GeoC[][1] contains the	//
//  	scaled Y data. The precision of CoM is higher than that of pixels in ROI.		//
//																		//
//	CoMDistances2(CoM1,CoM2)	calculates the (scaled) distances between	//
//	all CoMs in wave CoM1 and all CoMs in wave CoM2 and returns the result 	//
//	as the matrix DistanceMatrix											//
/////////////////////////////////////////////////////////////////



Function CenterOfMass_custom(image,ROI)

	wave image, roi
	
	if (dimsize(image, 0) != dimsize(ROI,0))
		return -1
	elseif (dimsize(image, 1) != dimsize(ROI,1))
		return -1
	endif
	
	variable ROInumber, Xcounter, Ycounter, number, xDim, yDim, xDelta, yDelta
	imagestats /m= 1 ROi
	ROInumber = -v_min
	
	xDim = dimsize(ROI,0)
	yDim = dimsize(ROI,1)
	xDelta = DimDelta(image,0)
	yDelta = DimDelta(image,1)
	
	make /o/free/n=(ROinumber, 3) data=0
	
	 for(Xcounter=0;Xcounter<xDim;Xcounter+=1)
	 	 for(Ycounter=0;Ycounter<yDim;Ycounter+=1)
	 	
	 		if(ROI[xcounter][ycounter] < 0)
	 		
	 			number=-ROI[xcounter][ycounter]-1
	 			data[number][0]+=xcounter*image[xcounter][ycounter]	//weighted by intensity
	 			data[number][1]+=ycounter*image[xcounter][ycounter]	//weighted by intensity
	 			data[number][2]+=image[xcounter][ycounter]				//Sum of pixel intensities in ROI
	 		
	 		endif
	 	
	 	endfor
	 endfor
	
	make /o/n=(ROInumber, 2) CoM=0
	SetScale d,0,1,WaveUnits(image,0) CoM
	
	
		MultiThread CoM[][0]=data[p][0]/data[p][2]*xDelta
		MultiThread CoM[][1]=data[p][1]/data[p][2]*yDelta
		
		CoM[][0]+=DimOffset(image,0)
		CoM[][1]+=DimOffset(image,1)

	return (waveexists(CoM))
end

///////////////////////////////////////////

Function CenterOfMass3D(image,ROI)

	wave image, roi
	
	if (dimsize(image, 0) != dimsize(ROI,0))
		return -1
	elseif (dimsize(image, 1) != dimsize(ROI,1))
		return -1
	elseif (dimsize(image, 2) != dimsize(ROI,2))
		return -1
	endif
	
	variable ROInumber, Xcounter, Ycounter, Zcounter, number, xDim, yDim, zDim, xDelta, yDelta, zDelta
	wavestats /q/m= 1 ROi
	ROInumber = -v_min
	
	print roinumber
	
	xDim = dimsize(ROI,0)
	yDim = dimsize(ROI,1)
	zDim = dimsize(ROI,2)
	xDelta = DimDelta(image,0)
	yDelta = DimDelta(image,1)
	zDelta = DimDelta(image,2)
	
	make /o/free/n=(ROinumber, 4) data=0
	
	 for(Xcounter=0;Xcounter<xDim;Xcounter+=1)
	 	 for(Ycounter=0;Ycounter<yDim;Ycounter+=1)
	 	 	for(Zcounter=0;Zcounter<zDim;Zcounter+=1)
	 	
	 		if(ROI[xcounter][ycounter][zcounter] < 0)
	 		
	 			number=-ROI[xcounter][ycounter][zcounter]-1
	 			data[number][0]+=xcounter*image[xcounter][ycounter][zcounter]	//weighted by intensity
	 			data[number][1]+=ycounter*image[xcounter][ycounter][zcounter]	//weighted by intensity
	 			data[number][2]+=zcounter*image[xcounter][ycounter][zcounter]	//weighted by intensity
	 			data[number][3]+=image[xcounter][ycounter][zcounter]			//Sum of pixel intensities in ROI
	 		
	 		endif
	 		
	 		endfor
	 	endfor
	 endfor
	
	make /o/n=(ROInumber, 3) CoM=0
	SetScale d,0,1,WaveUnits(image,0) CoM
	
	
		MultiThread CoM[][0]=data[p][0]/data[p][3]*xDelta
		MultiThread CoM[][1]=data[p][1]/data[p][3]*yDelta
		MultiThread CoM[][2]=data[p][2]/data[p][3]*zDelta
		
		CoM[][0]+=DimOffset(image,0)
		CoM[][1]+=DimOffset(image,1)
		CoM[][2]+=DimOffset(image,2)

	return (waveexists(CoM))
end

///////////////////////////////////////////

Function ShortestDistance(func, relX, relY)

//relX/Y use absolute numbers, not points!

wave func
variable relX, relY

variable counter, offset, delta

duplicate /o func, dist
setscale /p x,dimoffset(func,0), dimdelta(func,0), waveunits(func,0) dist
dist = 0


offset=dimoffset(func,0)
delta=dimdelta(func,0)

MultiThread dist=sqrt((offset+p*delta-relx)^2 + (func[p] - rely)^2)		//dist is the Euclidean distance between all the points in func and (relX,relY)


variable result = wavemin(dist)		//look for the shortest distance
killwaves /z dist

return result							//return shortest distance

end


///////////////////////////////////////////

Threadsafe Function ShortestDistance2(xfunc,yfunc, relX, relY)

//relX/Y use absolute numbers, not points!

wave xfunc, yfunc
variable relX, relY

variable counter

duplicate /o xfunc, dist
dist = 0


MultiThread dist=sqrt((xfunc[p]-relX)^2+(yfunc[p]-relY)^2)	//dist is the Euclidean distance between all the points (xFunc,yFunc) and (relX,relY)

variable result = wavemin(dist)
killwaves /z dist

return result

end

//////////////////////////////////////////////////////////////////

Function DrawCoMNumbers(CoMWave, bgimg, WindowName, [fontsize, TextRot])

wave ComWave, bgimg
string windowName
variable fontsize, TextRot

variable counter, xpos, ypos

if (paramisdefault(fontsize))
	fontsize = 10
endif

if(ParamIsDefault(TextRot))
	textrot = 0
endif

variable xDim, yDim, xDelta, yDelta, ComNum
xDim=dimsize(bgimg,0)
yDim=dimsize(bgimg,1)
xDelta=dimdelta(bgimg,0)
yDelta=dimdelta(bgimg,1)
CoMNum=dimsize(CoMWave,0)

for (counter=0; counter<CoMNum;counter +=1)

	xpos = ComWave[counter][0]/(xDim*xDelta)
	ypos = 1-comwave[counter][1]/(yDim*yDelta)		//comment if origin is upper left
//	ypos =  comwave[counter][1]/(yDim*yDelta)			//uncomment if origin is upper left
	setdrawEnv /w=$windowname textRGB=(65535,0,0), textrot=TextRot, fstyle = 0, fsize = fontsize, fname="Helvetica"
	
	drawtext /w=$windowname xpos,ypos, num2str(counter)


endfor


end

//////////////////////////////////////////////////////////////////

Function/wave CoMDistances(CoM,[index])
	wave CoM
	variable index
	
	Variable CoMNumber=Dimsize(CoM,0)
	
	make /o/n=(CoMNumber,CoMNumber) DistanceMatrix
	
	setscale d,0,1,WaveUnits(CoM,-1) DistanceMatrix 
	
	if (paramisdefault(index))
	
		MultiThread DistanceMatrix = sqrt((Com[p][0]-CoM[q][0])^2+(Com[p][1]-CoM[q][1])^2)
	
	else				//CoMPoP
		
		MultiThread DistanceMatrix = sqrt((Com[p][0][index]-CoM[q][0][index])^2+(Com[p][1][index]-CoM[q][1][index])^2)
		
	endif

	return DistanceMatrix
End

//////////////////////////////////////////////////////////////////

Function/wave CoMDistances3D(CoM,[index])
	wave CoM
	variable index
	
	Variable CoMNumber=Dimsize(CoM,0)
	
	make /o/n=(CoMNumber,CoMNumber) DistanceMatrix
	
	setscale d,0,1,WaveUnits(CoM,-1) DistanceMatrix 
	
	if (paramisdefault(index))
	
		MultiThread DistanceMatrix = sqrt((Com[p][0]-CoM[q][0])^2+(Com[p][1]-CoM[q][1])^2+(Com[p][2]-CoM[q][2])^2)
	
	else				//CoMPoP
		
		MultiThread DistanceMatrix = sqrt((Com[p][0][index]-CoM[q][0][index])^2+(Com[p][1][index]-CoM[q][1][index])^2+(Com[p][2][index]-CoM[q][2][index])^2)
		
	endif

	return DistanceMatrix
End

//////////////////////////////////////////////////////////////////

Function/Wave DistanceMatrix2Column(DistanceMatrix,[Index])
	wave distancematrix
	Variable Index
	
	If(ParamIsDefault(Index))
		Index=0
	Endif

	variable CoMNum=Dimsize(DistanceMatrix, 1)
	variable NumLines =ComNum*(Comnum+1)/2
	variable ii,jj=0, offset=0, kk=0
	
	Make /o/n=(NumLines,3) DM2C
	SetScale /p y,0,1,WaveUnits(DistanceMatrix, -1) DM2C
	DM2C=NaN
	
	
	
	ii=0
	Do
	
		if(mod(ii,ComNum) == 0 && ii > 0)
			jj+=1
			ii+=jj
		endif
		
		If(mod(ii, ComNum)==jj)
			DM2C[kk][0]=NaN
		else
			DM2C[kk][0]=DistanceMatrix[mod(ii, ComNum)][jj]			
		endif
		
		DM2C[kk][1]=mod(ii, ComNum)
		DM2C[kk][2]=jj
		
		ii+=1
		kk+=1
		While(kk<NumLines)	

	If(Index==0)
		Redimension/n=(-1) DM2C
	EndIf
	
	Return DM2C
End

//////////////////////////////////////////////////////////////////


Function GeometricCenter(ROI)

wave roi


variable ROInumber, Xcounter, Ycounter, number, xDim, yDim, xDelta, yDelta
imagestats /m= 1 ROi
ROInumber = -v_min


xDim = dimsize(ROI,0)
yDim = dimsize(ROI,1)
xDelta = DimDelta(ROI,0)
yDelta = DimDelta(ROI,1)

make /o/n=(ROinumber, 3) data=0

 for(Xcounter=0;Xcounter<xDim;Xcounter+=1)
 	 for(Ycounter=0;Ycounter<yDim;Ycounter+=1)
 	
 		if(ROI[xcounter][ycounter] < 0)
 		
 			number=-ROI[xcounter][ycounter]-1
 			data[number][0]+=xcounter
 			data[number][1]+=ycounter
 			data[number][2]+=1										//Number of pixels in ROI
 		
 		endif
 	
 	endfor
 endfor

make /o/n=(ROinumber, 2) GeoC=0
SetScale d,0,1,WaveUnits(ROI,0) GeoC


	MultiThread GeoC[][0]=data[p][0]/data[p][2]*xDelta
	MultiThread GeoC[][1]=data[p][1]/data[p][2]*yDelta

killwaves /z data
return (waveexists(GeoC))
end

//////////////////////////////////////////////////////////////////

Function/wave CoMDistances2(CoM1,CoM2)		//Calculate distances between 2 CoMs
	wave CoM1, CoM2
	variable index
	
	Variable CoM1Number=Dimsize(CoM1,0)
	Variable CoM2Number=Dimsize(CoM2,0)
	
	make /o/n=(CoM1Number,CoM2Number) DistanceMatrix
	
	
	
		MultiThread DistanceMatrix = sqrt((Com1[p][0]-CoM2[q][0])^2+(Com1[p][1]-CoM2[q][1])^2)
	


	return DistanceMatrix
End

//////////////////////////////////////////////////////////////////