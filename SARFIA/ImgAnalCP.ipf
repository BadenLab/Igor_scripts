#pragma rtGlobals=1		// Use modern global access method.
#pragma version = 1.2
#include "z-project"
#include "normalize"
#include "multiroi"
#include "ManThresh"
#include "QuickAnal"
#include "Customcolor"
#include "populationwave"
#include "GammaCorrCP"
#include "LoadScanImage"
#include "RegisterStack"
#include "dif_image"
#include "SaveTiff"
#include "NaNBust"
#include "OneClickSmooth"
#include "ROISize"
#include "difference"
#include "PopWaveBrowser3"
#include "ImgAnalCP"
#include <Image ROI>
#include <ImageSlider>
#include <Image Contrast>


constant row1= 15, row2 = 90, row3 = 240, row4 = 440 

/////////////////////////////////Control Panel////////////////////////////////////////////

Function ImgAnalCP() //creates the panel
variable screenright


	
	GetWindow kwFrameInner wsize
	
	screenright = V_Right

	

variable left=screenright - 350, top = 0

DFREF saveDFR = GetDataFolderDFR()		//save current data folder


If (WinType("IAControlPanel"))
	doWindow /F IAControlPanel
else

		
	
	If(DataFolderRefStatus(root:Packages)!=1)
		NewDataFolder root:Packages
		NewDataFolder root:Packages:IACP
		SetDataFolder root:Packages:IACP
	ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:IACP)!=1)
		NewDataFolder root:Packages:IACP
	ElseIf( DataFolderRefStatus(root:Packages:IACP)==1)
		//
	Else
		DoAlert 0, "IACP_Initialise failed due to conflict with a free data folder."
		return -1
	EndIf

	SetDataFolder root:Packages:IACP

	String /g g_NameOf3DWave = "none", g_NameOf1DWave = "none",  g_NameOf2DWave = "none", g_QAStatus = "Not running", g_QAMethodType = "Average", g_NameOfROIWave = "Automatic", g_MTMethod
	Variable /g g_MultiroiCheckBox = 0, g_ThresholdLevelNumber = 3, g_AutoName = 1, g_AutoDisplay = 1, g_axes = 1
	Variable /g g_AutoLayout = 1, g_deltaFbyF = 1, g_HeaderInfo = 0, g_Registration = 0 , g_PathSpec = 0, g_DeltaFByF0 = 0, g_BGSubtract=1
	variable bottom = top + 505
	//Make Panel
	//NewPanel /K=2 /N=IAControlPanel /W=(left,top,left + 330,bottom) as "Image Analysis"
	NewPanel /K=2 /N=IAControlPanel /W=(left,top,left + 330,bottom) /fg=(*,FR,*,*) as "Image Analysis"
	SetDrawEnv fillpat= 0
	groupbox MainButtons pos={5,5}, size={335,70}//, title = "Main Controls"
	groupbox WaveControls pos={5, 80}, size={335,120}
	groupbox QAControls pos={5, 210}, size={335, 260}//, title = "Quick Analysis"
	
	//Drawrect /W=IACOntrolPanel 5,5,325,250		//left, top, right, bottom
	//SetDrawEnv fillpat= 0
	//Drawrect /W=IACOntrolPanel 5,255,325,450
	Drawtext /W=IACOntrolPanel 20,row3 + 30, "Selected Stack: "//+g_NameOf3DWave
	//Drawtext /W=IACOntrolPanel 15,bottom - top - 8, "Image Analysis Control Panel v1.2"
	Titlebox Quicktitle, pos = {130, row3 - 20}, frame =2,  Win=IACOntrolPanel, fsize = 12, fstyle = 1, title = "Quick Analysis"
	TitleBox Display3dWave pos = {117, row3 + 15}, frame =0,  Win=IACOntrolPanel, fsize = 12, fstyle = 10, variable= g_NameOf3DWave
	TitleBox QAStatusBox pos = {20, row4 - 35}, size={180, 40}, frame = 1,  Win=IACOntrolPanel, fsize = 12, fstyle = 0, title = "Current Status", variable= g_QAStatus
	Button QuitButton, fcolor=(100,10,00), pos = {250,bottom - top - 30}, size = {60,20}, proc=Buttonpress, title="Quit"
	Button Load, pos = {20, row1}, size = {80,20}, proc=Buttonpress, title="Load Image"
	Button ROI, pos = {120,row1}, size = {80,20}, proc=Buttonpress, title="ROI Panel"
