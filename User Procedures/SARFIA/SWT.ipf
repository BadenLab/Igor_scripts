#pragma rtGlobals=1		// Use modern global access method.

////////////////////////////////////////////////////////////////////////
//SWT2D(im) calculates a stationary (or ˆ trous) wavelet transform of the image im	//
//																					//
//SWT3D(im) calculates a stationary wavelet transform of the image stack im		//
//																					//
//mirror(im) mirrors half of the image im outwards in all four directions			//
//	to compensate for edge effects													//
//																					//
//makeSWTkernel(iter) returns the starting kernel, {1/16,1/4,3/8,1/4,1/16},	//
//	iterated to have 2^(iter-1)-1 zeroes between taps. The first iter is 1 (not 0).	//
//																					//
//bigPi2D(imstack, [stop]) calculates the product of all (or stop) layers of imstack.	//
//																					//
//bigPi3D(imstack, [stop]) calculates the product of all (or stop) chunks of imstack.	//
//																					//
//Reference: Olivo-Marin 2002, Pattern Recognition 35:1989-1996				//
////////////////////////////////////////////////////////////////////////


function SWT2D(image, [filter])
	wave image		//image
	variable filter	//k in Olivo-Marin 2002
	variable xdim, ydim, ii, maxxIter, maxYIter, maxIter, jj
	variable klen
	
	if(paramisdefault(filter))
		filter=0
	endif
	
	duplicate/o/free image,im, im_con, im_con2, input
	
	
	wavestats/q/m=1 image
	
	if(V_numNaNs)		//replace NaNs with 0
		MatrixOP/o/free im=ReplaceNaNs(image,0)
	endif
	
	duplicate/o im  wavelet, A_Wave
	
	xdim=dimsize(im,0)
	ydim=dimsize(im,1)
	
	maxXIter = (log(xdim-1)-log(4)+log(2))/log(2)		//max. number of iterations in X
	maxYIter = (log(ydim-1)-log(4)+log(2))/log(2)		//max. number of iterations in Y
	
	maxIter=min(maxXIter, maxYIter)
	
	redimension/n=(-1,-1,floor(maxIter)+1) wavelet, A_Wave	//result waves
	
	FastOP im_con=0
	FastOP im_con2=0

	
	Make/free/n=(xdim) xker		//X Kernel
	Make/free/n=(ydim) yker		//Y Kernel 
	
	For(jj=1;jj<maxIter;jj+=1)	//loop through iterations
		input = A_wave[p][q][jj-1]
	
		Wave Kernel = makeSWTkernel(jj)	//make appropriate kernel
		klen=numpnts(Kernel)
		xker = 0
		yker = 0
		
		xker[0,klen-1] = Kernel[p]
		yKer[0,klen-1] = Kernel[p]
		
		
		for(ii=0;ii<ydim;ii+=1)	//loop through Y dim
		
			duplicate/o/free/r=[0,*][ii,ii] input xtrace
			
			convolve/c xker, xtrace
		
			im_con[][ii,ii]+=xtrace[p]
			
	
		endfor //ii ydim
		
		for(ii=0;ii<xdim;ii+=1)		//loop through X dim
		
			duplicate/o/free/r=[ii,ii][0,*] input ytrace
			
			convolve/c yker, ytrace
		
			im_con2[ii,ii][]+=ytrace[q]
			
		
		endfor //ii xdim
		
		//calculate results
		A_wave[][][jj] = (im_con[p+2][q] + im_con2[p][q+2])/2 
		wavelet[][][jj] = A_Wave[p][q][jj-1] - A_wave[p][q][jj]
	
		
	Endfor	//jj
	
	if(filter)
		filterW2D(wavelet,filter)
	endif
	
	
end

////////////////////////////////////////////////////////////////////

