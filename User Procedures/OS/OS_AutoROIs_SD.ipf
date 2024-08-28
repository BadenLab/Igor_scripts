#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/// BY TAKESHI YOSHIMATSU 2019

function OS_autoROIs_SD()

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

variable Display_RoiMask = OS_Parameters[%Display_Stuff]
variable SD_minimum = OS_Parameters[%ROI_SD_min]
variable ROI_minsize  = OS_Parameters[%ROI_minPx] 
variable ROI_maxsize = OS_Parameters[%ROI_maxPx] 
variable ROI_minpx = OS_Parameters[%ROI_minPx] 
variable GaussSize = OS_Parameters[%ROI_GaussSize]
variable adjacentPix = OS_Parameters[%ROIGap_px] 
variable X_cut = OS_Parameters[%LightArtifact_cut]
variable LineDuration = OS_Parameters[%LineDuration]
variable nLifesLeft = 10
variable nPxBinning = OS_Parameters[%ROI_PxBinning]
variable FOV_at_zoom065 = OS_Parameters[%FOV_at_zoom065] * (OS_Parameters[%fullFOVSize]/0.5)

variable nROIs_max = 1000

wave ROIs
wave M_ROIMask
duplicate /o M_ROIMask ROI_mask
wave wDataCh0_detrended
variable nX = Dimsize(wDataCh0_detrended,0)
variable nY = Dimsize(wDataCh0_detrended,1)
variable nLayers = Dimsize(wDataCh0_detrended,2)
variable GaussFilter = 1

wave wParamsNum // Reads data-header
variable zoom = wParamsNum(30) // extract zoom
variable px_Size = (0.65/zoom * FOV_at_zoom065)/nX // microns
variable MaxPixelRoi = ROI_maxsize//floor((pi * (ROI_maxsize^2))/(px_Size^2))
variable MinPixelRoi = ROI_minsize//floor((pi * (ROI_minsize^2))/(px_Size^2))


duplicate /o wDataCh0_detrended wDataCh0_mask

if (waveexists($"M_ROIMask")==0)
	print "Make Area Mask first"
else

wave M_ROIMask
duplicate /o M_ROIMask AreaMask

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
endif

// generate Stack_SD image

make /o/n=(nLayers) current_value
make /o/n=(nX,nY)  wDataCh0_mask_SD=0
variable zz
for (xx=cornerX1;xx<cornerX2;xx+=1)
	for (yy=cornerY1;yy<cornerY2;yy+=1)
		if (ROI_mask[xx][yy]==0)
			for (zz=0;zz<nLayers;zz+=1)
			current_value[zz]= wDataCh0_mask[xx][yy][zz]
			endfor
			wavestats /q current_value 
			 wDataCh0_mask_SD[xx][yy]=V_Sdev
		 else
		 wDataCh0_mask_SD[xx][yy]=NaN
		 endif
	endfor
endfor
imagestats /q wDataCh0_mask_SD
variable baseV= V_avg
print "background: "+Num2Str(baseV)
duplicate /o wDataCh0_mask_SD stack_SD

// median filter
variable nMedian = 0
variable MedianEdgeX = nX - nMedian*2
variable MedianEdgeY = nY - nMedian*2
variable MedianSide =  nMedian*2 + 1
variable MedianRank = ((nMedian*2+1)^2)/2
variable xxx,yyy,nn
if (nMedian>0)
make /o/n=((nMedian*2+1)^2) MedianSize = 0
make /o/n=(nX,nY) current_average = 0
	for (xx=0;xx<MedianEdgeX;xx+=1)
		for (yy=0;yy<MedianEdgeY;yy+=1)
			for (xxx=0;xxx<MedianSide;xxx+=1)
				for (yyy=0;yyy<MedianSide;yyy+=1)
					MedianSize[xxx+MedianSide*yyy] = wDataCh0_mask_SD[xx+xxx][yy+yyy]
				endfor
			endfor
			for (nn=0;nn<MedianRank;nn+=1)
				wavestats /q MedianSize
				MedianSize[V_maxRowLoc]=0
			endfor
			wavestats /q MedianSize
			current_average[xx+nMedian][yy+nMedian]=V_max
		endfor
	endfor	
