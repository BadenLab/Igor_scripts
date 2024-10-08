#pragma rtGlobals=3		// Use modern global access method.

//Update 20100418: added MorphROI
//Update 20140516: Added 3D support

// MultiROI(binarymask, targetwave) numbers regions of interest (ROIs) from the binary
// ROI mask sourcewave (pixels in the ROI have a value of 0, those outside 1) and generates
// a MultiROi ROI wave with the name targetwave. In this wave, ROIs will have increasing negative
// numbers starting with -1 near the origin. ROIs are numbered line-by-line, with rows increasing 
// at the end of each line and layers increasing after that, if binarymask has 3 dimensions. 
// Furthermore, if pixels "touch" on an edge, the will be considered to be the
// same ROI. This can be changed by commenting out the conditional statements where neither x2 nor
// y2 nor z2 is 0.
//If roicount > 0 the first ROI will have the value roicount.
//If closing > 0 image closure will be pwerformed on binarymask. This can have unexpected results if
//binarymask is not actually binary.
// MorphROI(ROI, type) performs morphological operations on the MultiROIwave ROI, depending on type:
// 0=Erosion, 1=Dilation, 2=Closing, 3=Opening;

Function MultiROI(binarymask, targetwave, [roicount, closing, overwrite])
	wave binarymask
	string targetwave
	variable ROIcount, closing, overwrite
	
	variable nDims, result
	
	if(paramisdefault(ROICount))
		roicount = 0
	endif
	
	if(ParamIsDefault(closing))
		closing = 0
	endif
	
	if(ParamIsDefault(overwrite))
		overwrite = 0
	endif
	
	nDims = WaveDims(binarymask)
	
	switch(nDims)
	
		case 2:	//2D
			result = MultiROI2D(binarymask, targetwave, roicount=roicount, closing=closing, overwrite=overwrite)
		break
	
		case 3:	//3D
			result = MultiROI3D(binarymask, targetwave, roicount=roicount, closing=closing, overwrite=overwrite)
		break
		
		default:
			result = -1
		break
	
	endswitch
	
	return result
end


///////////////////////////////////////////////////////////////////////////////

Function MultiROI2D(binarymask, targetwave, [roicount, closing, overwrite])
	wave binarymask
	string targetwave
	variable ROIcount, closing, overwrite
	
	if(paramisdefault(ROICount))
		roicount = 0
	endif
	
	if(ParamIsDefault(closing))
		closing = 0
	endif
	
	if(ParamIsDefault(overwrite))
		overwrite = 0
	endif
	
	
	
	variable xdim, ydim, xcount = 0, ycount = 0, x2, y2, condition, minx, condition2, maxx, type, pixelnumber = 0
	variable x3,y3, pxtrack
	string info
	
	info =waveinfo(binarymask, 0)
	type =  NumberByKey("NUMTYPE", info)
	
	
	if(closing>0)
		duplicate/o/free binarymask, locmask
		redimension/b/u locmask
		ImageMorphology Closing locmask	
		Wave M_ImageMorph
		duplicate/o/free M_ImageMorph, sourcewave
	else
		wave sourcewave=binarymask
	endif
	
	
	duplicate /o/free sourcewave, mrcalcwave
	xdim = dimsize(sourcewave, 0)
	ydim = dimsize(sourcewave, 1)
	make /o/free/n=(xdim*ydim,2) pointstore
	
	
	if (type > 5)
		redimension /d mrcalcwave
	endif
	FastOP mrcalcwave = 1
	
	ycount = 0
	do	//ycount
	xcount = 0
		do //xcount
		pixelnumber = 0
			if ((sourcewave[xcount][ycount] < 1) && (mrcalcwave[xcount][ycount]==1))
				pixelnumber +=1
				ROIcount +=1
				pxtrack = 0
				mrcalcwave[xcount][ycount]= -roicount
				pointstore[pixelnumber - 1][0] = xcount
				pointstore[pixelnumber - 1][1] = ycount
				x3 = xcount
				y3 = ycount
				
				do //pxtrack
					x2 = -1
					y2 = -1
					
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
					
					
					x2 = 0
					y2 = -1
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))		
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
						
						x2 = 1
						y2 = -1
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
						
						x2 = -1
						y2 = 0
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
						
						x2 = 1
						y2 = 0
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
						
						x2 = -1
						y2 = 1
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
						
						x2 = 0
						y2 = 1
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
						
						x2 = 1
						y2 = 1
					if((x3+x2 > 0) && (y3+y2 > 0) && (x3+x2 < xdim) && (y3+y2 < ydim))	
						if ((sourcewave[x3+x2][y3+y2] < 1) && (mrcalcwave[x3+x2][y3+y2]==1))
							pixelnumber +=1
							mrcalcwave[x3+x2][y3+y2]= -roicount
							pointstore[pixelnumber - 1][0] = x3+x2
							pointstore[pixelnumber - 1][1] = y3+y2
						endif
					endif
					
					
				pxtrack +=1
				x3 = pointstore[pxtrack][0]
				y3 = pointstore[pxtrack][1]
				while(pxtrack <= pixelnumber)
				
			endif
		xcount +=1
		while(xcount<xdim)
	ycount +=1
	while (ycount<ydim)
	
	
	
	if(overwrite>0)
		duplicate/o mrcalcwave, binarymask
	else
		duplicate /o mrcalcwave, $targetwave
	endif
	
	return ROIcount
