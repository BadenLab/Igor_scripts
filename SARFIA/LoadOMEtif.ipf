#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "RegisterStack"
//Loads OME tif movies stored in single tif files 
//with a filename format xxx0000.tif or xxxx0000.ome.tif
//start specifies the first frame to be loaded
//NOTE: always choose the first file which contains the header info
//delta specifies if files should be skipped
//num specifies how many frames are loaded

// LoadOMEtifMenu()		//Popup menu with the option to skip frames (or load all)
// LoadOMEtifMenuAvg()	//Popup menu with the option to average frames



Function /t LoadOMEmovie([start, delta, num, resultname])
	Variable start, delta, num
	string resultname

	String ImgWaveName, FirstWave
	string header, s_info = "No header info available\r"
	Variable PointPos, ii, nImages, nFrames, fCount, nSteps, deltaT
	String PathAndFile, C1WaveName, ext, fName, fPath
	
	If(ParamIsDefault(start))
		start=0
	Endif
	
	If(ParamIsDefault(delta))
		delta=1
	Endif
	
	If(ParamIsDefault(num))
		num=inf
	Endif
	
	ImageLoad /Q /O /C=-1 /N=w_omeLoad
	
	if (v_flag == 0)
		return "-1"
	endif

	header = s_info
	PointPos = strsearch(S_Filename, ".ome.tif", 0)
	ext=".ome.tif"
	if(pointpos==-1)
		PointPos = strsearch(S_Filename, ".tif", 0)
		ext=".tif"
	endif
	
	ImgWaveName = S_FileName[0,PointPos-1]
	fName=S_FileName[0,PointPos-5]
	ImgWaveName = ReplaceString("-", ImgWaveName, "_")
	fPath=s_Path
	
	PointPos = strsearch(S_Wavenames, ";", 0)
	FirstWave =S_Wavenames[0,PointPos-1]
	
	if(ParamIsDefault(resultname))
		resultname=ImgWaveName
	endif


	duplicate /o $FirstWave, $ResultName
	Killwaves /z $FirstWave
	
	Wave ImageStack = $ResultName
	Wave HeaderInfo = OMEheaderinfo(header)
	

	Note ImageStack, header
	Note ImageStack, "file.path="+s_path
	Note ImageStack, "file.name="+s_filename

	
	nImages=HeaderInfo[%sizeT]
	nFrames=round(HeaderInfo[%sizeT]/delta)

	redimension /s ImageStack		//convert to single precision floating point
									//Comment: large resolution files may exceed the system's memory when converted to double-precision FP
	
//	num = start > 0 ? num : num-1					//reduce num by 1 if start >= 0 
	nSteps = num<nFrames ? num : nFrames		//nSteps is the smaller of num and nFrames 
	
//load rest of movie
	For(ii=start,fCount=0;ii<nImages&&fCount<num;ii+=delta,fCount+=1)
		Prog("Loading",fCount,nSteps)
	
	
		sprintf pathandfile, fPath+fName+"%04.0f"+ext, ii		//generate filename with 4 digit num

			ImageLoad /o/q/t=tiff/c=1 pathandfile
			if(v_flag==0)		//no image found?
				break
			endif
		
		C1WaveName=StringFromList(0, S_waveNames)
		Wave NewFrame = $C1WaveName		
		Redimension/s NewFrame
		
		Concatenate/o/NP=2 {ImageStack, NewFrame}, m_output
		Duplicate/o m_output, ImageStack
		
		KillWaves NewFrame
	endfor

//scaling

	deltaT = delta * HeaderInfo[%TimeIncrement]

	
	SetScale /p x,0,HeaderInfo[%SizeX]/1e6,"m", ImageStack		//"PhysicalSizeX" = pixel size in µm?
	SetScale /p y,0,HeaderInfo[%SizeY]/1e6,"m", ImageStack		//"PhysicalSizeY" = pixel size in µm?
	SetScale /p z,0,deltaT,"s", ImageStack

//clean up
	
	deletepoints/m=2 0,1, ImageStack			//delete 1st frame because it occurs twice
	

	KillWaves/z NewFrame, m_output, HeaderInfo		
	Return ImgWaveName
End

/////////////////////////////////////////////////////////////////////////