wDataCh0_mask_SD[][]=current_average[p][q]
endif

duplicate /o wDataCh0_mask_SD correlation_projection_sub

killwaves MedianSize,current_average


nX = DimSize(wDataCh0_detrended,0)
nY = DimSize(wDataCh0_detrended,1)

if (MinPixelRoi<ROI_minpx) // exception handling - don't allow ROIs smaller than ROI_minpx pixels
	MinPixelRoi=ROI_minpx
endif
print "Pixel Size:", round(px_size*100)/100," microns"
print MinPixelRoi, "-", MaxPixelRoi, "pixels per ROI"
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nF = DimSize(InputData,2)
make /o/n=(nF) currentwave_main = 0



// place ROIs

MatrixFilter/N=(GaussSize)/P=1 gauss correlation_projection_sub

for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		if (M_ROIMask[xx][yy]==1)
			correlation_projection_sub[xx][yy]=NaN
		endif
	endfor
endfor

duplicate /o correlation_projection_sub correlation_projection_mask


make/o/n=(nRois_max) RoiSizes = 0
make/o/n=(nRois_max,2) RoiShapes = 0
make /o/n=(nX,nY) ROIs = 1 // 1 means "no roi/ background"

make/o/n=(nX, nY) CurrentRoi = 0
variable X_pos,Y_pos
variable max_corr 
variable nRois = 1
variable Roisize = 0
variable nPx_before, nPx_after
make /o/n=(ROI_maxsize,ROI_maxsize) current_region
make /o/n=7 W_coef

