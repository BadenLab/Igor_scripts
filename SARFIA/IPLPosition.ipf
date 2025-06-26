#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

#include "CenterOfMass_custom"
#include "NaNBust"

//Update 18/06/2010: Added MeasureDistancesFromPercentiles, slightly sped up MeasureDistances
//Update 10/12/2010: Repaired functions MeasureDistances and MeasureDistancesFromPercentiles
//Update 10/12/2010: Aded function DrawCoMPositions

////////////////////////////////////////////////////////////////////////
//																					//
//	QuickPA(image, size, method) finds the borders of an object 						//
//	applying the inbuilt functions ImageThreshold and 								//
//	ImageAnalyzeParticles and then extracting the two longest contingent				//
//	borders as waves TopY vs TopX and Bottomy vs BottomX. Size is the minimum		//
//	area in pixels that objects (i.e. the IPL) will have. It even cleans					//
//	up after itself.																	//
//																					//
//	MeasureDistances(CoM, BottomX, BottomY, Topx, TopY) returns the				//
//	Percentile closest to the center of mass (CoM) as wave Postitions. 				//
//	Bottom = 0 %, Top = 100 %														//
//																					//
//	 LineFunctionDist(PointX,PointY,k,Xfunc,Yfunc) returns the distance				//
//	 between a point PointY vs PointX and Yfunc vs Xfunc lying on a line 				//
//	pointY - k*PointX = d															//
//																					//
//	InterpAndLoess(XWave, YWave, interpNumber, [SmoothNumber]) inter-		//
//	polates linearly to interpNumber of points and then smoothes YWave				//
//	using locally-weighted regression smoothing with a factor of						//
//	SmoothNumber (0<SmoothNumber<1; default = 0.5)								//
//																					//
//	Reorder(xwave,ywave) orders Xwave/YWave pairs according to ascending		//
//	numbers in xwave.																//
//																					//
//	Horizontal(Xfunc, Yfunc) determines whether Yfunc vs Xfung is 					//
//	horizontal (1) or vertical (0)													//
//																					//
//  DrawCoMPositions(CoMWave, positions, bgimg, WindowName, [fontsize, TextRot])//
//  Draws the Positions as stored in positions at the position of 						//
//	the center of mass in WindowName. bgimg is needed to get the dimensions			//
//	of the background image, which should be displayed in WindowName.				//
//	Fontsize is optional and useful for very large images, as fonts don't				//
//	scale when the image size is changed.												//
////////////////////////////////////////////////////////////////////////



Function QuickPA(image, size, method, [level])
wave image
variable size, method, level

if(method)
	ImageThreshold/I/M=(method)/Q image
else
	if(paramisdefault(level))
		DoAlert 0, "Must specify a level with manual thresholding."
		return -1
	endif
	ImageThreshold/I /T=(level) /Q image
	Wave M_ImageThresh
endif

if(method==3)
	redimension /b/u M_ImageThresh
endif

ImageAnalyzeParticles /f/E/W/Q/M=0/A=(size) stats, M_ImageThresh
Wave w_boundaryx, w_boundaryy

duplicate /o w_boundaryx, IPLboundaryX
duplicate /o w_boundaryy, IPLboundaryY

if(numpnts(IPLBoundaryX) == 0 || numpnts(IPLBoundaryY) == 0)
	return -1
endif

variable ii, maxX, maxY


wavestats /m=1 /q IPLboundaryX
maxX = v_max
wavestats /m=1 /q IPLboundaryY
maxY = v_max





//removing extremes

//IPLboundaryX = SelectNumber(IPLboundaryX[p]==0,IPLboundaryX[p],NaN)
//IPLboundaryY = SelectNumber(IPLboundaryX[p]==0,IPLboundaryY[p],NaN)
//IPLboundaryX = SelectNumber(IPLboundaryY[p]==0,IPLboundaryX[p],NaN)
//IPLboundaryY = SelectNumber(IPLboundaryY[p]==0,IPLboundaryY[p],NaN)

MultiThread IPLboundaryX = SelectNumber(IPLboundaryX[p]==MaxX,IPLboundaryX[p],NaN)
MultiThread IPLboundaryY = SelectNumber(IPLboundaryX[p]==MaxX,IPLboundaryY[p],NaN)
MultiThread IPLboundaryX = SelectNumber(IPLboundaryY[p]==MaxY,IPLboundaryX[p],NaN)
MultiThread IPLboundaryY = SelectNumber(IPLboundaryY[p]==MaxY,IPLboundaryY[p],NaN)

//Extract junks
variable start=0, cnt=0, l1,l2, l3
string newname 
make /o/n=1 length =0
for (ii=0;ii<numpnts(IPLboundaryX);ii+=1)

	if(NumType(IPLBoundaryY[ii])==2 || NumType(IPLBoundaryX[ii])==2)
		newname="IPLcalcY"+num2str(cnt)
		duplicate /o/r=[start,ii] iplboundaryy, $newname
		newname="IPLcalcX"+num2str(cnt)
		duplicate /o/r=[start,ii] iplboundaryx, $newname
		length[cnt]={ii-start}
		start=ii+1
		cnt+=1
	endif	

