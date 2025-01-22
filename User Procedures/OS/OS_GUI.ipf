#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "OS_ParameterTable"
#include "OS_DetrendStack"
#include "OS_ManualROI"
#include "OS_AutoRoiByCorr"
#include "OS_TracesAndTriggers"
#include "OS_BasicAveraging"
#include "OS_hdf5Export"
#include "OS_LaunchCellLab"
#include "OS_STRFs"
#include "OS_EventFinder"
#include "OS_hdf5Import"
#include "OS_LineScanFormat"
#include "OS_LED_Noise"
#include "OS_Clustering"
#include "OS_Bars"
#include "OS_Register"  // Takeshi's
#include "OS_AutoROIs_SD" // Takeshi's
#include "OS_LoadTiff" // Tiff Loader - currently not included as button

#include "OS_AveragingSuite" //
#include "OS_ROI3D"
#include "OS_ROIPicker"



//----------------------------------------------------------------------------------------------------------------------
Menu "ScanM", dynamic
	"-"
	" Open OS GUI",	/Q, 	OS_GUI()
	"-"	
End
//----------------------------------------------------------------------------------------------------------------------


function OS_GUI()
	NewPanel /N=ImageProc /k=1 /W=(200,100,450,780)
	ShowTools/A
	SetDrawLayer UserBack

	variable BHeight = 25
	variable BWidth1 = 175
	variable BWidth2 = 85
	variable BWidth3 = 55
	variable BWidth4 = 40
	variable BGapY = 5
	variable BGapX = 5
	
	variable TopOffset = 40
	variable BlockOffset = 30
	
	variable TextX = 20
	variable BX = 40

	variable Block1Y = TopOffset
	variable Block2Y = Block1Y+BlockOffset+BHeight*1+BGapY*1
	variable Block3Y = Block2Y+BlockOffset+BHeight*1+BGapY*1
	variable Block4Y = Block3Y+BlockOffset+BHeight*1+BGapY*1
	variable Block5Y = Block4Y+BlockOffset+BHeight*1+BGapY*1
	variable Block6Y = Block5Y+BlockOffset+BHeight*4+BGapY*5
	variable Block7Y = Block6Y+BlockOffset+BHeight*1+BGapY*1
	variable Block8Y = Block7Y+BlockOffset+BHeight*3+BGapY*4

	

	SetDrawEnv fstyle= 1
	DrawText textX,Block1Y,"Step 1: Load Data"
	SetDrawEnv fstyle= 1
	DrawText textX,Block2Y,"(Step 2: Optional)"
	SetDrawEnv fstyle= 1
	DrawText textX,Block3Y,"Step 3: Parameter Table"
	SetDrawEnv fstyle= 1
	DrawText textX,Block4Y,"Step 4: Pre-formatting"
	SetDrawEnv fstyle= 1
	DrawText textX,Block5Y,"Step 5: ROI placement"
	SetDrawEnv fstyle= 1
	DrawText textX,Block6Y,"Step 6: Extract Traces and Triggers"
	SetDrawEnv fstyle= 1
	DrawText textX,Block7Y,"Step 7: Further optional processes"
	SetDrawEnv fstyle= 1	
	DrawText textX,Block8Y,"Step 8: Database Export/Import (hdf5)"
	
	Button LoadScanM,pos={BX,Block1Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="ScanM" 
	Button LoadTiff,pos={BX+BWidth2+BGapX,Block1Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Tiff" 
	
	Button LineScan,pos={BX,Block2Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Linescan"
	Button Register,pos={BX+BWidth2+BGapX,Block2Y+BGapY},size={BWidth4,BHeight},proc=OS_GUI_Buttonpress,title="Reg."
	Button RegisterDo,pos={BX+BWidth2+BWidth4+BGapX*2,Block2Y+BGapY},size={BWidth4,BHeight},proc=OS_GUI_Buttonpress,title="Do"	
	
	Button MakeTable,pos={BX,Block3Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Make / Show"
	Button KillTable,pos={BX+BWidth2+BGapX,Block3Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Kill"	
	
	Button DetrendStandard,pos={BX,Block4Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Standard"
	Button DetrendMinimal,pos={BX+BWidth2+BGapX,Block4Y+BGapY},size={BWidth4,BHeight},proc=OS_GUI_Buttonpress,title="Skip"
	Button DetrendSave,pos={BX+BWidth2+BWidth4+BGapX*2,Block4Y+BGapY},size={BWidth4,BHeight},proc=OS_GUI_Buttonpress,title="Save"
	
	Button ROIManual,pos={BX,Block5Y+BGapY},size={BWidth3,BHeight},proc=OS_GUI_Buttonpress,title="Manual"
	Button ROIManualApply,pos={BX+BWidth3+BGapX,Block5Y+BGapY},size={BWidth3,BHeight},proc=OS_GUI_Buttonpress,title="Apply"
	Button ROIPixelate,pos={BX+BWidth3*2+BGapX*2,Block5Y+BGapY},size={BWidth3,BHeight},proc=OS_GUI_Buttonpress,title="Pixels"
	
	Button ROIPicker1,pos={BX,Block5Y+2*BGapY+BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Picker3D" 
	Button ROIPicker2,pos={BX+BWidth2+BGapX,Block5Y+2*BGapY+BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="SnailROIs" 
	
	Button ROICorr,pos={BX,Block5Y+3*BGapY+2*BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Auto Corr"
	Button ROISD,pos={BX+BWidth2+BGapX,Block5Y+3*BGapY+2*BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Auto SD"
	
	Button ROISARFIA,pos={BX,Block5Y+4*BGapY+3*BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="SARFIA"	
	Button ROICellLab,pos={BX+BWidth2+BGapX,Block5Y+4*BGapY+3*BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Auto CellLab"
	
	Button TracesAndTriggers,pos={BX,Block6Y+BGapY},size={BWidth1,BHeight},proc=OS_GUI_Buttonpress,title="Traces and Triggers"
	
	Button Average,pos={BX,Block7Y+BGapY},size={BWidth1,BHeight},proc=OS_GUI_Buttonpress,title="Average"
	
		
	Button Events,pos={BX,Block7Y+2*BGapY+BHeight},size={BWidth3,BHeight},proc=OS_GUI_Buttonpress,title="Events"			
	Button Cluster,pos={BX+BWidth3+BGapX,Block7Y+2*BGapY+BHeight},size={BWidth3,BHeight},proc=OS_GUI_Buttonpress,title=" Cluster "			
	Button Bars,pos={BX+BWidth3*2+BGapX*2,Block7Y+2*BGapY+BHeight},size={BWidth3,BHeight},proc=OS_GUI_Buttonpress,title=" Bars "			
	
	Button Kernels,pos={BX,Block7Y+3*BGapY+2*BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Kernels"	
	Button STRFs,pos={BX+BWidth2+BGapX,Block7Y+3*BGapY+2*BHeight},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title=" STRFs "
	
	Button HDF5Export,pos={BX,Block8Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Export"
	Button HDF5Import,pos={BX+BWidth2+BGapX,Block8Y+BGapY},size={BWidth2,BHeight},proc=OS_GUI_Buttonpress,title="Import"	
	
	HideTools/A
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function OS_GUI_Buttonpress(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (ba.ctrlName)
			
				case "LoadScanM":
					if(exists("LoadSMPFileWithDialog")==6)
					 	LoadSMPFileWithDialog()
					 else
					 	print "ScanM Loader not found"
					 endif
					
					break
				case "LoadTiff":
					OS_LoadTiff()
					break
			   ////////////////////
				case "LineScan":
					OS_LineScanFormat()
					break
				case "Register":
					OS_registration_rigiddrift()
					break
				case "RegisterDo":
					OS_registration_recover()
					break
				///////////////////////
				case "MakeTable":
					OS_ParameterTable()
					break
				case "KillTable":
					OS_ParameterTable_Kill()
					break					
				///////////////////////
				case "DetrendStandard":
					OS_DetrendStack()
					break
				case "DetrendMinial":
					OS_PreFormat_minimal()
					break		
				case "DetrendSave":
					OS_SaveRawAsTiff()
					break									
				///////////////////////
				case "ROIManual":
					OS_CallManualROI()
					break
				case "ROIManualApply":
					OS_ApplyManualRoi()
					break	
				case "ROIPixelate":
					OS_monoPixelApply()
					break						
				
				
				case "ROIPicker1":
					OS_ROI3D()
					break
				case "ROIPicker2":
					OS_ROIPicker()
					break
				
				
				case "ROISARFIA":
					OS_CloneSarfiaRoi()
					break																		
				case "ROICorr":
					OS_AutoRoiByCorr()
					break
				case "ROISD":
					OS_autoROIs_SD()
					break
				case "ROICellLab":
					OS_LaunchCellLab()
					break
				///////////////////////
				case "TracesAndTriggers":
					OS_TracesAndTriggers()
					break					
				///////////////////////
				case "Average":
					OS_BasicAveraging()
					break
				case "Events":
					OS_EventFinder()
					break					
				case "Kernels":
					OS_LED_Noise()
					break
				case "Cluster":
					OS_Clustering()
					break

				case "Bars":
					OS_Bars()
					break		
				case "STRF":
					OS_STRFs_new()
					break																					
				/////////////
				case "HDF5Export":
					OS_hdf5Export()
					break										
				case "HDF5Import":
					OS_hdf5Import("")
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
