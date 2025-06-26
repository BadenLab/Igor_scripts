#pragma rtGlobals=1		// Use modern global access method.
#include "SaveTiff"
#include "EqualizeScaling"

//Update 10/11/2015 MMD: Added ImageStackFilter for multithreaded 2D filtering of image stacks.
//This is automaticcaly called by the OCS and Filter2 functions, when appropriate.

Function OCS()

string topwave,twname

Twname=WinName(0,1,1)

if(stringmatch(TWname,""))
	topwave=""
else

	GetWindow $TWname, wavelist
	wave /t w_wavelist

	topwave = w_wavelist[0][0]
endif


Filter2($topWave)

string newname=topWave+"_fil"

Display/k=1
AppendImage $newName
DoUpDate
WMAppend3DImageSlider(); DoUpdate
SizeImage(300)

end

/////////////////////////////////////

Function Filter2(image)
	wave image
	Variable Filtering3D=0
	
	
	if ((wavedims(image) < 2) | (wavedims(image) > 3)) 
		String AbortStr=Nameofwave(image)+" is not an image/stack."
		Abort AbortStr
	endif
	
	duplicate /o/free image, f_image
	
	string method
	
	string methods = "Average;FindEdges;Gauss;Hybridmedian;Max;Median;Min;Point;PCA;Sharpen;Sharpenmore"
	variable eN = 3, ii, zDim
	
	zDim=DimSize(image,2)
	
	//prompt topwave, "Image", popup, WaveList("*",";","")
	prompt method, "Method",popup, methods
	prompt eN, "Filter Size/Number of Principal Components"
	prompt Filtering3D, "Filter in z-axis (0/1)?"
	
	doPrompt /help="ImageFilter" "Filter parameters for "+nameofwave(image), method,eN, Filtering3D
	
	if(v_flag)
		Abort
	endif
	
	if(wavedims(image) == 3 && Filtering3D >0)
	
		strswitch(method)
			case "average":
				imagefilter /n=(eN) /o avg3d f_image
			break
			
			case "Gauss":
				imagefilter /n=(eN) /o gauss3d f_image
			break
			
			case "Hybridmedian":
				imagefilter /o hybridmedian f_image
			break
			
			case "Max":
				imagefilter /n=(eN) /o max3d f_image
			break
			
			case "Median":
				imagefilter /n=(eN) /o median3d f_image
			break
			
			case "Min":
				imagefilter /n=(eN) /o min3d f_image
			break
			
			case "Point":
				imagefilter /n=(eN) /o point3d f_image
			break
			
			case "PCA":
				 Wave PCA_res=SmoothByPCA(f_image, eN)
				 Fastop f_image=PCA_res
				Killwaves/z PCA_res, m_r, m_c, wv2dx
			break
			
			case "FindEdges":
				Print "FindEdges is a 2D-only method. Running 2D..."
				ImageStackFilter(f_image, eN, method)
			break
			
			case "Sharpen":
				Print "Sharpen is a 2D-only method. Running 2D..."
				ImageStackFilter(f_image, eN, method)
			break
			
			case "Sharpenmore":
				Print "Sharpen is a 2D-only method. Running 2D..."
				ImageStackFilter(f_image, eN, method)
			break
			
		endswitch
		
	elseif(wavedims(image) == 3 && Filtering3D <=0)
	
	
	//2D stack filtering
	strswitch(method)			
			case "PCA":
				 Wave PCA_res=SmoothByPCA(f_image, eN)
				 MultiThread f_image=PCA_res
				 Killwaves/z PCA_res, m_r, m_c, wv2dx
			break
			
			case "Hybridmedian":
				Print "Hybridmedian is a 3D-only method. Running 3D..."
				imagefilter /o hybridmedian f_image
			break
			
			Default:
				ImageStackFilter(f_image, eN, method)
			break
			
		endswitch
		
		
		
		
	Elseif(wavedims(image) == 2)
	
		strswitch(method)
			case "average":
				imagefilter /n=(eN) /o avg f_image
			break
			
			case "Gauss":
				imagefilter /n=(eN) /o gauss f_image
			break
			
			case "Hybridmedian":
				imagefilter /o FindEdges f_image
			break
			
			case "Max":
				imagefilter /n=(eN) /o max f_image
			break
			
			case "Median":
				imagefilter /n=(eN) /o median f_image
			break
			
			case "Min":
				imagefilter /n=(eN) /o min f_image
			break
			
			case "Point":
				imagefilter /n=(eN) /o point f_image
			break
			
			case "PCA":
				Abort "PCA works only with stacks"
			break
			
		endswitch
	
	
	Else
		abort "This Wave doesn't seem to be an image"
	endif
	
	string newname=nameofwave(image)+"_fil"
	
	duplicate /o f_image, $(newname)
	wave w=$(newname)

return 1
end

//////////////////////////Smoothing by PCA//////////////////////////////////

Function/wave Make2Dx(wv)		//convert 3D to 2D
	Wave wv
	
	Variable xd, yd, zd, ii, arow, acol
	
	xd = dimsize(wv,0)
	yd = DimSize(wv,1)
	zd = DimSize(wv,2)
	
	Make /o/n=(zd,xd*yd) wv2Dx
	
	
	for(ii=0;ii<xd*yd;ii+=1)
	
		arow = mod(ii,xd)
		acol = floor(ii/xd)
		
		Matrixop/o/free Beams = Beam(wv,arow,acol)
	
		wv2dx[][ii] = Beams[p]
		
	endfor
	
	setscale/p x,DimOffSet(wv,2),DimDelta(wv,2),WaveUnits(wv,2) wv2dx
	
	return wv2dx