endfor

wavestats /m=1/q length
l1=v_maxloc
replace(length,v_max,0)
wavestats /m=1/q length
l2=v_maxloc
replace(length,v_max,0)
wavestats /m=1/q length
l3=v_maxloc

newname="IPLcalcY"+num2str(l1)
duplicate /o $newname, TopY
newname="IPLcalcX"+num2str(l1)
duplicate /o $newname, TopX

newname="IPLcalcY"+num2str(l2)
duplicate /o $newname, BottomY
newname="IPLcalcX"+num2str(l2)
duplicate /o $newname, BottomX

newname="IPLcalcY"+num2str(l3)
duplicate /o $newname, ThirdY
newname="IPLcalcX"+num2str(l3)
duplicate /o $newname, ThirdX

//cleaning up
string kills=wavelist("IPLcalc*",";","")

for(ii=0;ii<itemsinlist(kills)+1;ii+=1)
	newname=stringfromlist(ii,kills)
	killwaves /z $newname
endfor

killwaves /z length, IPLboundaryX, IPLBoundaryY
Killwaves /z   M_ImageThresh,M_Moments,M_RawMoments,M_Particle
killwaves /z   W_ImageObjArea,W_SpotX,W_SpotY,W_circularity,W_rectangularity
killwaves/z W_ImageObjPerimeter,W_xmin,W_xmax,W_ymin,W_ymax,W_BoundaryX,W_BoundaryY,W_BoundaryIndex
return 1
end


//////////////////////////////////////////////////////////////////

Function InterpAndLoess(XWave, YWave, interpNumber, [DoLoess, SmoothNumber])
	wave xwave, ywave //result of GraphWaveDraw - WILL BE OVERWRITTEN
	variable interpNumber, DoLoess, SmoothNumber
	//interpNumber - number of points in the result
	//DoLoess - set to 0 for interpolation without smoothing
	//SmoothNumber - smoothing factor for Loess (see WM documentation)
	
	if(numpnts(Xwave) != numpnts(Ywave))
		Doalert 0, "X and Y wave must have the same number of points!"
		return -1
	endif
	
	if(paramisdefault(smoothnumber))
		smoothnumber = 0.5
	endif
	
	if(paramisdefault(DoLoess))
		DoLoess = 1
	endif
	
	
	Duplicate /o/free XWave, Xinterp
	Duplicate /o/free YWave, Yinterp
	
	interpolate2 /t=1 /n=(InterpNumber) /i=0 /y=XInterp Xwave
	interpolate2 /t=1 /n=(InterpNumber) /i=0 /y=YInterp YWave
	AbortOnRTE		//Abort if any interpolate2 fails
	
	if(DoLoess)
		Loess /V=0 /smth=(SmoothNumber) /z=1 /r factors={XInterp}, srcWave=YInterp
	endif
	
	
	
	string wvname
	wvname = nameofwave(xwave)
	duplicate/o XInterp $wvname
	wvname = nameofwave(ywave)
	duplicate/o yInterp $wvname
	
	
	if(v_flag)
		DoAlert 0, "Loess reported error "+num2str(v_flag)+"."
	endif

end

////////////////////////////////////////////////////////////////

function reorder(xwave,ywave)
	wave xwave, ywave

	if(numpnts(Xwave) != numpnts(Ywave))
		Doalert 0, "X and Y wave must have the same number of points!"
		return -1
	endif

//make /o /n=(numpnts(xwave)) xcalc = xwave
//duplicate/o xwave, xcalc
//duplicate /o ywave, ycalc
//variable ii
//
//for (ii=0;ii<numpnts(xwave);ii+=1)
//	
//	wavestats /m=1/q xcalc
//	xwave[ii] = v_min
//	ywave[ii] = ycalc[v_minloc]
//	xcalc[v_minloc]=inf
//	
//endfor
//killwaves /z xcalc, ycalc

	Sort Xwave, Xwave, YWave

end

////////////////////////////////////////////////////////////////

Function/wave MeasureDistances(CoM, Bottom_X, Bottom_Y, Top_X, Top_Y)
Wave CoM, Bottom_X, Bottom_Y, Top_X, Top_Y

variable ii, roicount

make /o/n=(dimsize(com,0)) Positions

duplicate /o bottom_X, Percentiles 
//make /o/n=(numpnts(Bottom_X)) PerX, PerY
redimension /n=(-1,2,103) Percentiles
Make /o/n=(103) distfromperc

For(ii=0;ii<101;ii+=1)

	Percentiles[][0][ii] = (ii*top_X[p]+(100-ii)*Bottom_X[p])/100
	Percentiles[][1][ii] = (ii*top_Y[p]+(100-ii)*Bottom_Y[p])/100

endfor

	Percentiles[][][102]=2*Percentiles[p][q][0]-Percentiles[p][q][1]		//-1%
	Percentiles[][][101]=2*Percentiles[p][q][100]-Percentiles[p][q][99]	//101%