printf "Placing ROIs: "
newimage /k=1 ROIs
do // forever loop until "while", unless "break" is triggered

	Imagestats/Q correlation_projection_sub//Stack_SD_Sub

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 1: Setup the Seed pixel
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	if (V_max>SD_minimum)
		variable currentPeakV = V_max
		X_pos = V_maxRowLoc// find peak - "seed pixel"
		Y_pos = V_maxColLoc // find peak - "seed pixel"
		correlation_projection_sub[X_pos][Y_pos]=0 // get rid of that pixel in the correlation map
		// now find the highest correlation with this seed pixel in the original correlation stack
		make /o/n=(nX,nY) currentRoi = 0
		currentRoi[X_pos][Y_pos]=1
		Roisize = 1
		variable maxROIcounter = 0
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 2: Flood-fill the ROI from seed pixel if Correlation minimum is exceeded, and if there is a non-diagonal face attached to seed or its outgrowths
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			make /o/n=(nX,nY) currentCor_neighbor = 0
			duplicate /o currentRoi currentRoi_invert
			make /o/n=(nX,nY) currentRoi_invert = 1
			currentRoi_invert[X_pos][Y_pos]=0
			currentCor_neighbor[X_pos-1,X_pos+1][Y_pos-1,Y_pos+1]=correlation_projection_sub[p][q]*currentRoi_invert[p][q]
			variable currentX_min=X_pos
			variable currentX_max=X_pos
			variable currentY_min=Y_pos
			variable currentY_max=Y_pos
			// expand ROIs 
		
		do
			Imagestats/Q currentCor_neighbor
			if (V_max>SD_minimum)
				xx = V_maxRowLoc
				yy = V_maxColLoc

				currentCor_neighbor[V_maxRowLoc][V_maxColLoc]=0
				currentRoi_invert[xx][yy]=0
				currentCor_neighbor[xx-1][yy]=correlation_projection_sub[xx-1][yy]*currentRoi_invert[xx-1][yy]
				currentCor_neighbor[xx+1][yy]=correlation_projection_sub[xx+1][yy]*currentRoi_invert[xx+1][yy]
				currentCor_neighbor[xx][yy-1]=correlation_projection_sub[xx][yy-1]*currentRoi_invert[xx][yy-1]
				currentCor_neighbor[xx][yy+1]=correlation_projection_sub[xx][yy+1]*currentRoi_invert[xx][yy+1]
				variable xxRegional=xx-X_pos
				variable yyRegional=yy-Y_pos
				if (xxRegional>-SQRT(ROI_maxsize) &&  xxRegional<SQRT(ROI_maxsize) && yyRegional>-SQRT(ROI_maxsize) &&  yyRegional<SQRT(ROI_maxsize))
					currentRoi[xx][yy]=1
					maxROIcounter+=1
				endif
				else
				break
			endif

		while(maxROIcounter <MaxPixelRoi)
 		Roisize= maxROIcounter

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 3: Kill ROIs that are too small, and relabel Rois as n*(-1) that are retained
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	




		make /o/n=(nX) currentXline = NaN
		make /o/n=(nX) currentYline = NaN
		variable ROIsizeX = 0
		variable ROIsizeY = 0
		variable cc=0
		for (xx=0;xx<nX;xx+=1)
			currentYline[]=currentROI[xx][p]
			if (mean(currentYline)>0)
				ROIsizeX+=1
			endif
		endfor
		for (yy=0;yy<nY;yy+=1)
			currentXline[]=currentROI[yy][p]
			if (mean(currentXline)>0)
				ROIsizeY+=1
			endif
		endfor	
		variable ROIwidth = ROIsizeX
		variable ROIhight = ROIsizeY
		


		if (Roisize>=MinPixelRoi && ROIsizeX * ROIsizeY<Roisize*3)
		//	Fill in holes
		make /o/n=8 currentSurround
		variable fillingMode = 0
		Do
		fillingMode = 0
		for (xx=0;xx<nX;xx+=1)
			for (yy=0;yy<nY;yy+=1)
				if (currentRoi[xx][yy]==1)
					variable neiX
					variable neiY
					for (neiX=-1;neiX<2;neiX+=2)
						for (neiY=-1;neiY<2;neiY+=2)
							variable neighborX = xx+neiX
							variable 	neighborY = yy+neiY
							if (currentRoi[neighborX][neighborY]==0)			
								currentSurround[0]=currentRoi[neighborX-1][neighborY-1]
								currentSurround[1]=currentRoi[neighborX-1][neighborY]
								currentSurround[2]=currentRoi[neighborX-1][neighborY+1]
								currentSurround[3]=currentRoi[neighborX][neighborY-1]
								currentSurround[4]=currentRoi[neighborX][neighborY+1]
								currentSurround[5]=currentRoi[neighborX+1][neighborY-1]
								currentSurround[6]=currentRoi[neighborX+1][neighborY]
								currentSurround[7]=currentRoi[neighborX+1][neighborY+1]							
								if (mean(currentSurround)>0.7)
									currentRoi[neighborX][neighborY]=1
									fillingMode = 1
								endif
							endif
						endfor
					endfor
				endif
			endfor
		endfor
		While(fillingMode==1) 		
		
		//Remove isolated pixel
		for (xx=0;xx<nX;xx+=1)
			for (yy=0;yy<nY;yy+=1)
				if (currentRoi[xx][yy]==1)
					currentSurround[0]=currentRoi[xx-1][yy]
					currentSurround[1]=currentRoi[xx+1][yy]
					currentSurround[2]=currentRoi[xx][yy-1]
					currentSurround[3]=currentRoi[xx][yy+1]				
						if (mean(currentSurround)==0)
							currentRoi[xx][yy]=0
						endif						
				endif
			endfor
		endfor
				
		//  Remove direct adjacent	
		for (xx=0;xx<nX;xx+=1)
			for (yy=0;yy<nY;yy+=1)
				if (currentRoi[xx][yy]==1)
					correlation_projection_sub[xx-adjacentPix + 1,xx+adjacentPix - 1][yy-adjacentPix + 1,yy+adjacentPix - 1]=0
					correlation_projection_sub[xx-adjacentPix,xx+adjacentPix][yy]=0
					correlation_projection_sub[xx][yy-adjacentPix,yy+adjacentPix]=0
				endif
			endfor
		endfor
		wavestats /q currentROI
		if (V_sum<MinPixelRoi)
			currentROI=0
		endif
		ROIs[][] = (currentRoi[p][q]==1)?(((nROIs-1)*(-1))-1):(ROIs[p][q]) 	// define ROI in ROI image
		RoiSizes[nROIs-1] = Roisize
		RoiShapes[nRois-1][0] = ROIwidth
		RoiShapes[nRois-1][1] = ROIhight
		Doupdate
		nRois+=1
		else
			Roisize = 0
		endif
	else
		break // finish when no more pixels respond well enough to exceed "SD_minimum"
	endif