Function/wave LoadOMEmovie2(PathAndFile0, [start, delta, num, resultname,pixelate])		//takes PathAndFile as a parameter for use from other functions
	String PathAndFile0
	Variable start, delta, num, pixelate
	string resultname

	String ImgWaveName, FirstWave
	string header, s_info = "No header info available\r"
	Variable PointPos, ii, nImages, nFrames, fCount, nSteps, deltaT
	String  C1WaveName, ext, fName, fPath, PathAndFile
	
	If(ParamIsDefault(start))
		start=0
	Endif
	
	If(ParamIsDefault(delta))
		delta=1
	Endif
	
	If(ParamIsDefault(num))
		num=inf
	Endif
	
	If(ParamIsDefault(pixelate))
		pixelate=1
	Endif
	
	ImageLoad /Q /O /C=-1 /N=w_omeLoad PathAndFile0
	
	AbortOnValue v_flag==0, 0

	header = s_info
	PointPos = strsearch(S_Filename, ".ome.tif", 0)
	ext=".ome.tif"
	if(pointpos==-1)
		PointPos = strsearch(S_Filename, ".tif", 0)
		ext=".tif"
	endif
	
	ImgWaveName = S_FileName[0,PointPos-1]
	fName=S_FileName[0,PointPos-5]
	ImgWaveName = ReplaceString("-", ImgWaveName, "_")
	fPath=s_Path
	
	PointPos = strsearch(S_Wavenames, ";", 0)
	FirstWave =S_Wavenames[0,PointPos-1]
	
	if(ParamIsDefault(resultname))
		resultname=ImgWaveName
	endif


	duplicate /o $FirstWave, $ResultName
	Killwaves /z $FirstWave
	
	Wave ImageStack = $ResultName
	Wave HeaderInfo = OMEheaderinfo(header)
	

	Note ImageStack, header
	Note ImageStack, "file.path="+s_path
	Note ImageStack, "file.name="+s_filename

	
	nImages=HeaderInfo[%sizeT]
	nFrames=round(HeaderInfo[%sizeT]/delta)

	redimension /s ImageStack		//convert to single precision floating point
	if(pixelate>1)
		ImageInterpolate/pxsz={pixelate,pixelate} pixelate ImageStack
		Wave M_PixelatedImage
		Duplicate/o M_Pixelatedimage ImageStack
		Killwaves M_PixelatedImage
	endif
									//Comment: large resolution files may exceed the system's memory when converted to double-precision FP
	
	num = start > 0 ? num : num-1					//reduce num by 1 if start >= 0 
	nSteps = num<nFrames ? num : nFrames		//nSteps is the smaller of num and nFrames 
	
//load rest of movie
	For(ii=start,fCount=0;ii<nImages&&fCount<num;ii+=delta,fCount+=1)
		Prog("Loading",fCount,nSteps)
	
	
		sprintf pathandfile, fPath+fName+"%04.0f"+ext, ii		//generate filename with 4 digit num

			ImageLoad /o/q/t=tiff/c=1 pathandfile
			if(v_flag==0)		//no image found?
				break
			endif
		
		C1WaveName=StringFromList(0, S_waveNames)
		Wave NewFrame = $C1WaveName		
		Redimension/s NewFrame
		
		Concatenate/o/NP=2 {ImageStack, NewFrame}, m_output
		Duplicate/o m_output, ImageStack
		
		KillWaves NewFrame
	endfor

//scaling
	deltaT = delta * HeaderInfo[%TimeIncrement]

	SetScale /p x,0,HeaderInfo[%SizeX]/1e6,"m", ImageStack		//"PhysicalSizeX" = pixel size in µm?
	SetScale /p y,0,HeaderInfo[%SizeY]/1e6,"m", ImageStack		//"PhysicalSizeY" = pixel size in µm?
	SetScale /p z,0,deltaT,"s", ImageStack

//clean up
							//delete 1st frame because it occurs twice
		deletepoints/m=2 0,1, ImageStack

	KillWaves/z NewFrame, m_output, HeaderInfo		
	Return ImageStack
End

////////////////////////////////////////////////////////////////////////



