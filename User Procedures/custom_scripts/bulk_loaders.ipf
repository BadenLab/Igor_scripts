#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
// Author: Kevin Doran
Function loadScanM(folderName, smpFileName)
	// home is created when experiment is created (see 
	// Experiment Recreation Procedures)
	String folderName
	String smpFileName
	// ScMIO_LoadSMP expects the base filename (w/o  extension)
	// Remove extension. 
	// Option 1: (ugly, but probably idomatic)
	smpFileName = ParseFilePath(3, smpFileName, ":", 0, 0)
	// Option 2: 
	// smpFileName = RemoveEnding(smpFileName, ".smp")
	WAVE wSCIOParams = createSCIOParamsWave()
	ScMIO_LoadSMP(folderName, smpFileName, 1, wSCIOParams)
	KillWaves/Z wSCIOParams
End

Function loadAllScanM(folderName)
	// example: loadAllScanM("E:\\kd408\\2024-11-21")
	String folderName
	String fileName
	// IndexedFile expects a Symbolic Path, not a string. So create one.
	NewPath folderPath, folderName
	Variable index=0
	do
		fileName = IndexedFile(folderPath, index, ".smp")
		if (strlen(fileName) == 0)
			// No more files.
			break
		endif
		index += 1
		loadScanM(folderName, fileName)
	while (1)
	// Symbolic paths need deleting
	KillPath folderPath
End