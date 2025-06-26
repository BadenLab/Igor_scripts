#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Official ScanM Data Preprocessing Scripts - by Tom Baden    	///
/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Requires detrended 3D data from "OS_DetrendStack" proc	///
///	Input Arguments - Channel (0,1,2..), Min_ampl, Min_corr		///
///	e.g.: "OS_AutoRoiByCorr(0,15,0.3)"							///
///   Uses image correlation to place ROIs						///
///   note primary flags below									///
///	Output is new wave called ROIs							///
/////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_AutoRoiByCorr()

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
variable includediagonals = OS_Parameters[%IncludeDiagonals] // 0 no, 1 yes 
variable timecompress = OS_Parameters[%TimeCompress]
variable correlation_minimum = OS_Parameters[%ROI_corr_min]
variable ROI_minpx = OS_Parameters[%ROI_minPx] 
variable ROI_maxpx = OS_Parameters[%ROI_maxPx] 
variable GaussSize = OS_Parameters[%ROI_GaussSize]
variable adjacentPix = OS_Parameters[%ROIGap_px]
variable useMask4Corr = OS_Parameters[%useMask4Corr]

variable X_cut = OS_Parameters[%LightArtifact_cut]
variable LineDuration = OS_Parameters[%LineDuration]
variable nPxBinning = OS_Parameters[%ROI_PxBinning]

variable nLifesLeft = 10
variable nROIs_absolute_Max = 1000 // does not allow going over 1000 here, otherwise start to get memory issues

// data handling
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)

variable nX_full = DimSize(InputData,0)
variable nY_full = DimSize(InputData,1)

variable nF = DimSize(InputData,2)
variable Framerate = 1/(nY * LineDuration) // Hz 
variable Total_time = (nF * nX ) * LineDuration
print "Recorded ", total_time, "s @", framerate, "Hz"

variable xx,yy,xxx,yyy,nn,rr,ww // initialise counters
if (nPxBinning==1)
else
	make /o/n=(ceil(nX/nPxBinning),ceil(nY/nPxBinning),nF) InputDataBinDiv
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			InputDataBinDiv[floor(xx/nPxBinning)][floor(yy/nPxBinning)][]+=InputData[xx][yy][r]/(nPxBinning^2)
		endfor
	endfor
	duplicate /o InputDataBinDiv InputData
	killwaves InputDataBinDiv
	nX=ceil(nX/nPxBinning)
	nY=ceil(nY/nPxBinning)
endif
variable nRois_max = (nX-X_cut/nPxBinning)*nY

print ROI_minpx, "-", ROI_maxpx, "pixels per ROI"
variable nPx_neighbours = 1

// make correlation stack and Ave/SD stacks

if (waveexists($"correlation_projection")==1)
	print "Correlation_projection already exists - if want to recompute, delete it by hand"
