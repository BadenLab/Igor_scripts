#pragma rtGlobals=1		// Use modern global access method.
#include "normalize"

//Update 11/07/2011: Completely reworked SaveTiff to prevent layer-by-layer normalisation when exporting stacks.

Function SaveTiff(wvin, [depth])
	wave wvin
	variable depth
	
	Variable nDim, xDim, yDim, zDim
	String svName
	
	nDim = wavedims(wvin)
	xDim = DimSize(wvin,0)
	yDim = DimSize(wvin,1)
	zDim = DimSize(wvin,2)
	if (zDim==0)
		zDim = 1
	endif
	svName = nameofwave(wvin)
	
	duplicate/o/free wvin wv, w_stNor
	
	if (nDim == 1)
		DoAlert 0, "<"+nameofwave(wvin)+"> is not an image. Nothing will be saved."
		return -1
	endif
	
	If (paramisdefault(depth))
		depth=16
	elseif ((depth != 1) && (depth != 8) && (depth != 16) && (depth != 32) )
		doalert 1, "Only bit depths of 1, 8, 16 and 32 can be selected. Continue with default value 16?"
			if (v_flag != 1)
				return -1
			else
				depth = 16
			endif
	endif
	
	redimension /n=(xDim*yDim*zDim) wv, w_stNor			//convert to 1D
	
	
	Switch (depth)
		Case 32:
			If(nDim == 2)
				ImageSave /F/T="tiff" wvin as svName
			Else
				ImageSave /F/S/T="tiff" wvin as svName
			Endif
		Break
		
		
		Case 16:
			MatrixOP/o/free w_stnor = Scale(wv,0,65535)
			Redimension /W/U w_stnor
			If(nDim == 2)
				Redimension /e=1/n=(xDim,yDim) w_stnor			
				ImageSave /U/D=16/T="tiff" w_stnor as svName
			Else
				Redimension /e=1/n=(xDim,yDim,zDim) w_stnor
				ImageSave /U/S/D=16/T="tiff" w_stnor as svName
			Endif
		Break
		
		Case 8:
			MatrixOP/o/free w_stnor = Scale(wv,0,255)
			Redimension /B/U w_stnor
			If(nDim == 2)
				Redimension /e=1/n=(xDim,yDim) w_stnor
				ImageSave /D=40/U/T="tiff" w_stnor as svName
			Else
				Redimension /e=1/n=(xDim,yDim,zDim) w_stnor
				ImageSave /U/S/D=40/T="tiff" w_stnor as svName
			Endif
		Break
	
		Case 1:
			MatrixOP/o/free w_stnor = (-equal(wvin,0) +1) * 255
			Redimension /B/U w_stnor
			If(nDim == 2)
				ImageSave /D=40/U/T="tiff" w_stnor as svName
			Else
				ImageSave /S/D=40/U/T="tiff" w_stnor as svName
			Endif
		Break
	
		Default:
			Print "SaveTiff unspecified input"
			return -1
		Break
	EndSwitch

	//Debug only
	//duplicate/o w_stnor w_nor
	//printf "Min %g, Max %g\r",wavemin(w_stnor),wavemax(w_stnor)

	return 0
end



//////////////////////////////////////////////////////

Function SizeImage(Size,[WindowName])
	Variable Size
	string WindowName
	
	String TWName
	Variable xRange, yRange
	
	If(ParamIsDefault(WindowName))
		TWName=WinName(0,1,1)
	Else
		TWName=WindowName
	Endif
	
	DoUpdate
	
	GetAxis /w=$TWName/q left
	if(v_flag)
		GetAxis /w=$TWName/q right
	endif
	
	yRange = abs(v_max-v_min)
	
	GetAxis /w=$TWName/q bottom
	if(v_flag)
		GetAxis /w=$TWName/q top		//picture?
	endif
	xRange = abs(v_max-v_min)
	
	
	If(xRange > yRange)
		 ModifyGraph /w=$TWName width=(Size), Height=(Size*yRange/xRange)
	Else
		ModifyGraph /w=$TWName Height=(Size), Width=(Size/yRange*xRange)
	Endif
	
	DoUpDate
	ModifyGraph/w=$TWName height=0, width=0		//unlock size

End


//////////////////////////////////////////////////////////////////////////////////

//Function SaveTiff_old(wvin, [depth])
//wave wvin
//variable depth
//
//duplicate/o/free wvin wv
//
//
//if (wavedims(wv) == 1)
//	DoAlert 0, "<"+nameofwave(wv)+"> is not an image. Nothing will be saved."
//	return -1
//endif
//
//If (paramisdefault(depth))
//	depth=16
//elseif ((depth != 1) && (depth != 8) && (depth != 16) && (depth != 24) && (depth != 32) && (depth != 40) )
//	doalert 1, "Only bit depths of 1, 8, 16, 32, 24 and 32 can be selected. Continue with default value 16?"
//		if (v_flag != 1)
//			return -1
//		else
//			depth = 16
//		endif
//endif
//
//normalise(wv, 0, 2^depth-1, name="stwv")
//wave stwv
//
//if (depth < 16)
//	redimension /B/U stwv
//elseif (depth < 32)
//	redimension /W/U stwv
//else
//	redimension /I/U stwv
//endif
//
//if (wavedims(wv) == 2)
//	ImageSave /t="TIFF" /D=(depth) stwv as nameofwave(wvin)
//else
//	ImageSave /t="TIFF" /s /D=(depth) stwv as nameofwave(wvin)
//
//endif
//
//
//killwaves /z stwv
//end