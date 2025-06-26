#pragma rtGlobals=1		// Use modern global access method.
#include "Progress Window"
constant Z_factor = 4, ImageLength = 665.6

//Z_factor is the factor by which distances in the z dimension have to be multiplied in order to return actual distances in µm. 
//This is important only for the correct scaling of image stacks, not for single images or movies.
//ImageLength is the side length in µm of an image taken at zoom 1. This will, among other factors, depend on the objective used.

//For images saved with a different program, only basic functionality (i.e. loading of image stacks or file sequences) is available.
// LoadGenericMovie(PathAndFile0, [num, digits]): loads sequentially numbered sequences of tiff files. PathAndFile0 is the path 
// to the first image to be loaded, such as provided by the Open operation; num is the maximum number of images to be loaded 
//(may terminate earlier if no more files are found); digits is the number of digits in the file naming scheme at the end of the filename
// (i.e., filename0000.tiff; default is 4).
//LGM() aks the user to specify a file and then calls LoadGenericMovie on that with default parameters.


//02/02/2010 MMD: added version support for msPerLineFromHeader
//26/04/2010 MMD: added AverageFrames(imStack, n) and AutoAverageFrames(imStack)
//13/05/2015 MMD: added  LoadGenericMovie(PathAndFile0, [num, digits]) and LGM()

//////////////////////////////////////////////////


Function /t LoadScanImage()

String ImgWaveName, FirstWave
string header, s_info = "No header info available\r"
Variable PointPos

ImageLoad /Q /O /C=-1

if (v_flag == 0)
	return "-1"
endif

	header = s_info
	PointPos = strsearch(S_Filename, ".tif", 0)
	ImgWaveName = S_FileName[0,PointPos-1]
	ImgWaveName = ReplaceString("-", ImgWaveName, "_")
	
	PointPos = strsearch(S_Wavenames, ";", 0)
	FirstWave =S_Wavenames[0,PointPos-1]
	
if (waveexists($ImgWaveName))
	killwaves /z $ImgWaveName
endif


duplicate /o $FirstWave, $ImgWaveName
Killwaves /z $FirstWave



Note $ImgWaveName, header
Note $ImgWaveName, "file.path="+s_path
Note $ImgWaveName, "file.name="+s_filename

redimension /s $ImgWaveName		//convert to single precision floating point
									//Comment: large resolution files may exceed the system's memory when converted to double-precision FP

Return ImgWaveName
End

//////////////////////////////////////////////////////

Function /wave AutoLoadScanImage(pathstr, filenamestr)			//Does not open a file dialogue, takes path and filename as input parameters
	String pathstr, filenamestr

	String ImgWaveName, FirstWave
	string header, s_info = "No header info available\r"
	Variable PointPos
	
	NewPath/o/q path, pathstr
	
	ImageLoad /Q /O /C=-1/p=path filenamestr
	
	if (v_flag == 0)
		Abort
	endif
	
		header = s_info
		PointPos = strsearch(S_Filename, ".tif", 0)
		ImgWaveName = S_FileName[0,PointPos-1]
		ImgWaveName = ReplaceString("-", ImgWaveName, "_")
		
		PointPos = strsearch(S_Wavenames, ";", 0)
		FirstWave =S_Wavenames[0,PointPos-1]
		
	if (waveexists($ImgWaveName))
		killwaves /z $ImgWaveName
	endif
	
	
	duplicate /o $FirstWave, $ImgWaveName
	Killwaves /z $FirstWave
	
	redimension /d $ImgWaveName		//convert to double precision floating point
	
	Note $ImgWaveName, header
	Note $ImgWaveName, "file.path="+s_path
	Note $ImgWaveName, "file.name="+s_filename
	
	Wave ReturnWv =  $ImgWaveName
	Return ReturnWv
End

//////////////////////////////////////////////////////

Function ZoomFromHeader(PicWave)
wave  Picwave
variable ZoomFactor
string header = note(PicWave)

ZoomFactor = NumberByKey("state.acq.zoomones", Header, "=","\r")
ZoomFactor += 10 * NumberByKey("state.acq.zoomtens", Header, "=","\r")
ZoomFactor += 100 * NumberByKey("state.acq.zoomhundreds", Header, "=","\r")

//ZoomFactor *= NumberByKey("state.acq.zoomFactor", HeaderWave[12], "=")	//? check for errors

Return ZoomFactor
End

//////////////////////////////////////////////////////

Function FramesFromHeader(PicWave)
wave PicWave
variable Frames
string header = note(PicWave)

Frames = NumberByKey("state.acq.numberOfFrames", Header, "=","\r")