function SWT3D(image, [filter])
	wave image		//image stack
	variable filter
	variable xdim, ydim, ii, maxxIter, maxYIter, maxIter, jj, zdim, kk
	variable klen, maxZIter
	
	if(paramisdefault(filter))
		filter=0
	endif
	
	duplicate/o/free image im, im_con, im_con2, input, im_con3
	
	wavestats /q/m=1 image
	if(V_numNaNs)		//replace NaNs with 0
		MatrixOP/o/free im=ReplaceNaNs(image,0)
	endif
	
	duplicate/o im  wavelet, A_Wave
	
	xdim=dimsize(im,0)
	ydim=dimsize(im,1)
	zdim=dimsize(im,2)
	
	maxXIter = (log(xdim-1)-log(4)+log(2))/log(2)
	maxYIter = (log(ydim-1)-log(4)+log(2))/log(2)
	maxZIter = (log(zdim-1)-log(4)+log(2))/log(2)
	
	maxIter=min(min(maxXIter, maxYIter),maxZIter)		//calculate max. number of iterations
	
	redimension/n=(-1,-1,-1,floor(maxIter)+1) wavelet, A_Wave
	
	im_con=0
	im_con2=0
	im_con3=0
	
	Make/free/n=(xdim) xker
	Make/free/n=(ydim) yker
	Make/free/n=(zdim) zker
	
	For(jj=1;jj<maxIter;jj+=1)
		input = A_wave[p][q][jj-1]
	
		Wave Kernel = makeSWTkernel(jj)
		klen=numpnts(Kernel)
		xker = 0
		yker = 0
		zker=0
		
		xker[0,klen-1] = Kernel[p]
		yKer[0,klen-1] = Kernel[p]
		zKer[0,klen-1] = Kernel[p]
		
		for(ii=0;ii<ydim;ii+=1)
			for(kk=0;kk<zdim;kk+=1)
		
				duplicate/o/free/r=[0,*][ii,ii][kk,kk] input xtrace
			
				convolve/c xker, xtrace
		
				im_con[][ii][kk]+=xtrace[p]
			
			endfor
		endfor //ii ydim
		
		for(ii=0;ii<xdim;ii+=1)
			for(kk=0;kk<zdim;kk+=1)
			
				duplicate/o/free/r=[ii,ii][0,*][kk,kk] input ytrace
			
				convolve/c yker, ytrace
		
				im_con2[ii][][kk]+=ytrace[q]
			
			endfor
		endfor //ii xdim
		
		for(ii=0;ii<zdim;ii+=1)
			for(kk=0;kk<xdim;kk+=1)
		
			duplicate/o/free/r=[ii,ii][kk,kk][0,*] input ztrace
			
			convolve/c zker, ztrace
		
			im_con3[ii][kk][]+=ztrace[q]
			
			endfor
		endfor //ii zdim
		
		
		//calculate results
		A_wave[][][][jj] = (im_con[p+2][q][r] + im_con2[p][q+2][r]+ im_con3[p][q][r+2])/3 
		wavelet[][][][jj] = A_Wave[p][q][r][jj-1] - A_wave[p][q][r][jj]
	
		
	Endfor	//jj
	
	if(filter)
		filterW3D(wavelet,filter)
	endif
	
end

////////////////////////////////////////////////////////////////////

function mirror2D(im)
	wave im
	
	variable xdim, ydim, ii
	
	
	xdim=dimsize(im,0)
	ydim=dimsize(im,1)
	
	duplicate/o im im_d
	redimension /n=(xdim*2,ydim*2) im_d
	im_d=0
	im_d[xdim/2,xdim*1.5][ydim/2,ydim*1.5]=im[p-xdim/2][q-ydim/2]		//centre
	im_d[0,xdim/2][ydim/2,ydim*1.5]=im[xdim/2-p][q-ydim/2]				//left
	im_d[xdim*1.5,xdim*2][ydim/2,ydim*1.5]=im[xdim-(p-xdim*1.5)][q-ydim/2]//right
	im_d[xdim/2,xdim*1.5][0,ydim/2]=im[p-xdim/2][ydim/2-q]				//bottom
	im_d[xdim/2,xdim*1.5][ydim*1.5,ydim*2]=im[p-xdim/2][ydim-(q-ydim*1.5)]//top
	
