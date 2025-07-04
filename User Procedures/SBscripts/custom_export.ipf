#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Export_custom()

	// WARNING- currently not exporting the StimArtifactwave -needs to update at somepoint
	
	Variable fileID
	WAVE/z OS_Parameters,ROIs,Traces0_raw,Traces0_znorm,Tracetimes0,Triggertimes,Triggervalues,wDataCh0,wDataCh1,wDataCh2
	WAVE/z stack_ave, stack_ave_report, GeoC, Snippets0,SnippetsTimes0,wParamsNum,wParamsStr
	NewPath targetPath
	variable nROIs = abs(Wavemin(ROIs)), i
	
	string pathName = "targetPath"
	HDF5CreateFile/P=$pathName /O /Z fileID as GetDataFolder(0)+".h5"
	WAVE wDataCh0, wDataCh1
	HDF5SaveData /O /Z wDataCh0, fileID
	HDF5SaveData /O /Z wDataCh1, fileID
	//HDF5SaveData /O /Z wDataCh2, fileID
	HDF5SaveData /O /Z /IGOR=8 wParamsNum, fileID
	HDF5SaveData /O /Z /IGOR=8 wParamsStr, fileID
	if (waveexists(stack_ave))
		HDF5SaveData /O /Z stack_ave, fileID // Mean image across the stack in the data channel 0
	endif
	if (waveexists($"Triggervalues")==1)
		print  "Triggervalues detected, exporting preprocessed data."
		HDF5SaveData /O /Z /IGOR=8 OS_parameters, fileID
		HDF5SaveData /O /Z ROIs, fileID
		HDF5SaveData /O /Z Traces0_raw, fileID
		HDF5SaveData /O /Z Tracetimes0, fileID
		HDF5SaveData /O /Z Triggertimes, fileID
		HDF5SaveData /O /Z Triggervalues, fileID	
		if (waveexists(GeoC))
			HDF5SaveData /O /Z GeoC, fileID // Cell positions in the field
		endif
		if (waveexists($"SnippetsTimes"+num2str(OS_Parameters[%Data_channel])))
			HDF5SaveData /O /Z Snippets0, fileID
			HDF5SaveData /O /Z SnippetsTimes0, fileID
		endif
	endif
	// If wave(s) called STRF0_n exist...
	if (waveexists($"STRF0_0")==1)
		//save them to HDF5 file.... 
		for (i=0; i< nROIs ; i+=1) // Consider using WaveList
			string curr_STRF = "STRF0_"+Num2Str(i)
			HDF5SaveData /O $curr_STRF, fileID
		endfor
		// Also grab the other related files
		WAVE /z STRF_Corr0, nislands_per_ROI, islandsX, islandsY,  islandTimeKernels, islandTimeKernels_Polarities, islandTimeKernels_Pol_rel, islandAmpls
		HDF5SaveData /O /Z STRF_Corr0, fileID
		HDF5SaveData /O /Z nislands_per_ROI, fileID
		HDF5SaveData /O /Z islandsX, fileID
		HDF5SaveData /O /Z islandsY, fileID
		HDF5SaveData /O /Z islandTimeKernels, fileID
		HDF5SaveData /O /Z islandTimeKernels_Polarities, fileID
		HDF5SaveData /O /Z islandTimeKernels_Pol_rel, fileID
		HDF5SaveData /O /Z islandAmpls, fileID
	endif
	
	HDF5CloseFile fileID
end