Variable xpnts = dimsize(CoM,0)

For(ROIcount = 0;ROICount < xpnts;roicount +=1)
	if(numtype(CoM[ROICount][0]) == 2 || numtype(CoM[ROICount][1]) == 2)
		Positions[ROICount] = NaN
	else

		For(ii=0;ii<103;ii+=1)
				
					
				Duplicate/o/free/r=[][0][ii] Percentiles, PerX
				Duplicate/o/free/r=[][1][ii] Percentiles, PerY
				Redimension/n=(-1) PerX, PerY
				
				//PerX[] = Percentiles[p][0][ii]
				//PerY[] = Percentiles[p][1][ii]
				distfromperc[ii] = ShortestDistance2(PerX, PerY, CoM[ROICount][0],CoM[ROICount][1])
			
		endfor
	
		wavestats /q/m=1 distfromperc
		Positions[ROICount] = v_minloc
	endif
	
endfor

	MatrixOP/o Positions = Replace(Positions,102,-1)


killwaves /z distfromperc, PerX, PerY
//killwaves /z Percentiles
return Positions
end

////////////////////////////////////////////////////////////////

Function/wave MeasureDistancesFromPercentiles(CoM,Percentiles)
Wave CoM, Percentiles

variable ii, roicount

make /o/n=(dimsize(com,0)) Positions


Make /o/n=(103) distfromperc


Variable xpnts = dimsize(CoM,0)

For(ROIcount = 0;ROICount < xpnts;roicount +=1)
	if(numtype(CoM[ROICount][0]) == 2 || numtype(CoM[ROICount][1]) == 2)
		Positions[ROICount] = NaN
	else

		For(ii=0;ii<103;ii+=1)
				
				Duplicate/o/free/r=[][0][ii] Percentiles, PerX
				Duplicate/o/free/r=[][1][ii] Percentiles, PerY
				Redimension/n=(-1) PerX, PerY
				//PerX[] = Percentiles[p][0][ii]
				//PerY[] = Percentiles[p][1][ii]
				distfromperc[ii] = ShortestDistance2(PerX, PerY, CoM[ROICount][0],CoM[ROICount][1])
			
		endfor
	
		wavestats /q/m=1 distfromperc
		Positions[ROICount] = v_minloc
	endif
	
endfor

	MatrixOP/o Positions = Replace(Positions,102,-1)


killwaves /z distfromperc, PerX, PerY
//killwaves /z Percentiles
Return Positions
end

////////////////////////////////////////////////////////////////

Function Horizontal(Xfunc, Yfunc)
wave XFunc, Yfunc

variable xrange, yrange, result

duplicate/o xfunc calc_difx, xcalc2
duplicate/o yfunc calc_dify, ycalc2

wavestats /m=1/q xcalc2
Xcalc2/=abs(v_max)
wavestats /m=1/q ycalc2
ycalc2/=abs(v_max)

differentiate Xcalc2 /d=calc_difX
differentiate Ycalc2 /d=calc_difY 

xrange=WaveMax(calc_difX)*WaveMin(calc_difX)
yrange=WaveMax(calc_difY)*WaveMin(calc_difY)


if(Xrange >= Yrange)
	result=1
else
	result=0
endif


killwaves /z calc_difX, calc_difY, xcalc2,ycalc2
return result
end 

////////////////////////////////////////////////////////////////

Function Thickness(Percentiles,[left, right])
wave percentiles
variable left, right

variable xdim=dimsize(percentiles,0)

if(paramisdefault(left))
	left=0
endif
if(paramisdefault(right))
	right = xdim-1
endif

make/o/n=(xdim) calc_thick



MultiThread calc_thick[]=sqrt((percentiles[p][0][0]-percentiles[p][0][100])^2 + (percentiles[p][1][0]-percentiles[p][1][100])^2)


wavestats /r=[left, right] calc_thick



killwaves /z calc_thick
return v_avg
end


////////////////////////////////////////////////////////////////

Function Thickness2(Percentiles,[left, right])
wave percentiles
variable left, right

variable xdim=dimsize(percentiles,0)

if(paramisdefault(left))
	left=0
endif
if(paramisdefault(right))
	right = xdim-1
endif

make/o/n=(xdim) calc_thick, perX0, perY0

perX0[]=percentiles[p][0][0]
perY0[]=percentiles[p][1][0]

MultiThread calc_thick[]=shortestdistance2(perx0,pery0,percentiles[p][0][100],Percentiles[p][1][100])



wavestats /r=[left, right] calc_thick



killwaves /z calc_thick
return v_avg
end

////////////////////////////////////////////////////////////////


Function DrawCoMPositions(CoMWave, positions, bgimg, WindowName, [fontsize, TextRot])

wave ComWave, positions, bgimg
string windowName
variable fontsize, TextRot

variable counter, xpos, ypos, num

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
	num=positions[counter]
	drawtext /w=$windowname xpos,ypos, num2str(num)


endfor


end