end

////////////////////////////////////////////



Function MultiROI3D(binarymask, targetwave, [roicount, closing, overwrite])
	wave binarymask
	string targetwave
	variable ROIcount, closing, overwrite
	
	if(paramisdefault(ROICount))
		roicount = 0
	endif
	
	if(ParamIsDefault(closing))
		closing = 0
	endif
	
	if(ParamIsDefault(overwrite))
		overwrite = 0
	endif
	
	
	variable xdim, ydim, zdim, xcount, ycount, zcount, x2, y2, z2, type, pixelnumber = 0
	variable x3,y3,z3, pxtrack
	string info
	
	if(closing>0)
		duplicate/o/free binarymask, locmask
		redimension/b/u locmask
		ImageMorphology Closing locmask	
		Wave M_ImageMorph
		duplicate/o/free M_ImageMorph, sourcewave
	else
		wave sourcewave=binarymask
	endif
	
	
	info =waveinfo(binarymask, 0)
	type =  NumberByKey("NUMTYPE", info)
	

	wave sourcewave=binarymask
	
	duplicate /o/free sourcewave, mrcalcwave
	xdim = dimsize(sourcewave, 0)
	ydim = dimsize(sourcewave, 1)
	zdim = dimsize(sourcewave, 2)
	
	
	make /o/free/n=(xdim*ydim*zdim,3) pointstore		
	
	
	if (type > 5)
		redimension /d mrcalcwave
	endif
	//FastOP 
	mrcalcwave = 1
	
	
	zcount=0
	do  //zcount
		ycount = 0
		do	//ycount
		xcount = 0
			do //xcount
			pixelnumber = 0
				if ((sourcewave[xcount][ycount][zcount] < 1) && (mrcalcwave[xcount][ycount][zcount]==1))
					pixelnumber +=1
					ROIcount +=1
					pxtrack = 0
					mrcalcwave[xcount][ycount][zcount]= -roicount
					pointstore[pixelnumber - 1][0] = xcount
					pointstore[pixelnumber - 1][1] = ycount
					pointstore[pixelnumber - 1][2] = zcount
					x3 = xcount
					y3 = ycount
					z3= zcount
					
					do //pxtrack
						//layer +0
						z2 = 0
						
						x2 = -1
						y2 = -1
						
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))						
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
											
						
						x2 = 0
						y2 = -1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))		
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
						x2 = 1
						y2 = -1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))		
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
								///repeat 2x if from above
						
						x2 = -1
						y2 = 0
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
						x2 = 1
						y2 = 0
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
						x2 = -1
						y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
						x2 = 0
						y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
						x2 = 1
						y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
						
						
						
						
							//layer +1
							z2 = 1
							
							x2 = 0
							y2 = 0		
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))				
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
										
							x2 = -1
							y2 = -1	
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))					
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 0
							y2 = -1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 1
							y2 = -1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = -1
							y2 = 0
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 1
							y2 = 0
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = -1
							y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 0
							y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 1
							y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif



						//layer -1
						z2 = -1
							
							x2 = 0
							y2 = 0		
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))				
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
										
							x2 = -1
							y2 = -1	
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))					
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 0
							y2 = -1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 1
							y2 = -1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = -1
							y2 = 0
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 1
							y2 = 0
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = -1
							y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 0
							y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif
							
							x2 = 1
							y2 = 1
						if((x3+x2 > 0) && (y3+y2 > 0) && (z3+z2>0) && (x3+x2 < xdim) && (y3+y2 < ydim) && (z3+z2<zdim))
							if ((sourcewave[x3+x2][y3+y2][z3+z2] < 1) && (mrcalcwave[x3+x2][y3+y2][z3+z2]==1))
								pixelnumber +=1
								mrcalcwave[x3+x2][y3+y2][z3+z2]= -roicount
								pointstore[pixelnumber - 1][0] = x3+x2
								pointstore[pixelnumber - 1][1] = y3+y2
								pointstore[pixelnumber - 1][2] = z3+z2
							endif
						endif

						
					pxtrack +=1
					x3 = pointstore[pxtrack][0]
					y3 = pointstore[pxtrack][1]
					z3 = pointstore[pxtrack][2]
					while(pxtrack <= pixelnumber)
					
				endif
			xcount +=1
			while(xcount<xdim)
		ycount +=1
		while (ycount<ydim)
	zcount+=1
	while(zcount<zdim)
	
	
	
	if(overwrite>0)
		duplicate/o mrcalcwave, binarymask
	else
		duplicate /o mrcalcwave, $targetwave
	endif
	
	return ROIcount