return Frames
End

//////////////////////////////////////////////////////

Function XRelFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

return NumberByKey("state.motor.relXPosition", Header, "=","\r")

End
//////////////////////////////////////////////////////

Function YRelFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

return NumberByKey("state.motor.relYPosition", Header, "=","\r")

End
//////////////////////////////////////////////////////
Function /t FilePathFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

return StringByKey("file.path", Header, "=","\r")

End
//////////////////////////////////////////////////////
Function /t FilenameFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

return StringByKey("file.name", Header, "=","\r")

End

//////////////////////////////////////////////////////


Function ZRelFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

return NumberByKey("state.motor.relZPosition", Header, "=","\r")

End
//////////////////////////////////////////////////////

Function msPerLineFromHeader(PicWave)
wave PicWave
string header = note(PicWave)
variable result, version

version = ScanImageVersionFromHeader(PicWave)

if(version > 3)
	result = NumberByKey("state.acq.msPerLine", Header, "=","\r")
else
	result = 1000*NumberByKey("state.acq.msPerLine", Header, "=","\r")
endif

Return result

End

//////////////////////////////////////////////////////

Function sPerLineFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

variable result, version

version = ScanImageVersionFromHeader(PicWave)

if(version > 3)
	result = NumberByKey("state.acq.msPerLine", Header, "=","\r")/1000
else
	result = NumberByKey("state.acq.msPerLine", Header, "=","\r")
endif

Return result

End

//////////////////////////////////////////////////////

Function /t ExpDateFromHeader(PicWave)
wave PicWave
string header = note(PicWave)
string ExpDate, month, day, year, ExpTime
variable pointer

ExpDate = StringByKey("state.internal.triggerTimeString", Header, "=","\r")
if (stringmatch(expdate, ""))
	return ""
endif

ExpDate = ReplaceString("'", ExpDate, "")

if(stringmatch(ExpDate[1], "/"))
	Month = "0"+ExpDate[0]
	pointer = 1
Elseif(stringmatch(ExpDate[2], "/"))
	Month = ExpDate[0,1]
	pointer = 2
else
	DoAlert 0, "Something's wrong with the date..."
	return ""
endif

if(stringmatch(ExpDate[pointer+2], "/"))
	Day = "0"+ExpDate[pointer+1]
	pointer += 1
Elseif(stringmatch(ExpDate[pointer+3], "/"))
	Day = ExpDate[pointer+1,pointer+2]
	pointer += 2
else
	DoAlert 0, "Something's wrong with the day..."
	return ""
endif

year = ExpDate[pointer+2, pointer+5]

ExpTime=ExpDate[pointer+7, pointer+14]

string result = Day+"/"+Month+"/"+Year+" "+ExpTime

Return Result
End

//////////////////////////////////////////////////////

Function ZSlicesFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

Return NumberByKey("state.acq.numberOfZSlices", Header, "=","\r")

End

//////////////////////////////////////////////////////

Function ZStepsizeFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

Return NumberByKey("state.acq.zStepSize", Header, "=","\r")

End

//////////////////////////////////////////////////////

Function ScanImageVersionFromHeader(PicWave)
wave PicWave
string header = note(PicWave)

Return NumberByKey("state.software.version", Header, "=","\r")

End

//////////////////////////////////////////////////////

function ApplyHeaderInfo(Wave3D)
	wave wave3D
	variable x_res,y_res,z_res, slices, stepsize
	
	variable Zoom=ZoomFromHeader(Wave3D)
	
	if(NumType(Zoom) == 2)			//break, if no ScanImage header info available
		return -1
	endif
	
	variable timeperline=sPerLineFromHeader(Wave3D), nChannels
	
	x_res = ImageLength/ zoom / dimsize(wave3d,0)*1e-6	//in m
	y_res = ImageLength / zoom / dimsize(wave3d,1)*1e-6	//in m
	z_res = timeperline *  dimsize(wave3d,1)	//in s
	slices = ZSlicesFromHeader(wave3d)
	stepsize= ZStepsizeFromHeader(wave3d) * z_factor*1e-6 //in m
	
	
	setscale /P x, 0, x_res,"m",wave3d
	setscale /P y, 0, y_res,"m",wave3d
	
	if(slices > 1)
		setscale /P z, 0, stepsize,"m",wave3d
	else
		setscale /P z, 0, z_res,"s",wave3d
	endif

end

////////////////////////////////////////////////

function /t LoadMovie()		//loads a ScanImage movie from multiple files

