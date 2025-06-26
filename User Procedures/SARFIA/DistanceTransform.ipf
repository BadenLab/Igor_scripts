#pragma rtGlobals=3		// Use modern global access method and strict wave access.


//Update 27/11/2011: Added optional parameter resultname
//Update 23/10/2015: Added optional parameter mask


/////////////////////////////////////////////////////////////////////////////////////////											//
// These functions calculate a distance transform of a 2D or 3D binary wave. For every pixel with a value		//
// of 0, the distance to the closest pixel with the value of 1 will be calculated. The output can be Euclidean 	//
// distances in pixels, Manhattan distances in pixels or scaled Euclidean distances.						//
//																								//
// Note: These functions use a very slow algorithm. Although the functions are multithreaded, processing 	//
// large waves will take a very, very long time. Processing speed can be increased by calculating the 		//
// distance transform of a pixelated wave and then resampling the result, using the ImageInterpolate 		//
// function with the pixelate and resample keywords, respectively.  										//
//																								//
// DistanceTransform (image,metric) Calculates the distance transform of the 2D or 3D wave image, 		//
// which must be binary, i.e. contain only 0 and 1. Metric can be 0 (Euclidean distances in pixels), 			//
// 1 (Manhattan distances in pixels), or 2 (scaled Euclidean distances). Scaling does work, even if pixels 	//
//  are not quadratic (or cubic).																		//
//																								//
// The oprional parameter resultname is a string which will be the name of the resulting wave, default is		//
// NameOfWave(image) + "_DT"																	//
//																								//
// The optional parameter mask is a wave with the same dimensions as image. All pixels with a value of 0	//
// in the mask will be skipped for analysis, the result will be NaN. This may considerably reduce the number	//
// of pixels to be analyzed and thereby speed up the processing time.									//
/////////////////////////////////////////////////////////////////////////////////////////											//





Function DistanceTransform(image,metric,[mask, resultname])
	Wave image	//must be binary, i.e. only values of 0 and 1
	Variable Metric //0=Euclidean (pixel-based), 1=Manhattan, 2=Euclidean (scaled)
	Wave mask
	String resultname
	
	Variable WD = WaveDims(image), wmin, wmax
	
	wmin=WaveMin(image)
	wmax=WaveMax(image)
	
	if(wmin != 0 || wmax != 1)
		printf "%s is not a binary wave\r",NameOfWave(image)
		return 1
	endif
	
	If(ParamIsDefault(mask))
		Duplicate/o/free image, mask
		FastOP mask = 1
	endif
	
	Switch (WD)
		Case 0:
			Return 1
		Break
	
		Case 1:
			Return 1
		Break
		
		Case 2:
					
			If(ParamIsDefault(Resultname))
				DistanceTransform2DMask(image,metric,mask=mask)
			Else
				DistanceTransform2DMask(image,metric,mask=mask,resultname=resultname)
			Endif
		Break
		
		Case 3:
			If(ParamIsDefault(Resultname))
				DistanceTransform3DMask(image,metric,mask=mask)
			Else
				DistanceTransform3DMask(image,metric,mask=mask,resultname=resultname)
			Endif
		Break
		
		Case 4:
			Print "Not yet implemented"
			Return 1
		Break
	
	
	EndSwitch
	
	Return 0
End



///////////////////////////////////////////////////////////////////////////////////


Static Function DistanceTransform2DMask(image,metric,[mask, resultname])					//calculates distance transform of binary image image
	Wave image	//must be binary, i.e. only values of 0 and 1
	Variable Metric //0=Euclidean (pixel-based), 1=Manhattan, 2=Euclidean (scaled)
	Wave mask
	string resultname
	
	variable xDim, yDim, ii, xLoc, yLoc, xDelta, yDelta
	Variable error,x1,x2,y1,y2
	String errorStr
	
	If(ParamIsDefault(resultname))
		resultname = NameOfWave(image) + "_DT"		//name of resulting wave
	Endif
	
	If(ParamIsDefault(mask))
		duplicate/o/free image, mask		//generate mask
		FastOP mask = 1				//set all 1's (analyze all pixels)
	else	
		if(DimSize(image,0)!=DimSize(mask,0))
			error+=1
		endif
		
		if(DimSize(image,1)!=DimSize(mask,1))
			error+=1
		endif
		
		if(error)
			x1=DimSize(image,0)
			x2=DimSize(mask,0)
			y1=DimSize(image,1)
			y2=DimSize(mask,1)
			sprintf errorStr, "Mismatch between image and mask dimensions in function DistanceTransform2DMask:\rx1=%g\rx2=%g\ry1=%g\ry2=%g",x1,x2,y1,y2
			Abort errorstr
		endif
		
	Endif
	
	
	xDim=DimSize(image,0)
	yDim=DimSize(image,1)
	xDelta = DimDelta(image,0)
	yDelta = DimDelta(image,1)
	
	Duplicate/o/free image, calc, DM
	Duplicate/o image,$resultname
	Wave DT=$resultname					//Distance Transform
	redimension/s DT
	MatrixOP/o calc = image / image			//Make 0 to NaN
	
	Make/o/free/n=(2*xDim+1,2*yDim+1) DMcent		//centered distance map to serve as a master
	
	//Calculate distances of centered distance map
	Switch(metric)
		Case 0:	//Euclidean
			MultiThread DMcent=sqrt((p-xDim)^2+(q-yDim)^2)
		break	
		
		Case 1://Manhattan
			MultiThread DMcent=(abs(p-xDim)+abs(q-yDim))
		break		
		
		Case 2:	//scaled Euclidean
			MultiThread DMcent=sqrt(((p-xDim)*xDelta)^2+((q-yDim)*yDelta)^2)
		break
			
		Default:		//Euclidean
			Print "Using Euclidean metric."
			MultiThread DMcent=sqrt((p-xDim)^2+(q-yDim)^2)
		Break
		
	EndSwitch
	
	MultiThread DT=distAssignMask(p,q,xdim,ydim,image,DMcent,calc,mask)
	return 0