//	Button Display2D, pos = {20, row2 + 80},size={60,20}, proc=ButtonPress, title="Display", disable = 2
	Button Contrast, pos = {20, row1+35}, size = {80,20}, proc=ButtonPress, title="Contrast"
	Button QuickAnalyze, pos = {20, row4}, size = {100,20}, proc=ButtonPress, title="Start", disable = 2
	Button ManThresh, win = IAControlPanel, pos={225, row3 + 130}, size = {90,20}, proc=ButtonPress, title="Thresholding", disable = 2
	Button GammaAdjust, win = IAControlPanel, pos = {120, row1+35}, size = {80,20}, proc=ButtonPress, title="Gamma"
	Button SaveExp, fcolor=(10,100,00), pos = {20,bottom - top - 30}, size = {120,20}, proc=Buttonpress, title="Save Experiment"
	Popupmenu Action3D, pos={20,row2},mode=0,proc = PopProc, title="Action", value="Average;Max;Min;SD;Range;Subtract BG;Normalize BG;Register;Z-Stack;Display;Filter;Response Image;Threshold;Invert;Rotate;View Properties;Rename;Save;Kill", disable = 2
	Popupmenu Action1D, pos={20,row2 + 40},mode=0,proc = PopProc, title="Action", value="Display;Normalize;Rectify (pos.);Rename;Kill", disable = 2
	PopUpMenu Action2D, pos = {20, row2 + 80},proc = PopProc,mode=0,title="Action"  , value="Display;PopWaveBrowse;Filter;PopX2Traces;Threshold;Invert;Rotate;Rename;Save;Kill",disable=2
	Popupmenu Waves_list3D, pos={260,row2},bodywidth=180,mode=1,proc = PopProc, title="Stack",popvalue="Select 3D Wave", value=WaveList("*",";","TEXT:0,DIMS:3")
	Popupmenu Waves_list1D,  pos={260,row2 + 40},bodywidth=180,proc = PopProc,mode=1, title="Graph",popvalue="Select Graph Wave", value=WaveList("*",";","TEXT:0,DIMS:1")
	Popupmenu Waves_list2D,  pos={260,row2 + 80},bodywidth=180,proc = PopProc,mode=1, title="Image",popvalue="Select Image Wave", value=WaveList("*",";","TEXT:0,DIMS:2")
	Popupmenu ROIWave,  pos={165,row3 + 130},bodywidth=150,proc = PopProc,mode=1, title="ROI Wave",popvalue="Automatic", value="Automatic;"+WaveList("*ROI*",";","TEXT:0,DIMS:2")
	Popupmenu QAMethod, pos={20, row3 + 50},proc = PopProc,mode=1,  title="Thresholding Method", popvalue="Average", value="Average;SD;Max;Raw Image;Response"
	
	CheckBox MultipleROIs, pos={215, row1-3}, size={20,20}, proc=CBControl, title = "Multiple ROIs?"
	CheckBox AutoLayout, pos={205, row3+72}, size={20,20}, proc=CBControl, title = "Generate Layout?", value = g_AutoLayOut
	CheckBox DeltaFByF,  pos={205, row3+52}, size={20,20}, proc=CBControl, title = "Delta F/F?", value = g_deltaFbyF
	CheckBox Strange, pos={215, row1+17}, size={20,20}, proc=CBControl, title = "Automatic Naming?", value = g_AUtoName
	CheckBox Autodisplay, pos={215, row1+37}, size={20,20}, proc=CBControl, title = "Display Results?", value = g_AutoDisplay
	CheckBox BGSubtr, pos={205, row3+92}, size={20,20}, proc=CBControl, title = "Subtract Background?", value = g_BGSubtract
	CheckBox EqAx, pos = {205,row3+32}, size = {20,20}, proc=CBControl, title = "Equalize axes?", value = g_Axes, value = 1

	Setvariable ThresholdLevel, win = IAControlPanel, pos={20, row3 + 97} , size = {160,20}, noproc, limits={1,2^16,1},noedit=0, value = g_ThresholdLevelNumber, title="Threshold levels"
	//Setvariable DiscardLevel, win = IAControlPanel, pos={20, row3 + 105} , size = {120,20}, noproc, limits={1,g_ThresholdLevelNumber - 1,1},noedit=0, value = g_DiscardLevelNumber, title="Discard levels"
endif

SetDataFolder SaveDFR

end

////////////////////////////////Button Control////////////////////////////////////////////////////

Function Buttonpress(ctlname) : ButtonControl
string ctlname

DFREF WF = root:Packages:IACP

SVAR g_NameOf2DWave = WF:g_NameOf2DWave,  g_NameOf3DWave = WF:g_NameOf3DWave
NVAR g_AutoDisplay = WF:g_AutoDisplay, g_PathSpec=WF:g_PathSpec
string SaveName, NewName

DFREF saveDFR = GetDataFolderDFR()		//save current data folder

strswitch(ctlname)
case "QuitButton":
	if(DataFolderRefStatus(WF))
		SetDataFolder WF
		KillStrings /z   g_NameOf3DWave,g_NameOf1DWave,g_NameOf2DWave,g_QAStatus,g_QAMethodType,g_NameOfROIWave
		Killvariables /z   g_MultiroiCheckBox,g_ThresholdLevelNumber,g_AutoName,g_AutoDisplay,g_axes,g_AutoLayout,g_deltaFbyF,g_HeaderInfo,g_Registration,g_PathSpec
		//Killwaves
		killwindow IAControlPanel
		KillDataFolder root:Packages:IACP
		Variable ObjectCount=CountObjects("root:packages",1)+CountObjects("root:packages",2)+CountObjects("root:packages",3)+CountObjects("root:packages",4)
			if(ObjectCount==0)
				KillDataFolder root:packages
			endif	
		SetDataFolder saveDFR
	endif
		
