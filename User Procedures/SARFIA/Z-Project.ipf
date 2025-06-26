#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

#include "EqualizeScaling"


/////////////////////////////////////////////////////
/////////////////////List of functions///////////////////
//<picwave>...3D image wave
//<outputwave>...string (name of new wave)
//*************************************
//----Functions that calculate an image (2D) out of a stack:----
//avgZ(picwave, outputwave) 		--> returns average intensity
//maxZ(picwave, outputwave) 		--> returns max intensity
//minZ(picwave, outputwave)		--> returns min intensity
//stdevZ(picwave, outputwave)		--> returns standard deviation
//rangeZ(picwave, outputwave)		--> returns max - min
//*************************************
//----Functions calculating a wave (1D) out of a stack:----
// ZStack(picwave, outputwave)	 --> produces a Z profile for the selected ROI
//		use Analysis/Packages/Image Analysis, then Image/ROI
//		make sure to actually *save* the ROI;  ZStack uses "M_ROIMask"
//		Zstack works with Option "Zero ROI pixels" ON!
// ZStack2(picwave, outputwave) 	--> as above, only that you can choose the ROI from a pulldown menu
//*************************************
//----Functions that calculate a new stack (3D):----
//SubstBG(picwave, outputwave)	--> substracts average of ROI for each Z-frame
//NormBG(picwave, outputwave)	--> divides by average of ROI and substracts 1 for each Z-frame
//SubstBGPoly(picwave, outputwave, roiwave, order) fits an order-th polynimial to roiwaave and substracts that from
//	picwave, stores it as $outputwave. order=0 is equal to SubstBG


//////////////////////////////////////////////////////////////

function/wave maxZ(picwave, outputwave)
wave picwave
string outputwave

variable xdim, ydim, zdim, xcount = 0, ycount = 0, zcount = 0, zpeak
xdim = dimsize(picwave, 0)
ydim = dimsize(picwave, 1)
zdim = dimsize(picwave, 2)

make /o/n=(xdim,ydim) calcwave

do
ycount = 0
	do
	zpeak = 0
	zcount = 0
		do
			if (zpeak < picwave[xcount][ycount][zcount])
			zpeak = picwave[xcount][ycount][zcount]
			endif
		zcount = zcount + 1
		while (zcount < zdim)
	calcwave[xcount][ycount] = (zpeak)
	ycount = ycount +1
	while (ycount < ydim)
xcount = xcount + 1
while (xcount < xdim)
	
	
CopyScaling(picwave, calcwave)
duplicate /o calcwave, $outputwave	
killwaves /z calcwave
return $outputWave
end

//////////////////////////////////////////////////////////////

function minZ(picwave, outputwave)
wave picwave
string outputwave

variable xdim, ydim, zdim, xcount = 0, ycount = 0, zcount = 0, zpeak
xdim = dimsize(picwave, 0)
ydim = dimsize(picwave, 1)
zdim = dimsize(picwave, 2)

make /o/n=(xdim,ydim) calcwave

do
ycount = 0
	do
	zpeak = picwave[xcount][ycount][0]
	zcount = 0
		do
			if (zpeak > picwave[xcount][ycount][zcount])
			zpeak = picwave[xcount][ycount][zcount]
			endif
		zcount = zcount + 1
		while (zcount < zdim)
	calcwave[xcount][ycount] = (zpeak)
	ycount = ycount +1
	while (ycount < ydim)
xcount = xcount + 1
while (xcount < xdim)
	
	
CopyScaling(picwave, calcwave)
duplicate /o calcwave, $outputwave	
killwaves /z calcwave
end

//////////////////////////////////////////////////////////////


function rangeZ(picwave, outputwave)
wave picwave
string outputwave

variable xdim, ydim, zdim, xcount = 0, ycount = 0, zcount = 0, zsum, zmin, zmax
xdim = dimsize(picwave, 0)
ydim = dimsize(picwave, 1)
zdim = dimsize(picwave, 2)
make /o/n=(xdim,ydim) calcwave

do
ycount = 0
	do
	zsum = 0
	zcount = 0
	zmin = picwave[xcount][ycount][0]
	zmax = picwave[xcount][ycount][0]
		do
			if (picwave[xcount][ycount][zcount] > zmax)
			zmax =  picwave[xcount][ycount][zcount]
			endif
			if (picwave[xcount][ycount][zcount] < zmin)
			zmin =  picwave[xcount][ycount][zcount]
			endif		
		zcount = zcount + 1
		while (zcount < zdim)
	calcwave[xcount][ycount] = (zmax - zmin)
	ycount = ycount +1
	while (ycount < ydim)
xcount = xcount + 1
while (xcount < xdim)
	
	
CopyScaling(picwave, calcwave)
duplicate /o calcwave, $outputwave	
killwaves /z calcwave
end

////////////////////////////////////////////////////////////

function zStack(picwave, outputwave, roiwave)
wave picwave, roiwave
string outputwave

variable  wtype

wtype = WaveType(roiwave)

if(wtype != 72)
	redimension /b/u roiwave
endif

	ImageStats /M=1 /BEAM/R=roiwave picwave
	wave W_ISBeamAvg

	