String ImgWaveName, FirstWave, FileName, FNTrunc, FNNum, FNPath, StrNum
	string  header, s_info = "No header info available\r"
	Variable PointPos, startnum, cont = 1, newframes,currentframes, frames
	
	ImageLoad /Q /O /C=-1
	
	if (v_flag == 0)
		return "-1"
	endif
	
		header = s_info
		PointPos = strsearch(S_Filename, ".tif", 0)
		ImgWaveName = S_FileName[0,PointPos-1]
		FileName = S_FileName[0,PointPos-1]
		ImgWaveName = ReplaceString("-", ImgWaveName, "_")
		PointPos = strsearch(S_Wavenames, ";", 0)
		FirstWave =S_Wavenames[0,PointPos-1]
		FNPath = S_Path
	
		StrNum=FileName[strlen(FileName)-3,strlen(FileName)-1]	//last 3 characters in FileName
		StartNum=Str2Num(StrNum)
		if(NumType(StartNum==2))
			DoAlert 0, "The last three characters of the filename are not numbers."
			return "-1"
		endif
	
		FNTrunc = FileName[0,strlen(FileName)-4]
		
	if (waveexists(:tw0))
		killwaves /z tw0
	endif
		
	duplicate /o/free $FirstWave, TempImage
	killwaves /z  $FirstWave
	
	
	variable refnum
	
	string fn2
	
	Do
		startnum +=1
		currentframes=dimsize(TempImage,2)
		
		if (startnum < 10)
			FNNum = "00"+Num2Str(startnum)
		elseif (startnum < 100)
			FNNum = "0"+Num2Str(startnum)
		else
			FNNum = Num2Str(startnum)
		endif
			
		FileName = 	FnPath+FNTrunc+FNNum+".tif"
		fn2 = 	FnPath+FNTrunc+FNNum
		open /z=1 /r  refnum as FileName
		
		if (v_flag==0)
			ImageLoad /c=-1 /n=tw /o /q FileName
			
			
			PointPos = strsearch(S_Wavenames, ";", 0)
			FirstWave =S_Wavenames[0,PointPos-1]
			Wave sec = $firstwave
			
			
			frames=dimsize(sec,2)
			if(frames==0)
				frames = 1
			endif
			
			newframes=currentframes+frames
			
			redimension/n=(-1,-1,newframes) TempImage
			
			TempImage[][][currentframes,newframes-1] = sec[p][q][r-currentframes]
			
									
			close refnum
			killwaves $firstwave
		else
			cont = 0
		endif
		
		
	While(cont)
	
	
	if (waveexists($ImgWaveName))
		killwaves /z $ImgWaveName
	endif
	
	
	duplicate /o TempImage, $ImgWaveName
	Killwaves /z $FirstWave, TempImage
	
	redimension /s $ImgWaveName		//convert to single precision floating point
	
	
	Note $ImgWaveName, header
	Note $ImgWaveName, "file.path="+s_path
	Note $ImgWaveName, "file.name="+s_filename
	
	Print "Saved as "+ ImgWaveName
	
	Return ImgWaveName
End

///////////////////////////////////////////////////////

