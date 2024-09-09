#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Export()

	// WARNING- currently not exporting the StimArtifactwave -needs to update at somepoint
	
	Variable fileID
	WAVE/z OS_Parameters,ROIs,Traces0_raw,Traces0_znorm,Averages0,Tracetimes0,Triggertimes,Triggertimes_Frame,Triggervalues,wDataCh0, wDataCh0_detrended,wDataCh1,wDataCh2
	WAVE/z stack_ave, stack_ave_report, GeoC, Snippets0,SnippetsTimes0,wParamsNum//,wParamsStr
	WAVE AverageStack0,  AverageStack0_Chopped, AverageSubStack_0, AverageSubStack_1, AverageSubStack_2, AverageSubStack_3

	NewPath targetPath
	PathInfo targetPath
	variable nROIs = abs(Wavemin(ROIs)), i
	//variable experiment_date = wParamsStr[4]
	string exp_date
	wave /T wParamsStr
	exp_date = wParamsStr[4]
	//duplicate /o/r=[0,0] wDataCh2, wDataCh2_line
	//print($exp_date)
	string pathName = "targetPath"
	string folderName = GetDataFolder(0)[4, StrLen(GetDataFolder(0))]
	HDF5CreateFile/P=$pathName /O fileID as exp_date + "_" + folderName + ".h5"
	WAVE wDataCh0, wDataCh1A
	HDF5SaveData /O /Z wDataCh0, fileID
	HDF5SaveData /O wDataCh0_detrended, fileID
	HDF5SaveData /O /Z wDataCh2, fileID
	HDF5SaveData /O /Z /IGOR=8 wParamsNum, fileID
	HDF5SaveData /O /Z /IGOR=8 wParamsStr, fileID
	if (waveexists($"correlation_projection")==1)
		wave correlation_projection
		HDF5SaveData /O /Z correlation_projection, fileID	
	endif
	if (waveexists(stack_ave))
		HDF5SaveData /O /Z stack_ave, fileID // Mean image across the stack in the data channel 0
	endif
	if (waveexists($"Triggervalues")==1)
		print  "Triggervalues detected, exporting preprocessed data."
		HDF5SaveData /O /Z /IGOR=8 OS_parameters, fileID
		HDF5SaveData /O /Z ROIs, fileID
		HDF5SaveData /O /Z Traces0_raw, fileID
		HDF5SaveData /O /Z Traces0_znorm, fileID
		HDF5SaveData /O /Z Averages0, fileID
		HDF5SaveData /O /Z Triggertimes, fileID
		HDF5SaveData /O /Z Triggertimes_Frame, fileID
		HDF5SaveData /O /Z Triggervalues, fileID	
		if (waveexists(GeoC))
			HDF5SaveData /O /Z GeoC, fileID // Cell positions in the field
		endif
		if (waveexists($"SnippetsTimes"+num2str(OS_Parameters[%Data_channel])))
			HDF5SaveData /O /Z Snippets0, fileID
			HDF5SaveData /O /Z SnippetsTimes0, fileID
		endif
	endif
	if (waveexists($"AverageStack0")==1)
		variable avg_stacks_found = 1
		print("Found AverageStacks, putting 'em into HDF5")
		HDF5SaveData /O /Z AverageStack0, fileID
		HDF5SaveData /O AverageStack0_Chopped, fileID
		HDF5SaveData /O /Z AverageSubStack_0, fileID
		HDF5SaveData /O /Z AverageSubStack_1, fileID
		HDF5SaveData /O /Z AverageSubStack_2, fileID
		HDF5SaveData /O /Z AverageSubStack_3, fileID
	endif
	// Check if 'STRF' waves exist
	string check_strf = wavelist("STRF*", ";", "")
	if (strlen(check_strf) > 1)
		variable strfs_found = 1
		print("Found STRFs, chucking those into HDF5")
		// Get list of STRFs present 
		string raw_strfs = wavelist("STRF0*", ";", "")
			//save them to HDF5 file.... 
			for (i=0; i< itemsinlist(raw_strfs) ; i+=1) // Using WaveList to get all STRF waves
				string curr_STRF = stringfromlist(i, raw_strfs)
				HDF5SaveData /O $curr_STRF, fileID
			endfor
			// Also grab the other related files
			WAVE /z STRF_Corr0, nislands_per_ROI, islandsX, islandsY,  islandTimeKernels, islandTimeKernels_Polarities, islandTimeKernels_Pol_rel, islandAmpls, islandAmpls, island_sum
			HDF5SaveData /O /Z STRF_Corr0, fileID
			HDF5SaveData /O /Z nislands_per_ROI, fileID
			HDF5SaveData /O /Z islandsX, fileID
			HDF5SaveData /O /Z islandsY, fileID
			HDF5SaveData /O /Z islandTimeKernels, fileID
			HDF5SaveData /O /Z islandTimeKernels_Polarities, fileID
			HDF5SaveData /O /Z islandTimeKernels_Pol_rel, fileID
			HDF5SaveData /O /Z islandAmpls, fileID
			HDF5SaveData /O /Z island_sum, fileID
			WAVE STRF_Corr_Montage_RGB, STRF_Corr_Montage_RGB2
			HDF5SaveData /O /Z STRF_Corr_Montage_RGB, fileID
			HDF5SaveData /O /Z STRF_Corr_Montage_RGB2, fileID
	else
		strfs_found = 0
	endif
	if (waveexists($"Positions")==1)
		print("Found IPL positions, adding those to HDF5")
		variable pos_found = 1
		WAVE Positions 
		HDF5SaveData /O /Z Positions, fileID
	else
		pos_found = 0
	endif
	if ((strfs_found == 1 || avg_stacks_found == 1) && pos_found == 0)
		print("WARNING: IPL Positions missing!") 
	endif
	print("Saved as: " + S_path + folderName)	
	HDF5CloseFile fileID
end