end

////////////////////////////////////////////////////////////////////

function/wave makeSWTkernel(iter)
	variable iter
	
	variable nitems, nZeroes, ii, count = 1, num
	
	nZeroes = 2^(iter-1)-1
	
	make/free StartKernel = {1/16,1/4,3/8,1/4,1/16}

	nItems = 5 + 4*(nZeroes)

	
	make/o/n=(nItems) Kernel = 0
	Kernel[0]=StartKernel[0]
	
	For(ii=1;ii<nItems;ii+=1)
	
		if(mod(ii,nZeroes+1)==0)
			Kernel[ii] = Startkernel[count]
			count+=1
		else
			Kernel[ii]=0
		endif
		
	
	EndFor

	
	return Kernel
end

////////////////////////////////////////////////////////////////////

function/wave bigPi2D(imstack, [stop])
	wave imstack
	variable stop
	
	variable zdim, ii
	
	zdim=dimsize(imstack,2)
	
	if(paramisdefault(stop))
		stop=zdim
	else
		stop=min(stop,zdim)
	endif
	
	if(zdim<2)
		Abort "No 2D pies for less than 2 layers"
	endif
	
	duplicate/o imstack Pie
	redimension/n=(-1,-1) Pie
	
	
	for(ii=1;ii<stop;ii+=1)
	
		Pie=pie[p][q]*imstack[p][q][ii]
	
	endfor
	return Pie
end

////////////////////////////////////////////////////////////////////

function/wave bigPi3D(imstack, [stop])
	wave imstack
	variable stop
	
	variable zdim, ii
	
	zdim=dimsize(imstack,3)
	
	if(paramisdefault(stop))
		stop=zdim
	else
		stop=min(stop,zdim)
	endif
	
	if(zdim<2)
		Abort "No 3D pies for less than 2 chunks"
	endif
	
	duplicate/o imstack Pie
	redimension/n=(-1,-1,-1) Pie
	
	
	for(ii=1;ii<stop;ii+=1)
	
		Pie=pie[p][q][r]*imstack[p][q][r][ii]
	
	endfor
	return Pie
end

////////////////////////////////////////////////////////////////////

Function filterW2D(wavelet,k)	//overwrites wavelet
	wave wavelet
	variable k
	
	variable ncoef, ii, ti
	
	ncoef=dimsize(wavelet,2)
	
	duplicate/o/free wavelet, w_fil
	
	For(ii=0;ii<ncoef;ii+=1)
		duplicate/o/free/r=[][][ii] wavelet, coef
		imagestats /m=2 coef
		ti=k*statsMAD(coef)/0.67	//ti = k * sigmai; k=3, sigmai=MAD/0.67
		
		MultiThread w_fil[][][ii]=SelectNumber(abs(coef[p][q])>ti,0,abs(coef[p][q]))
	EndFor
	
	Duplicate/o w_fil, wavelet
End
			
////////////////////////////////////////////////////////////////////

Function filterW3D(wavelet, k) //overwrites wavelet
	wave wavelet
	variable k
	
	variable ncoef, ii, ti
	
	ncoef=dimsize(wavelet,3)
	
	duplicate/o/free wavelet, w_fil
	
	For(ii=0;ii<ncoef;ii+=1)
		duplicate/o/free/r=[][][][ii] wavelet, coef
		imagestats /m=2 coef
		ti=k*statsMAD(coef)/0.67
		MultiThread w_fil[][][][ii]=SelectNumber(abs(coef[p][q][r])>ti,0,abs(coef[p][q][r]))
	EndFor
	
	Duplicate/o w_fil, wavelet
End	

////////////////////////////////////////////////////////////////////

Threadsafe Function statsMAD(wv)		//calculates Median Absolute Deviation (MAD)
	wave wv
	
	variable median, MADresult
	
	median=StatsMedian(wv)
	
	MatrixOP /o/free MedWv=Abs(wv-median)
	
	MADresult=StatsMedian(MedWv)
	
	Return MADResult
	
end