End


ThreadSafe Static function distAssignMask(ii,jj,xdim,ydim,image,DMcent,calc,mask)
	Variable ii,jj,xdim,ydim
	Wave image,DMcent,calc, mask
	
	if(image[ii][jj])	
		return 0
	elseif(mask[ii][jj]==0)	
		return NaN
	endif
	
	
	Duplicate/o/free/r=[xDim-ii,2*(xDim)-ii-1][yDim-jj,2*(yDim)-jj-1] DMcent DM	
	MatrixOP/o/free DM2=DM*calc		
	return WaveMin(DM2)	 
End



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Function DistanceTransform3DMask(image,metric,[mask,resultname])					//calculates distance transform of binary volume image
	Wave image	//must be binary, i.e. only values of 0 and 1
	Variable Metric //0=Euclidean (pixel-based), 1=Manhattan, 2=Euclidean (scaled)
	Wave mask
	string resultname 		//name of resulting wave
	
	variable xDim, yDim, zDim,ii, xLoc, yLoc, xDelta, yDelta, zDelta
	Variable error = 0
	
	If(ParamIsDefault(resultname))
		resultname = NameOfWave(image) + "_DT"		//name of resulting wave
	Endif
	
	If(ParamIsDefault(mask))
		duplicate/o/free image, mask		//generate mask
		FastOP mask = 1				//set all 1's (analyze all pixels)
	else	
		if(DimSize(image,0)!=DimSize(mask,0))
			error+=1
		endif
		
		if(DimSize(image,1)!=DimSize(mask,1))
			error+=1
		endif
		
		if(DimSize(image,2)!=DimSize(mask,2))
			error+=1
		endif
		
		if(error)
			Abort "Mismatch between image and mask dimensions in function DistanceTransform3DMask."
		endif
		
	Endif
	
	xDim=DimSize(image,0)
	yDim=DimSize(image,1)
	zdim=DimSize(image,2)
	xDelta = DimDelta(image,0)
	yDelta = DimDelta(image,1)
	zDelta=DimDelta(image,2)
	
	Duplicate/o/free image, calc, DM
	Duplicate/o image,$resultname
	Wave DT=$resultname					//Distance Transform
	redimension/s DT
	MatrixOP/o calc = image / image			//Make 0 to NaN
	
	Make/o/free/n=(2*xDim+1,2*yDim+1,2*zDim+1) DMcent		//centered distance map to serve as a master
	
	//Calculate distances of centered distance map
	Switch(metric)
		Case 0:	//3D Euclidean
			MultiThread DMcent=sqrt((p-xDim)^2+(q-yDim)^2+(r-zDim)^2)
		break	
		
		Case 1://3D Manhattan
			MultiThread DMcent=(abs(p-xDim)+abs(q-yDim)+abs(r-zDim))	
		break		
		
		Case 2:	//3D scaled Euclidean	
			MultiThread DMcent=sqrt(((p-xDim)*xDelta)^2+((q-yDim)*yDelta)^2+((r-zDim)*zDelta)^2)
		break
		
		Default:		//3D Euclidean
			Print "Using Euclidean metric."
			MultiThread DMcent=sqrt((p-xDim)^2+(q-yDim)^2+(r-zDim)^2)
		Break
		
	EndSwitch
	
	MultiThread DT=distAssign3DMask(p,q,r,xdim,ydim,zDim,image,DMcent,calc,Mask)
	return 0
End


ThreadSafe Static function distAssign3DMask(ii,jj,kk,xdim,ydim,zDim,image,DMcent,calc,Mask)
	Variable ii,jj,kk,xdim,ydim,zDim
	Wave image,DMcent,calc,Mask
	
	if(image[ii][jj][kk])	
		return 0
	elseif(mask[ii][jj][kk]==0)
		return NaN
	endif	
	
	Duplicate/o/free/r=[xDim-ii,2*(xDim)-ii-1][yDim-jj,2*(yDim)-jj-1][zDim-kk,2*(zDim)-kk-1] DMcent DM	
	MatrixOP/o/free DM2=DM*calc		
	return WaveMin(DM2)	 
End