function /t LoadMovie2([step])		//loads a ScanImage movie from multiple files
	Variable step

	String ImgWaveName, FirstWave, FileName, FNTrunc, FNNum, FNPath, StrNum
	string  header, s_info = "No header info available\r"
	Variable PointPos, startnum, cont = 1, newframes,currentframes, frames
	
	if (paramisdefault(step))
		step=1
	endif
	
	ImageLoad /Q /O /C=-1
	
	if (v_flag == 0)
		return "-1"
	endif
	
		header = s_info
		PointPos = strsearch(S_Filename, ".tif", 0)
		ImgWaveName = S_FileName[0,PointPos-1]
		FileName = S_FileName[0,PointPos-1]
		ImgWaveName = ReplaceString("-", ImgWaveName, "_")
		PointPos = strsearch(S_Wavenames, ";", 0)
		FirstWave =S_Wavenames[0,PointPos-1]
		FNPath = S_Path
	
		StrNum=FileName[strlen(FileName)-4,strlen(FileName)-1]	//last 3 characters in FileName
		StartNum=Str2Num(StrNum)
		if(NumType(StartNum==2))
			DoAlert 0, "The last four characters of the filename are not numbers."
			return "-1"
		endif
	
		FNTrunc = FileName[0,strlen(FileName)-5]
		
	if (waveexists(:tw0))
		killwaves /z tw0
	endif
		
	duplicate /o/free $FirstWave, TempImage
	killwaves /z  $FirstWave
	
	
	variable refnum
	
	string fn2
	
	Do
		
		startnum +=step
		currentframes=dimsize(TempImage,2)
		
		if (startnum < 10)
			FNNum = "000"+Num2Str(startnum)
		elseif (startnum < 100)
			FNNum = "00"+Num2Str(startnum)
		elseif (startnum < 1000)
			FNNum = "0"+Num2Str(startnum)
		else
			FNNum = Num2Str(startnum)
		endif
			
		FileName = 	FnPath+FNTrunc+FNNum+".tif"
		fn2 = 	FnPath+FNTrunc+FNNum
		open /z=1 /r  refnum as FileName
		
		if (v_flag==0)
			ImageLoad /c=-1 /n=tw /o /q FileName
			
			
			PointPos = strsearch(S_Wavenames, ";", 0)
			FirstWave =S_Wavenames[0,PointPos-1]
			Wave sec = $firstwave
			
			
			frames=dimsize(sec,2)
			if(frames==0)
				frames = 1
			endif
			
			newframes=currentframes+frames
			
			redimension/n=(-1,-1,newframes) TempImage
			
			TempImage[][][currentframes,newframes-1] = sec[p][q][r-currentframes]
			
									
			close refnum
			killwaves $firstwave
		else
			cont = 0
		endif
		
		
		Prog("Files loaded", startnum, startnum)
		
	While(cont)
	
	
	if (waveexists($ImgWaveName))
		killwaves /z $ImgWaveName
	endif
	
	
	duplicate /o TempImage, $ImgWaveName
	Killwaves /z $FirstWave, TempImage
	
	redimension /s $ImgWaveName		//convert to single precision floating point
	
	
	Note $ImgWaveName, header
	Note $ImgWaveName, "file.path="+s_path
	Note $ImgWaveName, "file.name="+s_filename
	
	Print "Saved as "+ ImgWaveName
	
	Return ImgWaveName
End



//////////////////////////////////////////////////////
// LoadFrap is a modification of LoadScanImage to load FRAP experiments
// saved in iVision (script?) on one specific microscope. It can be used as
// a template for similar procedures.

Function /t LoadFrap()

String ImgWaveName, FirstWave
Variable PointPos

ImageLoad /Q /O /C=-1

if (v_flag == 0)
	return "-1"
endif

	//removing the extension from the filename

	PointPos = strsearch(S_Filename, ".tif", 0)
	ImgWaveName = S_FileName[0,PointPos-1]
	ImgWaveName = ReplaceString("-", ImgWaveName, "_")
	
	PointPos = strsearch(S_Wavenames, ";", 0)
	FirstWave =S_Wavenames[0,PointPos-1]
	
if (waveexists($ImgWaveName))
	killwaves /z $ImgWaveName
endif


duplicate /o $FirstWave, $ImgWaveName
Killwaves /z $FirstWave

redimension /d $ImgWaveName		//convert to double precision floating point

setscale /p x,0,63e-6/512,"m" $ImgWaveName	//63µm is the side length of an image
setscale /p y,0,63e-6/512,"m" $ImgWaveName

variable zdim = 1

prompt  zdim, "Time between frames (s)"
doprompt "Enter variables", zdim
if(v_flag)
	setscale /p z,0,1,"Frame", $ImgWaveName
else
	setscale /p z,0,zdim,"s", $ImgWaveName
endif

Note $ImgWaveName, "file.path="+s_path
Note $ImgWaveName, "file.name="+s_filename

Return ImgWaveName

end


//////////////////////////////////////////////////////

Function nChannelsFromHeader(PicWave)
	wave PicWave
	string header = note(PicWave)
	
	Variable nChannels=0

	nChannels = NumberByKey("state.acq.savingChannel1", Header, "=","\r") + NumberByKey("state.acq.savingChannel2", Header, "=","\r") + NumberByKey("state.acq.savingChannel3", Header, "=","\r")

	return nChannels

End

//////////////////////////////////////////////////////

Function SplitChannels(PicWave,nChannels)
	wave PicWave
	variable nChannels
	
	variable nFrames = DimSize(PicWave,2), FramesPerChannel, Rest, ii
	String wvName
	FramesPerChannel=nFrames/nChannels
	Rest=FramesPerChannel-trunc(FramesPerChannel)
	
	if(Rest)
		Print "WARNING: inequal number of frames per channel."
		FramesPerChannel=trunc(FramesPerChannel)
	endif
	
	For(ii=0;ii<nChannels;ii+=1)
		wvName=NameOfWave(PicWave)+"_Ch"+Num2Str(ii+1)
		Duplicate /o PicWave $wvName
		wave w=$wvName
		Redimension/n=(-1,-1,FramesPerChannel) w
		MultiThread w=PicWave[p][q][r*nChannels+ii]	
	EndFor	
