#pragma rtGlobals=1		// Use modern global access method.
#include "LoadScanImage"
#include "RegisterStack"

//Use AutoRegistration() to call RegisterStack on multiple files in a folder. 
//This is useful for registering a large number of image stacks overnight or 
//while away from the computer. Call AutoRegistration() and specify one or 
//many .tiff files. These will be sequentially loaded, registered and saved as 
//Igor binary files in the origin folder.


Function AutoRegistration()
	String AllFiles
	String PathAndFile, pathStr, fileStr, saveStr
	
	AllFiles = DoOpenMultiFileDialog()			//Get files to be loaded
	
	If(strlen(allFiles)==0)
		Print "AutoRegistration Cancelled"
		return -1
	EndIf

	Variable numFilesSelected = ItemsInList(AllFiles, "\r")		//number of files loaded
	Variable ii, pointpos, len
	
	Printf "\r%d files selected.\rStarting...\r", numFilesSelected
	
	for(ii=0; ii<numFilesSelected; ii+=1)
		pathandfile = StringFromList(ii, AllFiles, "\r")
		Printf "(%d) Loading %s\r", ii, pathandfile	
		
		len=strlen(pathandfile)
		PointPos = strsearch(pathandfile, ":", len, 1)
		PathStr =  pathandfile[0,PointPos-1]
		fileStr = pathandfile[Pointpos+1,len-1]
		
		Wave image = AutoLoadScanImage(pathstr, filestr)
		ApplyHeaderInfo(image)							//scale
		
//		Printf "(%d) Registering %s\r", ii, pathandfile	
		Reg2(image)										//image registration
		
		NewPath/o/q SavePath, pathstr
		SaveStr = NameOfWave(image)+"_reg.ibw"
		
		Save /o/p=SavePath image as saveStr					//save file
		KillWaves image									//...and clean up
		
		Print "File saved as "+pathstr+":"+saveStr
	endfor

	Print "\rJob done. May I go to sleep now?"
	Print "..."
	Print "Hello? You didn't leave me alone, did you?"
	Print "..."
	Print "*sob*"
End


//////////////////////////////

Static Function/S DoOpenMultiFileDialog()
	Variable refNum
	String message = "Select one or more files"
	String outputPaths
	String fileFilters = "Tiff Images :.tif,.tiff;"
	fileFilters += "All Files:.*;"

	Open /D /R /MULT=1 /F=fileFilters /M=message refNum
	outputPaths = S_fileName
	
//	if (strlen(outputPaths) == 0)
//		Print "Cancelled"
//	else
//		Variable numFilesSelected = ItemsInList(outputPaths, "\r")
//		Variable i
//		for(i=0; i<numFilesSelected; i+=1)
//			String path = StringFromList(i, outputPaths, "\r")
//			Printf "%d: %s\r", i, path	
//		endfor
//	endif
	
	return outputPaths		// Will be empty if user canceled
End

//////////////////////////////