break

case "SaveExp":
	if(g_pathspec==0)
		NewPath /o/q/M="Specify save location:" SP
		if(V_flag == 0)
			g_pathspec = 1
		else
			Return -1
		endif
	endif


	strswitch(g_NameOf3DWave)
		case "none":
			DoAlert 0, "Select a stack first, or use the File menu."
		break
		default:
			SaveName = g_NameOf3DWave+".pxp"
			SaveExperiment /P=sp as SaveName
		break
		endswitch
break

case "Display2D":
	strswitch(g_NameOf2DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				Display /k=1; Appendimage $g_NameOf2DWave
				DoUpdate
				SizeImage(300, WindowName=s_name)
			endswitch //g_NameOf1DWave
break

case "Load":
	string LSIname = LoadScanImage(), Ch1Name,Ch2Name,Ch3Name
	Variable nChannels, ii
	if (stringmatch(LSIname, "-1"))
		break
	else 
		ApplyHeaderInfo($LSIname)
		nChannels=nChannelsFromHeader($LSIname)
		if(nChannels > 1)
		
			SplitChannels($LSIname,nChannels)
			Ch1Name=LSIName+"_Ch1"
			Ch2Name=LSIName+"_Ch2"
			Ch3Name=LSIName+"_Ch3"	
		
		endif
		
		
		
		
	endif
	
	if (g_AutoDisplay)
	
		if((nChannels==1) || (numType(nChannels) == 2))		//one channel or no info
	
			display /k=1; Appendimage $LSIname; 
			DoUpdate
			
			if (dimsize($LSIname, 2) > 1)
				WMAppend3DImageSlider();
			elseif (dimsize($LSIname, 2) < 2)
				redimension /n=(-1,-1,0,0) $LSIname
			endif
			SizeImage(300, WindowName=s_name)
		elseif(nChannels==2)	
			display /k=1; Appendimage $Ch1Name; 
			DoUpdate
			
			if (dimsize($Ch1Name, 2) > 1)
				WMAppend3DImageSlider();
			elseif (dimsize($Ch1Name, 2) < 2)
				redimension /n=(-1,-1,0,0) $Ch1Name
			endif
			SizeImage(300, WindowName=s_name)
			
			display /k=1; Appendimage $Ch2Name; 
			DoUpdate
			
			if (dimsize($Ch2Name, 2) > 1)
				WMAppend3DImageSlider();
			elseif (dimsize($Ch2Name, 2) < 2)
				redimension /n=(-1,-1,0,0) $Ch2Name
			endif
			SizeImage(300, WindowName=s_name)
			
		elseif(nChannels==3)	
			display /k=1; Appendimage $Ch1Name; 
			DoUpdate	
			if (dimsize($Ch1Name, 2) > 1)
				WMAppend3DImageSlider();
			elseif (dimsize($Ch1Name, 2) < 2)
				redimension /n=(-1,-1,0,0) $Ch1Name
			endif
			SizeImage(300, WindowName=s_name)
			
			display /k=1; Appendimage $Ch2Name; 
			DoUpdate	
			if (dimsize($Ch2Name, 2) > 1)
				WMAppend3DImageSlider();
			elseif (dimsize($Ch2Name, 2) < 2)
				redimension /n=(-1,-1,0,0) $Ch2Name
			endif
			SizeImage(300, WindowName=s_name)
			
			display /k=1; Appendimage $Ch3Name; 
			DoUpdate
			if (dimsize($Ch3Name, 2) > 1)
				WMAppend3DImageSlider();
			elseif (dimsize($Ch3Name, 2) < 2)
				redimension /n=(-1,-1,0,0) $Ch3Name
			endif
			SizeImage(300, WindowName=s_name)
		endif
			
	endif
		
break

case "ROI":
	WMCreateImageROIPanel();
break

case  "Contrast":
WMCreateImageContrastGraph();
break

case "QuickAnalyze":
QuickAnalysis($g_NameOf3DWave)
break

case "GammaAdjust":
DisplayGammaCorrCP()
break

/////////////Man Thresh////////////////////

case "ManThresh":	
SVAR g_QAMethodType=WF:g_QAMethodType, g_QAstatus=WF:g_QAstatus,  g_MTMethod = WF:g_MTMethod
NVAR g_ThresholdLevelNumber = WF:g_ThresholdLevelNumber
 g_MTMethod = g_QAMethodType


	strswitch(g_QAMethodType) //Average;SD;Raw Image
	Case "Average":
	g_QAStatus = "Calculating average"
	DoUpdate
	DoUpdate
	avgZ($g_NameOf3DWave, nameofwave($g_NameOf3DWave)+"_THR")
	break
	
	Case "SD":
	g_QAStatus = "Calculating SD"
	DoUpdate
	DoUpdate
	stdevZ($g_NameOf3DWave, nameofwave($g_NameOf3DWave)+"_THR")
	break
	
	Case "Raw Image":
	variable xdim, ydim
	string name = nameofwave($g_NameOf3DWave)+"_THR"
	wave ImageStack=$g_NameOf3DWave
	xdim = dimsize(ImageStack, 0)
	ydim = dimsize(ImageStack, 1)
	Duplicate /o $g_NameOf3DWave, $name
	Redimension /N=(-1,-1,0,0) $name
	break
	
	Case "Response":
		g_QAStatus = "Define Stimulus"
		GetTimes($g_NameOf3DWave, g_NameOf3DWave+"_THR")
		
	
	break
	
	Case "Max":
		g_QAStatus = "Calculating Max"
		DoUpdate
		MaxZ($g_NameOf3DWave, nameofwave($g_NameOf3DWave)+"_THR")
	
	break
	
	default:
	Print "Default Case, using Average"
	g_QAStatus = "Calculating average"
	DoUpdate
	DoUpdate
	avgZ($g_NameOf3DWave, nameofwave($g_NameOf3DWave)+"_THR")
	break
	endswitch
	
g_QAStatus = "Manual Thresholding"
	DoUpdate

ManThresh($g_NameOf3DWave+"_THR", g_ThresholdLevelNumber)
killwaves /z Threshold_Base2
break

g_QAStatus = "Not Running"
	DoUpdate

default:
Print "Undefined button pressed:"
print ctlname
break
endswitch
end


////////////////////////////////Popup Control////////////////////////////////////////

Function PopProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
//Print "CtrlName=", ctrlname	//Name of the PopMenu
//Print "PopNum=",popnum		
//print "PoPStr=",popstr			//Name of the Choice

DFREF WF= root:Packages:IACP

String targetname
SVAR g_NameOf3DWave=WF:g_NameOf3DWave, g_NameOf1DWave=WF:g_NameOf1DWave,  g_NameOf2DWave=WF:g_NameOf2DWave, g_QAMethodType=WF:g_QAMethodType
NVAR g_MultiroiCheckBox=WF:g_MultiroiCheckBox, g_autoname=WF:g_autoname, g_AutoDisplay=WF:g_AutoDisplay,   g_HeaderInfo=WF:g_HeaderInfo

string NewName

strswitch(ctrlname)
	case "Waves_list3D": 
	g_NameOf3DWave = popStr
	Button QuickAnalyze, disable = 0
	Popupmenu Action3D , disable = 0
	Button ManThresh, disable = 0
	 g_HeaderInfo = 0
	 //CheckBox HeaderInfo, pos = {210,row3+32}, size = {20,20}, proc=CBControl, title = "Include Header Info?", value = g_headerinfo, disable = 0

	break
	/////////////
	case "Waves_list1D": 
	g_NameOf1DWave = popStr
	Popupmenu Action1D, disable = 0
	break
	/////////////
	case "Waves_list2D":
	g_NameOf2DWave = popStr
	PopupMenu Action2D, disable = 0
	
	break
	/////////////
	case "Action3D":
		strswitch(popstr)
		case "Display":
		break
		default:
			if (g_AutoName)
			targetname = g_NameOf3DWave+"_"+popstr[0,2]
			else
				prompt targetname, "Enter name for target wave"
				doprompt "Graph wave", targetname
				if (V_Flag)
					return -1
				endif
			endif
		endswitch //popstr
	
	strswitch(popstr) 
		case "Average":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				avgZ($g_NameOf3DWave,targetname)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name)
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Max":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				MaxZ($g_NameOf3DWave,targetname)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name)
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Min":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				MinZ($g_NameOf3DWave,targetname)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name)
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "SD":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				StDevZ($g_NameOf3DWave,targetname)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name)
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Range":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				RangeZ($g_NameOf3DWave,targetname)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name)
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Subtract BG":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				Wave M_ROIMask
				SubstBG($g_NameOf3DWave,targetname,M_ROIMask)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name);DelayUpdate
					WMAppend3DImageSlider();
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Normalize BG":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				NormBG($g_NameOf3DWave,targetname,M_ROIMask)
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name);DelayUpdate
					WMAppend3DImageSlider();
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Register":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				if (g_AutoName)
					RegisterStack($g_NameOf3DWave)
					targetname=g_NameOf3DWave+"_reg"
				else
					RegisterStack($g_NameOf3DWave, target=targetname)
				endif
				if (g_AutoDisplay)
					display /k= 1; appendimage $targetname
					DoUpdate
					SizeImage(300, WindowName=s_name)
					WMAppend3DImageSlider();
				endif
			endswitch //g_NameOf1DWave
		break
		
		case "Rename":
			NewName=RenameWave($g_NameOf3DWave)
			g_NameOf3DWave=NewName
			Popupmenu Waves_list3D, mode=1,popvalue=NewName, value=WaveList("*",";","TEXT:0,DIMS:3")
		break
		
		
		
		case "Z-Stack":
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				variable roinumber = 0
				if (g_MultiROICheckBox)
					MultiROI(:M_ROIMask, "MR_ROIMask")
					wave MR_ROIMask
					 roinumber = MultiROIZstack($g_NameOf3DWave,targetname,MR_ROIMask)
				else
					ZStack($g_NameOf3DWave,targetname,:M_ROIMask)
				endif
				
				if (g_AutoDisplay && g_MultiROICheckBox)
					display /k=1; appendimage $targetname
				elseif (g_Autodisplay)
					display /k= 1 $targetname				
				endif
			endswitch //g_NameOf3DWave
		break
		
		case "Display": 
			strswitch(g_NameOf3DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				Display /k=1;AppendImage/g=1 $g_NameOf3DWave
				DoUpdate
				WMAppend3DImageSlider(); DoUpdate
				SizeImage(300, WindowName=s_name);DelayUpdate			
			endswitch //g_NameOf1DWave
		break
		
		
		case "Response Image":
			variable GT_succeed 
			string RI_newname = g_NameOf3DWave+"_RI"
			GT_succeed = GetTimes($g_NameOf3DWave, RI_newname)
		
			if(GT_succeed == 1)
				Display/k=1
				AppendImage $RI_newname
				DoUpDate
				SizeImage(300)
			
			endif
		
		break
		
		
		case "Threshold":
			ManThresh($g_NameOf3DWave, 3)
		break
		
		case "Invert":
			Wave inverted = InvertImage($g_NameOf3DWave)		
			if(g_autodisplay)
				display
				appendimage inverted
				doupdate
				sizeimage(300)
			endif	
		break
		
		case "Rotate":
			RotateGUI(image=$g_NameOf3DWave)
		break
		
		case "View Properties":
			showheaderinfo($g_NameOf3DWave)
		break
		
		case "Filter2":
			variable fil=Filter2($g_NameOf3DWave)
			if (fil & g_autodisplay)
				Display /k=1;AppendImage $g_NameOf3DWave+"_fil"; 
					DoUpdate				
					WMAppend3DImageSlider(); DoUpdate
					SizeImage(300, WindowName=s_name);DelayUpdate
			endif
		break
		
		case "Save":
			SaveTiff($g_NameOf3DWave)
		break
		
		case "Compress":
			Imagetransform compress $g_NameOf3DWave
			rename w_compressed, $(g_NameOf3DWave+"_comp")
		break
		
		case "Kill":
		DoAlert 1, "Kill <"+g_NameOf3DWave+">? (Won't have any effect if wave is in use.)"
			If (v_flag)
				killwaves /z $g_NameOf3DWave
			endif
			
			Popupmenu Waves_list3D, mode=1,popvalue="Select 3D Wave", value=WaveList("*",";","TEXT:0,DIMS:3")


		break
		
		
	endswitch
	
	
	break
	/////////////
	case "Action1D":
		strswitch(popstr)
		
		case "Display":
			strswitch(g_NameOf1DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				Display /k=1 $g_NameOf1DWave
			endswitch //g_NameOf1DWave
			
		break
		
		case "Kill":
			DoAlert 1, "Kill <"+g_NameOf1DWave+">? (Won't have any effect if wave is in use.)"
				If (v_flag)
					KillWaves/z $g_NameOf1DWave
				endif
				Popupmenu Waves_list1D, mode=1, popvalue="Select Graph Wave", value=WaveList("*",";","TEXT:0,DIMS:1")

			break

		case "Rename":
			NewName=RenameWave($g_NameOf1DWave)
			g_NameOf1DWave=NewName
			Popupmenu Waves_list1D, mode=1, popvalue=NewName, value=WaveList("*",";","TEXT:0,DIMS:1")
		break
			
			
		case "Decompress":
			Imagetransform decompress $g_NameOf1DWave
			rename w_decompressed, $(g_NameOf1DWave+"_dc")
		break
		
			

		case "Normalize":
		if(g_AutoName)
			targetname = g_NameOf1DWave+"_"+popstr[0,2]
			else
					prompt targetname, "Enter name for target wave"
					doprompt "Graph wave", targetname
					if (V_Flag)
						return -1
					endif
			endif
		strswitch(g_NameOf1DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
				IACPnormalize($g_NameOf1DWave,targetname)
				
				if (g_AutoDisplay)
				display /k= 1 $targetname
				endif
				
			endswitch //g_NameOf1DWave
		break
		
		case "Rectify (pos.)":
		if(g_AutoName)
			targetname = g_NameOf1DWave+"_"+popstr[0,2]
			else
					prompt targetname, "Enter name for target wave"
					doprompt "Graph wave", targetname
					if (V_Flag)
						return -1
					endif
			endif
		strswitch(g_NameOf1DWave)
				case "none":		
				Print "Please select an appropriate wave"
				break
				default:
			rectify($g_NameOf1DWave,targetname)
			if (g_AutoDisplay)
				display /k= 1 $targetname
				endif
			endswitch //g_NameOf1DWave
		break
		
		
		
		endswitch //popstr
	
	
	/////////
	Case "QAMethod":
	NVAR  g_ThresholdLevelNumber = WF:g_ThresholdLevelNumber
		g_QAMethodType = popstr
		StrSwitch(PopStr)
		//Case "Average":
		
		//break
		//Case "SD":
		
		//break
		Case "Raw Image":
			Setvariable ThresholdLevel, win = IAControlPanel, pos={20, row3 + 97} , size = {160,20}, noproc, limits={1,2^16,0.1},noedit=0, value = g_ThresholdLevelNumber, title="Threshold levels", disable = 1
		//Setvariable DiscardLevel, win = IAControlPanel, pos={20, row3 + 105} , size = {120,20}, noproc, limits={1,g_ThresholdLevelNumber - 1,1},noedit=0, value = g_DiscardLevelNumber, title="Discard levels", disable = 1
		break
		default:
			Setvariable ThresholdLevel, win = IAControlPanel, pos={20, row3 + 97} , size = {160,20}, noproc, limits={1,2^16,0.1},noedit=0, value = g_ThresholdLevelNumber, title="Threshold levels", disable = 0
		//Setvariable DiscardLevel, win = IAControlPanel, pos={20, row3 + 105} , size = {120,20}, noproc, limits={1,g_ThresholdLevelNumber - 1,1},noedit=0, value = g_DiscardLevelNumber, title="Discard levels", disable = 0
		break
		endswitch
	
	break
		
	//////////////
	Case "ROIWave":
	SVAR g_NameOfROIWave = WF:g_NameOfROIWave
	g_NameOfROIWave = popstr
	//////////////
	
	
	
	break
	
	Case "Action2D":
		StrSwitch(PopStr)
			Case "Display":
				Display /k=1; Appendimage $g_NameOf2DWave
				DoUpdate
				SizeImage(300, WindowName=s_name)
			break
			
			Case "Filter3":
				Filter2($g_NameOf2DWave)
				if (g_autodisplay)
					Display /k=1;AppendImage $g_NameOf2DWave+"_fil"; 
					DoUpdate
					SizeImage(300, WindowName=s_name);DelayUpdate
				endif
			break
				
			Case "Kill":
				DoAlert 1, "Kill <"+g_NameOf2DWave+">? (Won't have any effect if wave is in use.)"
				If (v_flag)
					KillWaves/z $g_NameOf2DWave
				endif
				Popupmenu Waves_list2D, mode=1,popvalue="Select Image Wave", value=WaveList("*",";","TEXT:0,DIMS:2")

			break
			
			case "PopWaveBrowse":
				PoPWaveBrowser(PopWave=$g_NameOf2DWave)
			break
			
			case "PopX2Traces":
				variable ntraces=DimSize($g_NameOf2DWave,1)
				DoAlert 1, "WARNING: This will produce "+Num2Str(ntraces)+" waves which will hopelessly clutter your experiment. There might be a better way to do this. Proceed?"
					if(v_flag==1)
						PopX2Traces($g_NameOf2DWave,g_NameOf2DWave)			
					endif
			break
			
			case "Rename":
				NewName=RenameWave($g_NameOf2DWave)
				g_NameOf2DWave=NewName
				Popupmenu Waves_list2D, mode=1,popvalue=NewName, value=WaveList("*",";","TEXT:0,DIMS:2")
			break
			
			case "Save":
				SaveTiff($g_NameOf2DWave)
			break
			
			case "Filter1":
				variable fil2=Filter2($g_NameOf2DWave)
				if(fil2 && g_AutoDisplay)
					string filD = g_NameOf2DWave+"_fil"
					display $filD
					SizeImage(300)					
					
				endif
			break
			
			case "Threshold":
				ManThresh($g_NameOf2DWave,3)
			
			break
			
			case "Invert":
				Wave inverted = InvertImage($g_NameOf2DWave)		
				if(g_autodisplay)
					display
					appendimage inverted
					doupdate
					sizeimage(300)
				endif	
			break
			
			case "Rotate":
				RotateGUI(image=$g_NameOf2DWave)
			break
		
			Default:
				Print "Undefined Action in Action2D: "+PopStr
		
		
		EndSwitch
	
	
	//insert new button above here
	break
	default:
			Print "Undefined Popup used: "+ctrlname	

endswitch //ctlname
end

/////////////////////////////////Checkbox Control//////////////////////

Function CBControl (ctrlName,checked) : CheckBoxControl

String ctrlName
Variable checked			// 1 if selelcted, 0 if not
DFREF WF=root:Packages:IACP

NVAR g_MultiroiCheckBox=WF:g_MultiroiCheckBox, g_AutoLayout=WF:g_AutoLayout, g_deltaFbyF=WF:g_deltaFbyF, BGSub=WF:g_BGSubtract

strswitch(ctrlName)
case "strange":
	NVAR g_AutoName= WF:g_AutoName
	g_autoname = checked
break

case "MultipleROIs":
	g_MultiroiCheckBox  = checked
break

case "AutoLayout":
	g_AutoLayout = checked
break

case "DeltaFbyF":
	g_deltaFbyF = checked
break

case "Autodisplay":
	NVAR g_AutoDisplay=WF:g_AutoDisplay
	g_AutoDisplay = checked
break

case "BGSubtr":
	BGSUB=checked
break


case "EqAx":
NVAR g_Axes=WF:g_Axes
g_axes = checked
break

default:
Print "Undefined CheckBox Checked:", ctrlName 
break
endswitch

End




//////////////////////////Variable Control/////////////////////////

//function Variables(ctrlName,varNum,varStr,varName) : SetVariableControl
//	String ctrlName
//	Variable varNum	// value of variable as number
//	String varStr		// value of variable as string
//	String varName	// name of variable
//	Variable /g g_ThresholdLevelNumber
//
//
//strswitch(ctrlname)
//case "ThresholdLevel":
//	if (g_DiscardLevelNumber >= g_ThresholdLevelNumber)
//	g_DiscardLevelNumber = g_ThresholdLevelNumber - 1
//	endif
//	Setvariable DiscardLevel, win = IAControlPanel, pos={20, row3 + 105} , size = {120,20}, noproc, limits={1,g_ThresholdLevelNumber - 1,1},noedit=0, value = g_DiscardLevelNumber, title="Discard levels"
//	Doupdate
//	break
//	default:
//	doupdate
//endswitch
//
//
//End

///////////////////Get Header Info//////////////////////////////////////
//Header File:
//[0]	Zoom factor
//[1]	x resolution (auto)
//[2]	y resolution (auto)
//[3]	z resolution (time)
//[4]	time/line
//String Headers	
//[0]	date
//[1]	age
//[2]	construct
//[3]	filename
//[4]	settings
//[5]	
//[6]	notes


//Function GetHeaderInfofromUser(Wave3D)
//Wave Wave3D
//string IACPHeader_Wavename, StringHeader_Wavename
//
//variable zoom = 1, x_res, y_res, z_res, x_dim, y_dim, z_dim, timeperline = 1
//string expdate, age, construct, filename , settings, notes
//
//IACPHeader_Wavename=nameofwave(wave3d)+"_head"
//StringHeader_Wavename=nameofwave(wave3d)+"_string"
//
//if (!(waveexists($IACPHeader_Wavename)))
//	make /o/n=5 headcalcwave	
//else
//	duplicate /o $IACPHeader_Wavename, headcalcwave
//	zoom = headcalcwave[0]
//	x_res = headcalcwave[1]
//	y_res= headcalcwave[2]
//	z_res =  headcalcwave[3]
//	timeperline = headcalcwave[4]
//endif
//
//
//if (!(waveexists($StringHeader_Wavename)))
//	make /o/t/n= 7 stringheadwave
//	filename = nameofwave(wave3d)
//	expdate = date()
//else
//	duplicate /o /t $StringHeader_Wavename, stringheadwave
//	expdate = stringheadwave[0]
//	age = stringheadwave[1]
//	construct = stringheadwave[2]
//	filename = stringheadwave[3]
//	settings = stringheadwave[4]
//	notes = stringheadwave[6]
//endif
//
//wave /t stringheadwave
//
//prompt Zoom, "Zoom factor"
//prompt timeperline, "ms per line"
//prompt expdate, "Date of exeriment"
//prompt age, "Age of test subject"
//prompt construct, "Construct"
//prompt filename, "Filename of stack"
//prompt settings, "Microscope settings"
//prompt notes, "Any other notes"
//doprompt "Header Info", zoom, timeperline, expdate, age, construct, filename, settings, notes
//if (v_flag)
//	return -1
//endif
//
////sidelength = 665.6 µm / zoom
//x_res = 665.6 / zoom / dimsize(wave3d,0)	//in µm
//y_res = 665.6 / zoom / dimsize(wave3d,1)	//in µm
//z_res = timeperline *  dimsize(wave3d,1)	//in ms
//
// headcalcwave[0] = zoom
// headcalcwave[1] = x_res
// headcalcwave[2] = y_res
// headcalcwave[3] = z_res 
// headcalcwave[4] = timeperline
// 
// 
// stringheadwave[0] =  expdate
// stringheadwave[1] = age
// stringheadwave[2] = construct
// stringheadwave[3] = filename 
// stringheadwave[4] = settings 
// stringheadwave[5] = ""
// stringheadwave[6] = notes
// 
//
//
//
//
//duplicate /o headcalcwave , $IACPHeader_Wavename		
//duplicate /o /t stringheadwave, $StringHeader_Wavename	
//killwaves/z headcalcwave, stringheadwave				
//return 1													
//end

/////read header info

function showheaderinfo(wave3d)

Wave Wave3D
string IACPHeader_Wavename, StringHeader_Wavename

variable zoom = 1, x_res, y_res, z_res, x_dim, y_dim, z_dim, timeperline = 1, numericwaveexists, stringwaveexists
variable xrel,yrel,zrel
string expdate, age, construct, filename, settings, notes, path

IACPHeader_Wavename=nameofwave(wave3d)+"_head"
StringHeader_Wavename=nameofwave(wave3d)+"_string"



	
	      zoom = ZoomFromHeader(wave3d)
		x_res = ImageLength / zoom / dimsize(wave3d,0)			//µm
		y_res=  ImageLength / zoom / dimsize(wave3d,1)			//µm
		z_res =  sPerLineFromHeader(wave3d)* dimsize(wave3d,1) //msec 2 sec
		timeperline = msPerLineFromHeader(wave3d)					//ms
		path=FilePathFromHeader(wave3d)

		expdate = ExpDateFromHeader(wave3d)
		filename =FilenameFromHeader(wave3d)
		Xrel=XRelFromHeader(wave3d)
		Yrel=YRelFromHeader(wave3d)
		Zrel=ZRelFromHeader(wave3d)
		
		if (zoom)
		numericwaveexists = 1
		else
		numericwaveexists = 0
		endif

	notes = "X="+num2str(Xrel)+" Y="+num2str(Yrel)+" Z="+num2str(Zrel)


if (wintype("IACP_HeaderDisplay"))
	killwindow IACP_HeaderDisplay
endif

NewPanel /W=(200,100,610,315) /K=1/N=IACP_HeaderDisplay as "Properties of <"+nameofwave(wave3d)+">" 
groupbox NumericValues, pos={5,5}, size = {400,100}
groupbox StringValues, pos={5,110}, size={400,100}
if (numericwaveexists)
	titlebox zoomTB, win= IACP_HeaderDisplay, fsize=11, pos={20,15}, size={205,20}, title="Zoom: "+num2str(zoom), frame =0
	if (x_res >= 1)
		titlebox xresTB, win= IACP_HeaderDisplay, fsize=11, pos={20,45}, size={205,20}, title="X resolution: "+num2str(x_res)+" µm per pixel", frame =0
	else
		titlebox xresTB, win= IACP_HeaderDisplay, fsize=11, pos={20,45}, size={205,20}, title="X resolution: "+num2str(1000*x_res)+" nm per pixel", frame =0
	endif
	if (y_res >=1)
		titlebox yresTB, win= IACP_HeaderDisplay, fsize=11, pos={20,75}, size={205,20}, title="Y resolution: "+num2str(y_res)+" µm per pixel", frame =0
	else
		titlebox yresTB, win= IACP_HeaderDisplay, fsize=11, pos={20,75}, size={205,20}, title="Y resolution: "+num2str(1000*y_res)+" nm per pixel", frame =0
	endif
	titlebox timeperlineTB, win= IACP_HeaderDisplay, fsize=11, pos={225,15}, size={205,20}, title=num2str(timeperline)+" ms per line", frame=0
	titlebox zresTB, win= IACP_HeaderDisplay, fsize=11, pos={225,45}, size={205,20}, title="Framerate: "+num2str(1000/z_res)+" Hz", frame =0
	titlebox zres2TB, win= IACP_HeaderDisplay, fsize=11, pos={225,75}, size={205,20}, title="1 frame every "+num2str(z_res)+" ms", frame =0

else
	titlebox WDNE_numTB, win= IACP_HeaderDisplay, fsize=11, pos={20,20}, size={180,20}, title="No header info avaiable: "


endif
if (numericwaveexists)
	titlebox DateTB, win= IACP_HeaderDisplay, fsize=11, pos={20,120}, size={205,20}, title="Date: "+expdate, frame =0
	//titlebox AgeTB, win= IACP_HeaderDisplay, fsize=11, pos={20,150}, size={205,20}, title="Age of test subject: "+age, frame =0
	//titlebox PathTB, win= IACP_HeaderDisplay, fsize=8, pos={20,180}, size={255,20}, title="Path: "+path, frame =0
	titlebox filenameTB, win= IACP_HeaderDisplay, fsize=11, pos={225,120}, size={205,20}, title="Filename: "+filename, frame =0
	//titlebox settingsTB, win= IACP_HeaderDisplay, fsize=11, pos={225,150}, size={205,20}, title="Settings: "+settings, frame =0
	titlebox notesTB, win= IACP_HeaderDisplay, fsize=11, pos={20,150}, size={205,20}, title="Position: "+notes, frame =0

else
titlebox WDNE_strTB, win= IACP_HeaderDisplay, fsize=11, pos={20,120}, size={180,20}, title="No header info avaiable: "

endif



killwaves/z headcalcwave, stringheadwave
end

////////////////////////////////////////////////////

Static Function/t RenameWave(wv)
	wave wv
	
	String NewName=NameOfWave(wv)
	Prompt NewName, "Enter a new name"
	
	do
		
		DoPrompt/help="Rename" "New Name", NewName
	
		if(v_flag==1)
			return NewName
		endif
	
		if(WaveExists($NewName))
			DoAlert 0, NewName+" exists already. Choose a different name."
		else
			rename wv, $newName
			break
		endif
	
	while(1)
	
	return NewName
End