else
	make /o/n=(nX,nY) Stack_ave = 0 // Avg projection of InputData
	make /o/n=(nX,nY) correlation_projection = 0
	make /o/n=(nF/timecompress) currentwave_main = 0
	make /o/n=(nF/timecompress) currentwave_comp = 0
	make /o/n=1 W_Statslinearcorrelationtest = NaN
	variable Cumul_corr

	variable PercentDone = 0
	variable PercentPerPixel = 100/((nX)*(nY))
	printf "Correlation progress: "
	for (xx=ceil(X_cut/nPxBinning);xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			Multithread currentwave_main[]=InputData[xx][yy][p*timecompress] // get trace from "reference pixel"
			Wavestats/Q currentwave_main
			Multithread Stack_ave[xx][yy]=V_Avg 
		
			if (xx <= ceil(X_cut/nPxBinning) || xx ==nX-1 || yy == 0 || yy == nY-1) // only compute correlation of not on the edge
			else
				Cumul_corr = 0	
				Multithread currentwave_comp[]=InputData[xx+1][yy][p*timecompress] // get trace from "comparison pixel" 1
				statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
				Cumul_corr+=W_Statslinearcorrelationtest[1]
				Multithread currentwave_comp[]=InputData[xx-1][yy][p*timecompress] // get trace from "comparison pixel" 2
				statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
				Cumul_corr+=W_Statslinearcorrelationtest[1]
				Multithread currentwave_comp[]=InputData[xx][yy+1][p*timecompress] // get trace from "comparison pixel" 3
				statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
				Cumul_corr+=W_Statslinearcorrelationtest[1]
				Multithread currentwave_comp[]=InputData[xx][yy-1][p*timecompress] // get trace from "comparison pixel" 4
				statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
				Cumul_corr+=W_Statslinearcorrelationtest[1]
			
				if (includediagonals==1)
					Multithread currentwave_comp[]=InputData[xx+1][yy+1][p*timecompress] // get trace from "comparison pixel" 5
					statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
					Cumul_corr+=W_Statslinearcorrelationtest[1]
					Multithread currentwave_comp[]=InputData[xx-1][yy+1][p*timecompress] // get trace from "comparison pixel" 6
					statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
					Cumul_corr+=W_Statslinearcorrelationtest[1]
					Multithread currentwave_comp[]=InputData[xx+1][yy-1][p*timecompress] // get trace from "comparison pixel" 7
					statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
					Cumul_corr+=W_Statslinearcorrelationtest[1]
					Multithread currentwave_comp[]=InputData[xx-1][yy-1][p*timecompress] // get trace from "comparison pixel" 8
					statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
					Cumul_corr+=W_Statslinearcorrelationtest[1]
					Multithread correlation_projection[xx][yy] = Cumul_corr / 8 
				else
					Multithread correlation_projection[xx][yy] = Cumul_corr / 4 
				endif

				PercentDone+=PercentPerPixel
			endif
		endfor
		if (PercentDone>=10)
			PercentDone-=10
			printf "#"
		endif
		Multithread Stack_Ave[0,X_cut][] = V_Min
	endfor

	// correct edge effects 
	correlation_projection[nX-1,nX-2][] = 0
	correlation_projection[][0] = 0
	correlation_projection[][nY-1,nY-2] = 0
	correlation_projection[0,X_cut/nPxBinning][] = 0
	
	ImageStats/Q Stack_Ave
	Stack_Ave[0,X_cut/nPxBinning][] = V_Avg
	
	// expand Corr projection to original size
	duplicate /o Correlation_projection, correlation_projection_4Compute
	make /o/n=(nX_full,nY_full) Correlation_projection = 0
		
	Correlation_projection[][]=correlation_projection_4Compute[floor(p/nPxBinning)][floor(q/nPxBinning)]

	print "# complete..."
endif


// place ROIs



if (correlation_minimum<1 && useMask4Corr == 0) // if this is set to 1, skip this whole thing
	duplicate /o correlation_projection_4Compute correlation_projection_sub
	
	if (GaussSize>0) // Gauss filter smooth the sub image
		MatrixFilter/N=(GaussSize)/P=1 gauss correlation_projection_sub
	endif
	duplicate /o correlation_projection_sub testtest
	
	make/o/n=(nRois_max) RoiSizes = nan
	make /o/n=(nX,nY) ROIs = 1 // 1 means "no roi/ background"
	if ((nX-X_cut/nPxBinning)*nY < nROIs_absolute_Max)
		make /o/n=(nX,nY,(nX-X_cut/nPxBinning)*nY) AllRois = 0
	else
		make /o/n=(nX,nY,nROIs_absolute_Max) AllRois = 0
	endif
	make/o/n=(nX, nY) CurrentRoi = 0
	variable X_pos,Y_pos
	variable max_corr 
	variable nRois = 0
	variable Roisize = 0
	variable RoiKilled = 0

	print "Placing ROIs: "
	variable markercounter = 0
	do // forever loop until "while", unless "break" is triggered
		Imagestats/Q correlation_projection_sub//Stack_SD_Sub
		if (RoiKilled==1) // this bit closes the ROI placement if more than nLifesLeft ROIs were placed and subsequently killed due to min size criterion
			nLifesLeft-=1
			RoiKilled = 0
			if (nLifesLeft<=0) 
				break
			endif
		endif
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/// Step 1: Setup the Seed pixel
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		if (V_max>correlation_minimum)
			nRois+=1
			Markercounter+=1
			if (Markercounter<20)
				printf "#"
			else
				Markercounter = 0
				print "#" // new line
			endif
			
			
			X_pos = V_maxRowLoc// find peak - "seed pixel"
			Y_pos = V_maxColLoc // find peak - "seed pixel"
			ROIs[X_pos][Y_pos]=10 // placeholder // nRois-1 // set that Pixel in Rois mask to the  Roi number 
			correlation_projection_sub[X_pos][Y_pos]=0 // get rid of that pixel in the correlation map
			// now find the highest correlation with this seed pixel in the original correlation stack
			AllRois[][][nRois-1]=0
			AllRois[X_pos][Y_pos][nRois-1]=1
			make /o/n=(nX,nY) currentRoi = 0
			Roisize = 1
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/// Step 2: Flood-fill the ROI from seed pixel if Correlation minimum is exceeded, and if there is a non-diagonal face attached to seed or its outgrowths
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			do
				currentRoi[][]=AllRois[p][q][nRois-1] // all active pixels are == 1
				Imagestats/Q currentRoi
				variable nPx_before = V_Avg * nX*nY // how many pixels in old ROI
				Multithread AllRois[X_cut/nPxBinning+1,nX-2][1,nY-2][nRois-1]=((correlation_projection_sub[p][q]>correlation_minimum) && ((currentRoi[p+1][q]==1)||(currentRoi[p-1][q]==1)||(currentRoi[p][q+1]==1)||(currentRoi[p][q-1]==1)))?(1):(AllRois[p][q][nRois-1]) // if neigbor >corr min && == 1 go 1, else leave as is
				currentRoi[][]=AllRois[p][q][nRois-1]
				Imagestats/Q currentRoi
				variable nPx_after = V_Avg * nX*nY // how many pixels in "grown" ROI?
				if (nPx_after==nPx_before || nPx_after >=ROI_maxpx) // if no change, or if too big, exit do-while loop
					break
				endif
			while(1)

			// here update all the other arrays according to that ROI
			Multithread ROIs[][]=(AllRois[p][q][nRois-1]==1)?(10):(ROIs[p][q]) // placeholder//nRois-1 // set that Pixel in Rois mask to the Roi number
			Multithread correlation_projection_sub[][]=(AllRois[p][q][nRois-1]==1)?(0):(correlation_projection_sub[p][q]) // get rid of those pixels in the correlation map
 			Roisize=nPx_after
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/// Step 3: Kill ROIs that are too small, and relabel Rois as n*(-1) that are retained
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
			if (Roisize<ROI_minpx) // if roi too small....
				ROIs[][] = (ROIs[p][q]==10)?(1):(ROIs[p][q]) 	// kill ROI in ROI image
				nRois-=1
				RoiKilled = 1
			else	 // if ROI big enough...
				ROIs[][] = (ROIs[p][q]==10)?(((nROIs-1)*(-1))-1):(ROIs[p][q]) 	// define ROI in ROI image
				RoiSizes[nROIs-1] = Roisize
			endif 
			
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
			
			
		else
			break // finish when no more pixels respond well enough to exceed "SD_minimum"
		endif
	while(1)
	print " total of", nRois

	// recompute Stack_Ave at original resolution, if was binned
	if (nPxBinning==1)
	else
		make /o/n=(nF/timecompress) currentwave_main = 0
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
		make /o/n=(nX,nY) Stack_Ave = 0

		for (xx=X_cut;xx<nX;xx+=1)
			for (yy=0;yy<nY;yy+=1)
				Multithread currentwave_main[]=InputData[xx][yy][p] // get trace from "reference pixel"
				Wavestats/Q currentwave_main
				Stack_Ave[xx][yy]=V_Avg
			endfor
		endfor
		Stack_Ave[0,X_cut][] = V_Min		
		endif
elseif (useMask4Corr == 0) // correlation_minimum is set to 1
	print "standard ROI placement routine is skipped becasue ROI_corr_min is set to 1"
	print "generating an empty ROI mask"
	make /o/n=(nX,nY) ROIs = 1 // 1 means "no roi/ background"
endif

// // using the SARFIA ROI Mask
if (useMask4Corr==1)
	if (waveexists(ROIs)==0)
		print "generating an empty ROI mask becasue no SARFIA Mask was found"
		make /o/n=(nX,nY) ROIs = 1 // 1 means "no roi/ background"
	else	
		// using the SARFIA ROI Mask
		print "using SARFIA ROI Mask"
		//
		// fix CellLab Scaling
		wave wROI=root:CellLab2D:Stack_ave:waves:wROI
		wave wDisplay=root:CellLab2D:Stack_ave:waves:wDisplay
		//
		wave ROIs
		duplicate /o ROIs ROIs_input
		duplicate /o ROIs ROIs_output
		ROIs_output = 1 // start with empty ROI map
		make /o/n=(nX,nY) CurrentROI = NaN
		variable nROIs_input = -Wavemin(ROIs_input)
		variable nROIs_new = 0
		for (rr=0;rr<nROIs_input;rr+=1)
			Multithread CurrentROI[][]=(ROIs_input[p][q]==-rr)?(1):(NaN)
			CurrentROI[][]*=correlation_projection_4Compute[p][q]
			ImageStats/Q CurrentROI
			if (V_Avg>correlation_minimum)
				nROIs_new+=1
				ROIs_output[][]=(CurrentROI[p][q]>0)?(-nROIs_new):(ROIs_output[p][q])
			endif
		endfor
		print nROIs_new,"/",nROIs_input,"retained"
		duplicate /o ROIs_output, ROIs
		nROIs = nROIs_new				
		killwaves ROIs_input, ROIs_output, CurrentROI
	endif	
endif


// display
if (Display_RoiMask==1)
	display /k=1
	ModifyGraph width={Aspect,nX/nY}
	ModifyGraph height={Aspect,2*nY/nX}
	ModifyGraph width=400
	doUpdate
	ModifyGraph width=0
	
	Appendimage /l=YAxis1 /b=XAxis Correlation_projection
	Appendimage /l=YAxis2 /b=XAxis Stack_Ave	
	Appendimage /l=YAxis2 /b=XAxis ROIs
	ModifyGraph fSize=8,axisEnab(YAxis1)={0.05,0.5},axisEnab(XAxis)={0.05,1};DelayUpdate
	ModifyGraph fSize=8,axisEnab(YAxis2)={0.55,1}
	ModifyGraph freePos(YAxis1)={0,kwFraction};DelayUpdate
	ModifyGraph freePos(XAxis)={0,kwFraction},freePos(YAxis2)={0,kwFraction}
	ModifyGraph lblPos=47
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
	endfor
endif

// kill infs/NaN
Correlation_projection[][]=(NumType(Correlation_projection[p][q])==0)?(Correlation_projection[p][q]):(0)


// cleanup
killwaves InputData,W_Statslinearcorrelationtest,currentwave_main,currentwave_comp, correlation_projection_sub, allRois
killwaves currentRoi,InputDataBinDiv,ROIs_new

end