while(1)

killwaves currentSurround

imagestats /q ROIs
nRois = abs(V_min)
print " total of", nRois

//// upsample again if was Binned
if (nPxBinning==1)
else
	nX*=nPxBinning
	nY*=nPxBinning	
	make /o/n=(nX,nY) ROIs_new = 0
	for (xx=ceil(X_cut/nPxBinning);xx<floor(nX/nPxBinning);xx+=1)
		for (yy=0;yy<floor(nY/nPxBinning);yy+=1)
			ROIs_new[xx*nPxBinning,xx*nPxBinning+(nPxBinning-1)][yy*nPxBinning,yy*nPxBinning+(nPxBinning-1)]=ROIs[xx][yy]
		endfor
	endfor
	duplicate /o ROIs_new ROIs
	duplicate /o $input_name InputData
	make /o/n=(nX,nY) Stack_SD = 0
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			Multithread currentwave_main[]=InputData[xx][yy][p] // get trace from "reference pixel"
			Wavestats/Q currentwave_main
			Stack_SD[xx][yy]=V_SDev
		endfor
	endfor
	Stack_SD[0,X_cut][] = NaN	
		
endif

// ROI in left to right order
print "rearrangingROI"
duplicate /o ROIs ROIs_order
ROIs_order = 1
Imagestats/Q ROIs
nROIs = -1*V_Min
nn = 0
make /o/n=(nROIs) ROI_id = 1


for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		if (ROIs[xx][yy]<0)
			findvalue /v=(ROIs[xx][yy]) ROI_id
			if (V_value==-1)
			ROI_id[nn]=ROIs[xx][yy]
				for (xxx=0;xxx<nX;xxx+=1)
					for (yyy=0;yyy<nY;yyy+=1)
						if (ROIs[xxx][yyy]==ROIs[xx][yy])
							ROIs_order[xxx][yyy]=-1*(nn+1)
						endif
					endfor
				endfor
			nn+=1
			endif
		endif
	endfor
endfor

duplicate /o ROIs_order ROIs
killwaves ROI_id, ROIs_order

// setscale
setscale /p x,-nX/2*px_Size,px_Size,"µm" Stack_SD, ROIs
setscale /p y,-nY/2*px_Size,px_Size,"µm" Stack_SD, ROIs

variable rr
if (Display_RoiMask==1)
	display /k=1
	ModifyGraph width={Aspect,(nX/nY)*2}
	
	ModifyGraph height={Aspect,1/(2*nX/nY)}
	ModifyGraph width=800
	doUpdate
	ModifyGraph width=0
	
	Appendimage /l=YAxis /b=XAxis1 Stack_SD
	Appendimage /l=YAxis /b=XAxis2 Stack_SD	
	Appendimage /l=YAxis /b=XAxis2 ROIs
	ModifyGraph fSize=8,axisEnab(YAxis)={0.05,1},axisEnab(XAxis1)={0.05,0.5};DelayUpdate
	ModifyGraph axisEnab(XAxis2)={0.55,1},freePos(YAxis)={0,kwFraction};DelayUpdate
	ModifyGraph freePos(XAxis1)={0,kwFraction},freePos(XAxis2)={0,kwFraction}
	ModifyGraph lblPos=47
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
	endfor
endif



// cleanup
killwaves InputData,currentwave_main //allRois,correlation_projection_sub, 
killwaves currentRoi,M_colors,ROIs_new,currentRoi_invert,Inputdata,correlation_projection_sub,currentROI,currentROI_invert//currentAdjacent,currentXline,currentYline,
killwaves currentXline,currentYline,current_value,currentCor_neighbor

end

end