end

///////////////////////////////////////////

Function/wave Make3Dx(wv,xd,yd)		//reverse Make2Dx
	Wave wv
	Variable xd, yd
	
	Variable ii, zd, arow, acol, npts
	
	
	zd=dimsize(wv,0)
	npts = xd*yd
	
	if(DimSize(wv,1) !=  npts)
		Abort "Mismatch"
	endif	
	
	Make /o/n=(xd,yd,zd) wv3D = NaN
	
	for(ii=0;ii<yd;ii+=1)
	
		arow = mod(ii,yd)
		acol = trunc(ii/xd)
	
		wv3d[][ii][] = wv[r][p+ii*(xd)]
	
	
	endfor

	
	return wv3d		//unscaled
end

/////////////////////////////////////////

Function/wave SmoothByPCA(wv, PC)
	Wave wv
	variable PC 		//number of principal components to leave
	
	Variable xdim, ydim
	

	xdim = dimsize(wv,0)
	ydim = dimsize(wv,1)

	Wave wv2d = Make2Dx(wv)

	pca /q/scmt/srmt/leiv wv2d
	

	
	wave M_R, M_C
	
	Duplicate/o/free M_R MRMod
	
	MRMod = 0
	MRMod[][0,PC-1] = M_R
	
	MatrixOP/o/free smooth2D=MRMod x M_C
	
	Wave Smoothed = Make3Dx(smooth2D,xdim,ydim)
	
	CopyScaling(wv,smoothed)
	
	return smoothed


End


///////////////////////////////////////////////////////////////


Function ImageStackFilter(wv, n, method)
	Wave Wv
	Variable n 
	String method
	//methods: avg; FindEdges; gauss; max; median; min; point; sharpen; sharpenmore
	
	Variable numPlanes
	
	numPlanes=DimSize(wv,2)


	// Create a wave to hold data folder references returned by Worker.
	// /DF specifies the data type of the wave as "data folder reference".
	Make/O/Free/DF/N=(numPlanes) dfw

	
	MultiThread dfw= ImageStackFilter_Worker(wv,p, n, method)

	
	// At this point, dfw holds data folder references to numPlanes free
	// data folders created by Worker. Each free data folder holds the
	// extracted and filtered data for one plane of the source 3D wave.

	// Create an output wave named out3D by cloning the first filtered plane
	DFREF df= dfw[0]
	Duplicate/O/free df:M_ImagePlane, out3D

	// Concatenate the remaining filtered planes onto out3D
	Variable ii
	for(ii=1; ii<numPlanes; ii+=1)
		df= dfw[ii]			// Get a reference to the next free data folder
		Concatenate {df:M_ImagePlane}, out3D
	endfor
	
	Fastop wv = out3d		//overwrite wv 
	
	// dfw holds references to the free data folders. By killing dfw,
	// we kill the last reference to the free data folders which causes
	// them to be automatically deleted. Because there are no remaining
	// references to the various M_ImagePlane waves, they too are
	// automatically deleted.
//	KillWaves dfw
End


// Extracts a plane from the 3D input wave, filters it, and returns the
// filtered output as M_ImagePlane in a new free data folder
ThreadSafe Static Function/DF ImageStackFilter_Worker(w3DIn, plane, n, method)
	WAVE w3DIn
	Variable plane, n
	String method
	
	//methods correspond to methods in MatrixFilter

	
	DFREF dfSav= GetDataFolderDFR()

	// Create a free data folder to hold the extracted and filtered plane 
	DFREF dfFree= NewFreeDataFolder()
	SetDataFolder dfFree
	
	// Extract the plane from the input wave into M_ImagePlane.
	// M_ImagePlane is created in the current data folder
	// which is a free data folder.
	ImageTransform/P=(plane) getPlane, w3DIn
	Wave M_ImagePlane

	// Filter the plane
	StrSwitch(method)
		Case "Average":
		Case "avg":
			MatrixFilter/O/N=(n) Avg,M_ImagePlane
		break
		
		Case "FindEdges":
			MatrixFilter/O FindEdges,M_ImagePlane
		break
		
		Case "gauss":
			MatrixFilter/O/N=(n) gauss,M_ImagePlane
		break
		
		Case "max":
			MatrixFilter/O/N=(n) max,M_ImagePlane
		break
		
		Case "median":
			MatrixFilter/O/N=(n) median,M_ImagePlane
		break
		
		Case "NaNZapMedian":
			MatrixFilter/O/N=(n) NaNZapMedian,M_ImagePlane
		break
		
		Case "min":
			MatrixFilter/O/N=(n) min,M_ImagePlane
		break
		
		Case "point":
			MatrixFilter/O point,M_ImagePlane
		break
		
		Case "sharpen":
			MatrixFilter/O sharpen,M_ImagePlane
		break
		
		Case "sharpenmore":
			MatrixFilter/O sharpenmore,M_ImagePlane
		break		
		
		Default:
			MatrixFilter/O/N=(n) avg,M_ImagePlane
		break
		
	Endswitch
	
	
	SetDataFolder dfSav

	// Return a reference to the free data folder containing M_ImagePlane
	return dfFree
End