Function/wave OMEheaderinfo(header)
	string header
	
	string pid, xs, ys, ts, ti
	variable len
	
	Make/o/n=4 w_HeaderInfo
	SetDimLabel 0,0, SizeX,w_HeaderInfo
	SetDimLabel 0,1, SizeY, w_HeaderInfo
	SetDimLabel 0,2, SizeT, w_HeaderInfo
	SetDimLabel 0,3, TimeIncrement, w_HeaderInfo
			
	pid=stringfromlist(11, header, "\r")
	
	len= strlen(pid)
	pid=pid[1,len-1]		//remove <>
	
	xs=stringbykey("PhysicalSizeX", pid, "=", " ")
	len= strlen(xs)
	xs=xs[1,len-1]		//remove ""
	
	ys=stringbykey("PhysicalSizeY", pid, "=", " ")
	len= strlen(ys)
	ys=ys[1,len-1]		//remove ""
	
	ts=stringbykey("SizeT", pid, "=", " ")
	len= strlen(ts)
	ts=ts[1,len-1]		//remove ""
	
	ti=stringbykey("TimeIncrement", pid, "=", " ")
	len= strlen(ti)
	ti=ti[1,len-1]		//remove ""
	
	w_HeaderInfo[%SizeX]=str2num(xs)
	w_HeaderInfo[%SizeY]=str2num(ys)
	w_HeaderInfo[%SizeT]=str2num(ts)
	w_HeaderInfo[%TimeIncrement]=str2num(ti)
	
	return w_HeaderInfo
end


////////////////////////////////////////////////////////////////////////

Function LoadOMEtifMenu()

	Variable refNum = 0
	String fnameStr=""
	Open/D/R/T=".tif" refNum	// Not a real open - just returns S_fileName
	
	fnameStr = S_fileName		// S_fileName contains full filename returned from Open
	if (strlen(fnameStr) == 0)
		return -1
	endif
	
	Variable start=0, delta=1, num=inf
	String resultname = "_FileName_"
	
	Prompt start, "First frame to load"
	Prompt delta, "Load every nth frame"
	Prompt num, "Number of frames to load"
	Prompt resultname, "Name of loaded movie in Igor"
	
	DoPrompt /help="I can't help you :-\ " "Enter parameters", start, delta, num, resultname
	
	if(v_flag)
		return -1
	endif
	
	if (stringmatch(resultname,  "_FileName_"))	
		LoadOMEmovie2(fNameStr, start=start, delta=delta, num=num)
	else
		LoadOMEmovie2(fNameStr, start=start, delta=delta, num=num, resultname=resultname)
	endif
	
End





////////////////////////////////////////////////////////////////////////////////////////

Function/wave LoadOMEmovieFrameAveraging2(PathAndFile0, [start, avg, num, resultname,registration,pixelate])		//takes PathAndFile as a parameter for use from other functions
	String PathAndFile0
	Variable start, avg, num
	string resultname
	Variable registration, pixelate

	String ImgWaveName, FirstWave
	string header, s_info = "No header info available\r"
	Variable PointPos, ii, nImages, nFrames, fCount, nSteps, deltaT, jj, FrameNum
	String  C1WaveName, ext, fName, fPath, PathAndFile, regTarget
	
	If(ParamIsDefault(start))
		start=0
	Endif
	
	If(ParamIsDefault(avg))
		avg=1
	Endif
	
	If(ParamIsDefault(num))
		num=inf
	Endif
	
	If(ParamIsDefault(registration))
		registration=1
	Endif
	
	If(ParamIsDefault(pixelate))
		pixelate=0
	Endif
	
	ImageLoad /Q /O /C=-1 /N=w_omeLoad PathAndFile0
	
	AbortOnValue v_flag==0, 0
	

	header = s_info
	PointPos = strsearch(S_Filename, ".ome.tif", 0)
	ext=".ome.tif"
	if(pointpos==-1)
		PointPos = strsearch(S_Filename, ".tif", 0)
		ext=".tif"
	endif
	
	ImgWaveName = S_FileName[0,PointPos-1]
	fName=S_FileName[0,PointPos-5]
	ImgWaveName = ReplaceString("-", ImgWaveName, "_")
	fPath=s_Path
	
	PointPos = strsearch(S_Wavenames, ";", 0)
	FirstWave =S_Wavenames[0,PointPos-1]
	
	if(ParamIsDefault(resultname))
		resultname=ImgWaveName
	endif


	duplicate /o $FirstWave, $ResultName
	Killwaves /z $FirstWave
	
	Wave ImageStack = $ResultName
	Wave HeaderInfo = OMEheaderinfo(header)
	
	Make/o/free/n=(DimSize(ImageStack,0)/pixelate,DimSize(ImageStack,1)/pixelate,avg) ToBeAveraged

	Note ImageStack, header
	Note ImageStack, "file.path="+s_path
	Note ImageStack, "file.name="+s_filename

	
	nImages=HeaderInfo[%sizeT]
	nFrames=round(HeaderInfo[%sizeT]/avg)

	redimension /s ImageStack		//convert to single precision floating point
	if(pixelate>1)
		PixelateImage(ImageStack, pixelate)
	endif
									//Comment: large resolution files may exceed the system's memory when converted to double-precision FP
	