end




/////////////////////////////////////

Function MultiROIbyLayer(sourcewave, targetwave)
	wave sourcewave
	string targetwave
	
	
	Variable zDim = DimSize(sourcewave, 2), ii, ROInumber = 0, counter
	
	if(zDim < 1)
		zDim = 1
	endif
	
	duplicate/o/free sourcewave MRW
	
	for(ii=0;ii<zDim;ii+=1)
		duplicate/o/free/r=[0,*][0,*][ii] sourcewave frame
		
		counter=ROInumber
		ROInumber=multiroi(frame,"W_multiROI", roicount=counter)
		wave W_multiROI
	
		MultiThread MRW[][][ii]=W_multiROI[p][q]
	
	endfor
	

	duplicate/o MRW $targetwave
	
	killwaves W_multiROI
	return ROInumber
End

/////////////////////////////////////

Function/Wave MultiROIStats(image, ROI, [m])
	Wave Image, ROI
	Variable m
	
	Variable mismatch

	Mismatch = abs(WaveDims(image) - WaveDims(ROI)) + abs(DimSize(image,0) - DimSize(ROI, 0)) + abs(DimSize(image, 1) - DimSize(ROI, 1)) + abs(DimSize(image,2) - DimSize(ROI, 2))
	
	If(mismatch)			//just checking...
		DoAlert 0, "Image/ROI mismatch"
		Make/o/n=(1,4) ROIStats = NaN		
		Return ROIStats
	endif
	
	
	If(ParamIsDefault(m))
		m=1
	elseif(!((m == 1) || (m == 2)))
		m = 2
	endif
	
	Variable ROInumber, ii
	
	ROInumber = -WaveMin(ROI)
	
	if(m==1)
		Make/o/n=(ROInumber,4) ROIStats
		SetDimLabel 1, 0, Avg, ROIStats
		SetDimLabel 1, 1, Min, ROIStats
		SetDimLabel 1, 2, Max, ROIStats
		SetDimLabel 1, 3, npnts, ROIStats
	else
		Make/o/n=(ROInumber,9) ROIStats
		SetDimLabel 1, 0, Avg, ROIStats
		SetDimLabel 1, 1, Min, ROIStats
		SetDimLabel 1, 2, Max, ROIStats
		SetDimLabel 1, 3, npnts, ROIStats
		
		SetDimLabel 1, 4, sdev, ROIStats
		SetDimLabel 1, 5, rms, ROIStats
		SetDimLabel 1, 6, skew, ROIStats
		SetDimLabel 1, 7, kurt, ROIStats
		SetDimLabel 1, 8, adev, ROIStats	
	endif
	
	Duplicate/o/free ROI ROImask
	ROImask = 1
	Redimension /b/u ROIMask
	
	For(ii=0;ii<ROINumber;ii+=1)
	
//		ROIMask = selectnumber(ROI[p][q] == -ii-1,1,0)		//make a single ROImask for the current ROI
		MatrixOP /o ROIMask=-equal(-ii-1,ROI)+1				//faster code
		Redimension/b/u ROIMask
		
		ImageStats /m=(m) /R=ROIMask image
		
		if(m==1)
			ROIStats[ii][0] = v_avg
			ROIStats[ii][1] = v_min
			ROIStats[ii][2] = v_max
			ROIStats[ii][3] = V_npnts
		else
			ROIStats[ii][0] = v_avg
			ROIStats[ii][1] = v_min
			ROIStats[ii][2] = v_max
			ROIStats[ii][3] = V_npnts
			
			ROIStats[ii][4] = v_sdev
			ROIStats[ii][5] = v_rms
			ROIStats[ii][6] = v_skew
			ROIStats[ii][7] = v_kurt
			ROIStats[ii][8] = v_adev
		endif
	
	EndFor
	
	Return ROIStats
End


///////////////////////////////////////////////////////////

Function/wave MorphROI(ROI, type)
	wave ROI
	variable type		// 0=Erosion, 1=Dilation, 2=Closing, 3=Opening
	
	
	MatrixOP/o/free binary=-1*(ROI*(-equal(ROI,1)+1))
	
	redimension/b/u binary
	
	switch(type)
		
		case 0:
			ImageMorphology/o Dilation binary //inverted, because binary is inverted relative to ROI
		break
			
		case 1:
			ImageMorphology/o Erosion binary 
		break
		
		case 2:
			ImageMorphology/o Opening binary 
		break 
		
		case 3:
			ImageMorphology/o Closing binary 
		break
		
		default:
			duplicate/o ROI w_MorphROI
			return w_MorphROI
	endswitch
	
	
	MatrixOP /o w_MorphROI=equal(binary,0)-binary
	redimension/s w_MorphROI
	CopyScales ROI, w_MorphROI
	
	return w_MorphROI
end