End

//////////////////////////////////////////////////////

Function/wave InvertImage(image)			//inverts an image
	Wave image
	
	Variable imax = WaveMax(image)
	String ResName = NameOfWave(image)+"_inv"
	
	Duplicate/o/free image inv_image
	
	FastOP inv_image = -1*image+(imax)
	
	Duplicate/o inv_image $ResName
	
	Return $ResName
End


//////////////////////////////////////////////////////

Function/wave AverageFrames(imStack, n)		//averages every n frames in a stack
	wave imStack
	variable n
	
	variable nFrames, ii, newn, start, stop
	string newname = NameOfWave(imStack)+"_av"+num2str(n)
	
	nFrames=DimSize(imStack,2)
	
	newn = round(nFrames/n)
	
	duplicate/o/free imStack, av_stack
	redimension/n=(-1,-1,newn) av_stack
	
	For(ii=0;ii<newn;ii+=1)
	
		start=ii*n
		stop=start+n-1
		
		duplicate/o/free /r=[0,*][0,*][start,stop] imStack, tobeAv
		
		MatrixOP /o/free avImage=sumBeams(tobeAv)/n
	
		av_stack[][][ii]=avImage[p][q]
	
	
	EndFor
	
	duplicate/o av_stack, $newName
	return $newName
End

//////////////////////////////////////////////////////

Function /wave AutoAverageFrames(imStack)
	wave imStack

	string header = note(imStack)
	variable n = NumberByKey("state.acq.numberOfFrames", Header, "=","\r")		//get n from Header

	if(numtype(n))
		Abort "unablo to retrieve state.acq.numberOfFrames from wave note."
	else
		wave result= AverageFrames(imStack, n)
	endif

	return result
End
	
	
//////////////////////////////////////////////////////	
	
	
Function/t LoadGenericMovie(PathAndFile0, [num, digits])
	String PathAndFile0
	Variable num, digits
	
	Variable pointpos
	Variable count, ii
	String prefix, suffix, ImgWaveName, fName, fPath, PathAndFile, numStr, fnumStr, ext
	string  header, s_info = "No header info available\r"
	
	If(ParamIsDefault(digits))
		digits=4
	endif
	
	If(ParamIsDefault(num))
		num=inf
	Endif
	
	
	ImageLoad /Q /O /C=-1 /N=w_GenImgLoad PathAndFile0		
	AbortOnValue v_flag==0, 0
	
	Wave w_GenImgLoad
	Count = 1				//1 image loaded
	
	header = s_info
	PointPos = strsearch(S_Filename, ".tif", 0)
	ImgWaveName = S_FileName[0,PointPos-1]
	ImgWaveName = ReplaceString("-", ImgWaveName, "_")		//make wave name Igor compatible
	fName=S_FileName[0,PointPos-1-digits]
	
	
	numStr=S_FileName[PointPos-digits,PointPos-1]
	ii=str2num(numStr)			//get number of 1st file
	
	fPath=s_Path
	
	Note w_GenImgLoad, header
	Note w_GenImgLoad, "file.path="+s_path
	Note w_GenImgLoad, "file.name="+s_filename
	
	Duplicate/o/free w_GenImgLoad LoadedImage

	
	Do
		ii+=1
		Sprintf fnumStr, "%0*d", digits, ii			//generate next number as string with leading 0's
	
		PathAndFile = fPath+fName+fNumStr+".tif"	//assemble next filename
		
		ImageLoad /Z /Q /O /C=-1 /N=w_GenImgLoad PathAndFile		//load file
		If(V_flag==0)								//no image loaded
			Break								//exit loop
		Endif
	
		Concatenate /NP=2 /O {LoadedImage, w_GenImgLoad}, w_concwave	
		Duplicate/o w_concwave, LoadedImage
		count +=1
	While (count < num)
	
	
	Redimension/S LoadedImage		//make wave single precision, which is used in most Igor analyses
	Duplicate/o LoadedImage  $ImgWaveName
	KillWaves w_concwave, w_GenImgLoad
	Return ImgWaveName
End

////

Function LGM()
	String fileFilters
	Variable refNum
	String message = "Select file"
	String outputPaths


	fileFilters = "Tiff:*.tiff, *.tif;All files:.*;"

	Open /D /R /F=fileFilters /M=message refNum
	
	if(StrLen(S_fileName) == 0)
			return -1
	endif
	
		
	outputPaths = S_fileName

	 LoadGenericMovie(outputPaths)

End