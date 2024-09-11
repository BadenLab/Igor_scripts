#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
// #include "Sarfia"


Function KernelBrowser([Kernels_3D])

	String Kernels_3D
	String/G Kernels_disp
	Variable/G Roinumber=0
	Variable SDrange=40
	
	if(!paramIsDefault(Kernels_3D))
	
		Kernels_disp = Kernels_3D
		
	else 
	
		Kernels_disp = "Kernels0"
		
	endif
	
	Display /k=1 $Kernels_disp[][0][roinumber],$Kernels_disp[][1][roinumber],$Kernels_disp[][2][roinumber],$Kernels_disp[][3][roinumber]
	ModifyGraph rgb($Kernels_disp#1)=(0,52224,0),rgb($Kernels_disp#2)=(0,0,65280);DelayUpdate
	ModifyGraph rgb($Kernels_disp#3)=(65280,0,52224)
	ModifyGraph fSize=8,axisEnab(left)={0.05,1},axisEnab(bottom)={0.05,1};DelayUpdate
	Label left "\\Z10SD";DelayUpdate
	Label bottom "\\Z10Time (\\U)"
	ModifyGraph zero(bottom)=2
	SetAxis left -SDrange,SDrange
	ModifyGraph lsize=1.5

	ControlBar 30
	SetVariable ROInumSet size={120,20},value=Roinumber,proc=SetVarProc_2,title="ROI Number"


End






Function SetVarProc_2(sva) : SetVariableControl // for function KernelBrowser
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			
			SVAR w = Kernels_disp
			NVAR wn = ROInumber
			ReplaceWave trace=$w#0, $w[][0][wn]
			ReplaceWave trace=$w#1, $w[][1][wn]
			ReplaceWave trace=$w#2, $w[][2][wn]
			ReplaceWave trace=$w#3, $w[][3][wn]
			
			DoUpdate
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVarProc_3(sva) : SetVariableControl // for function KernelBrowser
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			
			NVAR wn1 = Pre
			wave Chirps_Before
			wave Steps_Before
			wave Kernels_Before 
			ReplaceWave trace=Steps_Before, Steps_Before[][wn1]
			ReplaceWave trace=Chirps_Before, Chirps_Before[][wn1]
			ReplaceWave trace=Kernels_Before, Kernels_Before[][0][wn1]
			ReplaceWave trace=Kernels_Before#1, Kernels_Before[][1][wn1]
			ReplaceWave trace=Kernels_Before#2, Kernels_Before[][2][wn1]
			ReplaceWave trace=Kernels_Before#3, Kernels_Before[][3][wn1]
			
			DoUpdate
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVarProc_4(sva) : SetVariableControl // for function KernelBrowser
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			
			NVAR wn2 = Post
			wave Chirps_Drug
			wave Steps_Drug
			wave Kernels_Drug 
			ReplaceWave trace=Steps_Drug, Steps_Drug[][wn2]
			ReplaceWave trace=Chirps_Drug, Chirps_Drug[][wn2]
			ReplaceWave trace=Kernels_Drug, Kernels_Drug[][0][wn2]
			ReplaceWave trace=Kernels_Drug#1, Kernels_Drug[][1][wn2]
			ReplaceWave trace=Kernels_Drug#2, Kernels_Drug[][2][wn2]
			ReplaceWave trace=Kernels_Drug#3, Kernels_Drug[][3][wn2]
			
			DoUpdate
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function h5_export ([f])
// export need waves for further calculation in hdf5 format

variable f
variable fileID
NewPath/O tarpath
string pathName = "tarpath"
SetDataFolder root:
string Data_name = IgorInfo(1)
HDF5CreateFile/P=$pathName /O fileID as Data_name+".h5"

Variable Group1_ID
Variable Group2_ID
Variable Group3_ID
Variable Group4_ID
Variable Group5_ID
Variable Group6_ID
Variable Group7_ID
Variable Group8_ID

variable nFolder = countObjects(":",4) // count the number of folders
variable rr
String DF_Root

if (f==1) // for setup 1 eaat data 
	
	
	for (rr=1;rr<nFolder;rr+=1)
		DF_Root = GetIndexedObjNameDFR(GetDataFolderDFR(),4,rr)
		SetDataFolder root:$(DF_Root)
		if (stringmatch(DF_Root,"SMP*"))
		
			HDF5CreateGroup fileID, DF_Root, Group1_ID  // save data for _001 folder, default steps2
			
			HDF5SaveData /O  root:$(DF_Root):Stack_Ave, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):ROIs, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Traces0_raw, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Traces0_znorm, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Tracetimes0, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Triggertimes, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Averages0, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):QualityCriterion, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Positions, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Snippets0, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):SnippetsTimes0, Group1_ID
			
			HDF5CloseGroup Group1_ID
		endif
		SetDataFolder root:
	endfor
		
elseif (f==2) // for DT brain data
//	variable nFolder = countObjects(":",4) // count the number of folders
//	variable rr
//	String DF_Root
	for (rr=1;rr<nFolder;rr+=1)
		DF_Root = GetIndexedObjNameDFR(GetDataFolderDFR(),4,rr)
		SetDataFolder root:$(DF_Root)
		if (stringmatch(DF_Root,"SMP*"))
		
			HDF5CreateGroup fileID, DF_Root, Group1_ID  // save data for _001 folder, default steps2
			
			HDF5SaveData /O  root:$(DF_Root):Stack_Ave, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):ROIs, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Traces0_raw, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Traces0_znorm, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Tracetimes0, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Triggertimes, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):Averages0, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):QualityCriterion, Group1_ID
			
			HDF5SaveData /O  root:$(DF_Root):Snippets0, Group1_ID
			HDF5SaveData /O  root:$(DF_Root):SnippetsTimes0, Group1_ID
			
			HDF5CloseGroup Group1_ID
		endif
		SetDataFolder root:
	endfor
endif

HDF5CloseFile fileID
end