//	num = start > 0 ? num : num-1					//reduce num by 1 if start >= 0 
	nSteps = num<nFrames ? num : nFrames		//nSteps is the smaller of num and nFrames 
	
//load rest of movie
	For(ii=start,fCount=0;ii<nImages&&fCount<num;ii+=avg,fCount+=1)
		Prog("Loading",fCount,nSteps)
	
	
		For(jj=0;jj<avg;jj+=1)
		
			FrameNum=ii+jj
		
			sprintf pathandfile, fPath+fName+"%04.0f"+ext, FrameNum		//generate filename with 4 digit num
	
				ImageLoad /o/q/t=tiff/c=1 pathandfile
				if(v_flag==0)		//no image found?
					break
				endif
			
			
			C1WaveName=StringFromList(0, S_waveNames)
			Wave NewFrame = $C1WaveName		
			Redimension/s NewFrame
			
			if(pixelate>1)
				PixelateImage(NewFrame, pixelate)
			endif
			
			ToBeAveraged[][][jj]=NewFrame[p][q]
			
			KillWaves NewFrame
		Endfor
		
		If(Registration)			//image registration
			RegisterStack(ToBeAveraged,target="w_tbareg")
			Wave w_tbareg
			Duplicate/o/free w_tbareg, ToBeAveraged		//overwrite
			Killwaves w_tbareg
		EndIf
		
		
		ImageTransform averageimage ToBeAveraged		//average frames
		Wave M_AveImage, M_StdvImage
		
		Concatenate/o/NP=2 {ImageStack, M_AveImage}, m_output
		Duplicate/o m_output, ImageStack
		
		KillWaves NewFrame, M_AveImage, M_StdvImage
	endfor

//scaling
	deltaT = avg * HeaderInfo[%TimeIncrement]

	SetScale /p x,0,HeaderInfo[%SizeX]/1e6,"m", ImageStack		//"PhysicalSizeX" = pixel size in µm?
	SetScale /p y,0,HeaderInfo[%SizeY]/1e6,"m", ImageStack		//"PhysicalSizeY" = pixel size in µm?
	SetScale /p z,0,deltaT,"s", ImageStack

//clean up
								//delete 1st frame
		deletepoints/m=2 0,1, ImageStack


	KillWaves/z NewFrame, m_output, HeaderInfo		
	Return ImageStack
End


////////////////////////////////////////////////////////////////////////

Function LoadOMEtifMenuAvg()

	Variable refNum = 0
	String fnameStr=""
	Open/D/R/T=".tif" refNum	// Not a real open - just returns S_fileName
	
	fnameStr = S_fileName		// S_fileName contains full filename returned from Open
	if (strlen(fnameStr) == 0)
		return -1
	endif
	
	Variable start=0, delta=1, num=inf, register = 1, pixelate=4
	String resultname = "_FileName_"
	
	Prompt start, "First frame to load"
	Prompt delta, "Average every n frames"
	Prompt register, "Register frames before averaging? (0/1)"
	Prompt num, "Number of frames to load"
	Prompt pixelate, "Bin factor"
	Prompt resultname, "Name of loaded movie in Igor"
	
	DoPrompt /help="I can't help you :-\ " "Enter parameters", start, delta, num,register, pixelate, resultname
	
	if(v_flag)
		return -1
	endif
	
	if (stringmatch(resultname,  "_FileName_"))	
		LoadOMEmovieFrameAveraging2(fNameStr, start=start, avg=delta, num=num, registration=register)
	else
		LoadOMEmovieFrameAveraging2(fNameStr, start=start, avg=delta, num=num, resultname=resultname, registration=register)
	endif
	
End

////////////////////////////////////////////////////////////////////////

Function PixelateImage(image, n, [m])			//pixelates and copies scaling
	Wave Image
	variable n, m
	
	if(ParamIsDefault(m))
		m=n
	EndIf
	
	
	ImageInterpolate/pxsz={n,m} pixelate image
	Wave M_PixelatedImage
	
	CopyScales /I image, M_PixelatedImage
	
	Duplicate/o  M_PixelatedImage, image
	
	KillWaves M_PixelatedImage
	
End