duplicate /o W_ISBeamAvg, $outputwave
setscale /p x, dimoffset(picwave, 2), dimdelta(picwave, 2), WaveUnits(picwave, 2) $outputwave
setscale /p y, 0,1,Waveunits(picwave, -1) $outputwave
killwaves /z calcwave, W_ISBeamAvg, W_ISBeamMax, W_ISBeamMin
end


//////////////////////////////////////////////////////////////////

function SubstBG(picwave, outputwave, roiwave, [F0Wave])
wave picwave, roiwave
string outputwave, F0Wave

variable xdim, ydim, zdim, zcount = 0
variable xcount2, ycount2 
string ROIname
xdim = dimsize(picwave, 0)
ydim = dimsize(picwave, 1)
zdim = dimsize(picwave, 2)
duplicate /o picwave, calcwave

make /o /n=(zdim) f0calcwave
setscale /p x,dimoffset(picwave,2),dimdelta(picwave,2),WaveUnits(picwave,2) f0calcwave


For(zcount=0;zcount<zDim;zCount+=1)
	ImageStats /P=(zcount) /M=1 /R=ROIWave picwave
	
	
		MultiThread calcwave[][][zcount] = picwave[p][q][zcount] - v_avg
		f0CalcWave[zcount]=v_avg
			
EndFor	



CopyScaling(picwave, calcwave)
duplicate /o calcwave, $outputwave
If(ParamIsDefault(F0Wave))
	duplicate /o f0calcwave, $(outputwave+"F0")
Else
	duplicate /o f0calcwave, $F0Wave
EndIf
killwaves /z calcwave, f0calcwave
end
/////////////////////////////////////////////////////////////////////////////

function MultiROIZstack(picwave, outputwave, ROIwave)		// produces a populationwave
wave picwave, roiwave
string outputwave

variable zdim, roinumber, zcount, roicount = 0
zdim = dimsize(picwave,2)

imagestats /M=1 Roiwave
roinumber = -v_min

if (!roinumber)
	DoAlert 0, "MultiROIZstack requires a MultiROI ROI wave."
	return -1
endif


make /o /n=(zdim,roinumber) calcwave
setscale /p x,dimoffset(picwave,2),dimdelta(picwave,2),waveunits(picwave,2) calcwave
setscale d, -inf,inf,waveunits(picwave,-1) calcwave
duplicate /o roiwave, rw2
redimension /b/u rw2


do

rw2 +=1	
				
		ImageStats /M=1 /R=RW2 /BEAM picwave
		Wave W_ISBeamAvg
		duplicate /o W_ISBeamAvg, cw2
		calcwave[][roicount] = cw2[p]
		
		
roicount +=1
while (roicount < roinumber)
	
	


duplicate /o calcwave, $outputwave
killwaves /z calcwave, W_ISBeamAvg, W_ISBeamMax, W_ISBeamMin
killwaves /z RW2, cw2

return roinumber
end


//////////////////////////////////////////////////////////////////

function NormBG(picwave, outputwave, roiwave)
wave picwave, roiwave
string outputwave

variable xdim, ydim, zdim, zcount = 0
variable xcount2, ycount2 
string ROIname
xdim = dimsize(picwave, 0)
ydim = dimsize(picwave, 1)
zdim = dimsize(picwave, 2)
duplicate /o picwave, calcwave



do
	ImageStats /P=(zcount) /M=1 /R=ROIWave picwave
	
			if (v_avg != 0)
				MultiThread calcwave[][][zcount] = picwave[p][q][zcount] / v_avg - 1	
			 else 	
				 MultiThread calcwave[][][zcount] = picwave[p][q][zcount] 
			endif
		
	
	
zcount += 1
while (zcount<zdim)


CopyScaling(picwave, calcwave)
duplicate /o calcwave, $outputwave	
killwaves /z calcwave
end

/////////////////////////////////////////////////////////////////////////////

function avgZ(picwave, outputwave)
wave picwave
string outputwave

imagetransform averageimage picwave
wave M_AveImage

duplicate /o M_AveImage, $outputwave
copyScaling (picwave, $outputwave)

killwaves/z M_AveImage, M_StdvImage

end

/////////////////////////////////////////////////////////////////////////////

function stdevZ(picwave, outputwave)
wave picwave
string outputwave

imagetransform averageimage picwave
Wave M_StdvImage
duplicate /o M_StdvImage, $outputwave
copyScaling (picwave, $outputwave)

killwaves/z M_AveImage, M_StdvImage

end

/////////////////////////////////////////////////////////////////////////////

function SubstBGPoly(picwave, outputwave, roiwave, order)
wave picwave, roiwave
string outputwave
variable order

variable xdim, ydim, zdim, zcount = 0
variable xcount2, ycount2 
string ROIname
xdim = dimsize(picwave, 0)
ydim = dimsize(picwave, 1)
zdim = dimsize(picwave, 2)
duplicate /o picwave, calcwave, frame
redimension /n=(-1,-1) frame
//wave m_removedbackground


do
	frame=picwave[p][q][zcount]
	imageremovebackground /r=roiwave /p=(order) frame
	if(zcount==0)
		wave m_removedbackground
	endif
	calcwave[][][zcount]=m_removedbackground[p][q]	 
	
	
zcount += 1
while (zcount<zdim)


CopyScaling(picwave, calcwave)
duplicate /o calcwave, $outputwave	
killwaves /z calcwave, frame, m_removedbackground
end