#pragma rtGlobals=1		// Use modern global access method.

// RepairNorm() scans all folders for sormalized waves (i.e. ending with _nor) and
// normalizes the respective raw data again using the BLbyHist algorithm.
// This is used to "repair" data analyzed with an older algorithm.



Function RepairNorm()

	string DFD, Folders, Waves, currentFolder, Suffix, wvName, BaseWaveName, root, rootFolder
	variable nFolders, nWaves, fCount, wCount, wnlength
	
	DFREF saveDFR, currentDFR
	
	DoAlert 2, "This procedure will re-normalise all waves ending with \"_nor\". This procedure cannot be undone. Save experiment now?"
	if(v_flag==1)	//yes
		SaveExperiment
		Print "Experiment sucessfully saved."
	elseif(v_flag==3)//cancel
		return -1
	endif
	
	saveDFR=GetDataFolderDFR()
	rootFolder=GetDataFolder(1)

	DFD= DataFolderDir(-1)
	DFD=ReplaceString(",",DFD,";")
	Folders = StringByKey("FOLDERS",DFD,":","\r")
	nFolders = ItemsInList(Folders)

	for(fCount = -1;fCount<nFolders;fCount+=1)
		if(fcount == -1)
			currentfolder=rootFolder
		else
			currentfolder = rootFolder+StringFromList(fCount,Folders)
		endif
		
		currentDFR = $currentFolder
		SetDataFolder currentDFR
		
		DFD= DataFolderDir(-1)
		DFD=ReplaceString(",",DFD,";")
		Waves = StringByKey("WAVES",DFD,":","\r")
		nWaves=ItemsInList(Waves)

		for(wCount=0;wCount<nWaves;wCount+=1)
			wvName=StringFromList(wCount, Waves)
			wnlength=StrLen(wvName)
			suffix=wvName[wnlength-4,wnlength-1]
			root=wvname[0,wnlength-5]
		
			if(stringmatch(suffix,"_nor") && WaveExists($root))
				BlByHist($root,1)		//1=no smoothing; >2 = smoothing
				Print "Renormalised wave <"+root+"> in folder "+currentFolder+"."
			endif
		
		EndFor	

	endFor




SetDataFolder SaveDFR
End


////////////////////////////////////////////////////////////
//BlByHist works like normalizepop, only that (optional) smoothing is implemented. 
//Enter a smth value > 2 for smoothing, 1 for no smoothing.

Function BlByHist(pop,smth,[resultname])
	Wave pop
	variable smth
	string resultname
	
	if(paramisdefault(resultname))
		resultname=nameofwave(pop)+"_NOR"
	endif
	
	variable npts = dimsize(pop,0), ntraces = dimsize(pop,1), ii, bl
	
	if(ntraces < 1)
		ntraces = 1
	endif
	
	Duplicate /o/free pop, trace, NorPop, smthPop
	redimension /n=(-1) trace
	Make/free/o Histo
	duplicate /o/free trace smtrace
	
	smooth /dim=0 smth, smthpop
	
	for(ii=0;ii<ntraces;ii+=1)
		trace = pop[p][ii]
		smtrace=smthpop[p][ii]
		Histogram /b=3 smtrace, Histo
		wavestats /q/m=1 histo
		bl = v_maxloc
		
		NorPop[][ii] = (trace[p] - bl) / bl 
	
	endfor
	
	Duplicate /o NorPop, $resultname
	
	
End


////////////////////////////////////////////////////////////


//Function AutoBLandROISize()
//
//	string DFD, Folders, Waves, currentFolder, Suffix, wvName, BaseWaveName, root, rootFolder, DataName
//	variable nFolders, nWaves, fCount, wCount, wnlength
//	
//	DFREF saveDFR, currentDFR
//	
//	saveDFR=GetDataFolderDFR()
//	rootFolder=GetDataFolder(1)
//
//	DFD= DataFolderDir(-1)
//	DFD=ReplaceString(",",DFD,";")
//	Folders = StringByKey("FOLDERS",DFD,":","\r")
//	nFolders = ItemsInList(Folders)
//
//	for(fCount = -1;fCount<nFolders;fCount+=1)
//		if(fcount == -1)
//			currentfolder=rootFolder
//		else
//			currentfolder = rootFolder+StringFromList(fCount,Folders)
//		endif
//		
//		currentDFR = $currentFolder
//		SetDataFolder currentDFR
//		
//		DFD= DataFolderDir(-1)
//		DFD=ReplaceString(",",DFD,";")
//		Waves = StringByKey("WAVES",DFD,":","\r")
//		nWaves=ItemsInList(Waves)
//
//		for(wCount=0;wCount<nWaves;wCount+=1)
//			wvName=StringFromList(wCount, Waves)
//			DataName=wvName[0,8]
//			wnlength=StrLen(wvName)
//			suffix=wvName[wnlength-4,wnlength-1]
//			root=wvname[0,wnlength-5]
//		
//			if(stringmatch(suffix,"_nor") && WaveExists($DataName))
//				BaseLineFromNor($DataName,$wvName,resultname=wvName+"_BL")
//				Print "Calculated baseline from <"+root+"> in folder "+currentFolder+"."
//				
//			elseif(stringmatch(suffix,"_ROI") && WaveExists($root))
//				ROISize($wvName,resultname=wvName+"_ROISize")
//				Print "Calculated ROI sizes from <"+root+"> in folder "+currentFolder+"."
//			endif
//			
//			
//		
//		EndFor	
//
//	endFor
//
//
//
//
SetDataFolder SaveDFR
End