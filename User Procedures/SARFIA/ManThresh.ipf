#pragma rtGlobals=1		// Use modern global access method.
#include <Image Contrast>
#include <Image Range Adjust>
#include <ImageSlider>
#include "EqualizeScaling"
#include "dif_image"
#include "ROISize"
#include "MultiROi"
#include "SaveTiff"
#include "SWT"

//Update 20100419: Cleaned up NVAR/SVAR calls; repaired kFilter in SWT thresholding

// ManThresh(picwave, startlevels) calls the manual threshold panel on the image picwave. Startlevels is the 
// starting threshold. 3 works fine for images I have tested. Internally, it is multiplied by the standard deviation
// of the image that is the sum of the 2nd derivatives in the x and y axis, or of the stationary wavelet transform.
//
// ImageUpdate is called whenever a parameter in the panel is changed and displays the new results after applying
// the appropriate algorithms.


function ManThresh(picwave, startlevels)
wave picwave
variable startlevels



DFREF saveDFR = GetDataFolderDFR()


variable screenright

GetWindow kwFrameInner wsize
	
	screenright = V_Right

variable left=screenright - 330, top = 270




If (WinType("ManThreshPanel"))
	doWindow /F ManThreshPanel
else

	If(DataFolderRefStatus(root:Packages)!=1)
		NewDataFolder root:Packages
		NewDataFolder root:Packages:ManThresh
		SetDataFolder root:Packages:ManThresh
	ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:ManThresh)!=1)
		NewDataFolder root:Packages:ManThresh
	ElseIf( DataFolderRefStatus(root:Packages:ManThresh)==1)
		//
	Else
		DoAlert 0, "IACP_Initialise failed due to conflict with a free data folder."
		return -1
	EndIf
	
	DFREF WF = root:Packages:ManThresh

	SetDataFolder WF
	
	variable/g g_ROIcount = 1, g_radius = 0,  g_stepsize = 0.2, g_currentlevels=startlevels, g_ThresholdLevelNumber
	variable/g g_ImageDims=WaveDims(picwave), g_loop3D = 0, g_Laplace=1, g_SWT=0, g_LevelCorr=2, g_MaxCorr=2
	variable /g g_kFilter=0
	string /g g_QAStatus, g_picwavename = NameOfWave(picwave), g_ROICountStr = " "
	
	


	NewPanel /K=1 /N=ManThreshPanel /W = (left,top,left+330, top+250) as "Thresholding"
	Groupbox GBx1 pos={5,5}, size={320,240}
	Button SaveButton pos={20, 215}, size = {100,20}, proc = MTButton, title = "Save Settings"
	Button CancelButton pos={230, 215}, size = {80,20}, proc = MTButton, title = "Cancel"
	Button IgContrast pos={20, 180}, size = {80,20}, proc = MTButton, title = "Contrast"
	Button IgHist pos={140, 180}, size = {80,20}, proc = MTButton, title = "Range"
	setvariable LevelVar pos={20, 35}, size = {200,20}, win = ManThreshPanel, proc = MT_VC, limits = {0,inf,g_stepsize}, value = g_currentlevels, title = "Threshold levels ", fsize = 12

	setvariable Radius pos={20, 70}, size = {240,20}, win = ManThreshPanel, proc = MT_VC, limits = {0,inf,1}, value = g_radius, title = "Remove ROIs smaller than (px)", fsize = 12
	TitleBox ShowROINumTB pos = {20, 135}, win = ManThreshPanel, title =  g_ROICountStr, size = {120, 40}, fsize = 12
	
	Titlebox Meth pos={20,100}, win = ManThreshPanel, title="Transform:", frame=0
	CheckBox Laplace pos={80,100}, win = ManThreshPanel, mode=1, proc=MT_CBC, title="Laplace", variable=g_laplace
	CheckBox SWT pos={140,100}, win = ManThreshPanel, mode=1, proc=MT_CBC, title="Wavelet", variable=g_SWT
	setVariable lCorr, pos={200,100}, win = ManThreshPanel,size={120,20}, variable=g_LevelCorr, disable=1, Title="Level of Corr.", proc=MT_VC
	setVariable kFil, pos={200,130}, win = ManThreshPanel,size={120,20}, variable=g_kFilter, disable=1, Title="\f02k\f00 Filter", proc=MT_VC, limits = {0,inf,0.5}
	

	
endif

SetDataFolder saveDFR
NVAR g_radius=WF:g_radius, ImageDims = WF:g_ImageDims

ImageUpdate(picwave, g_currentlevels,g_radius, g_SWT)
Wave ROI_CalcWave
 
 	//thresh2roi(ROI_calcwave, "ROI_calcwave")

If (WinType("ManualThreshold"))
			killwindow ManualThreshold
endif

CopyScaling(picwave,ROI_calcwave)
display /n=ManualThreshold;
appendimage picwave; appendimage ROI_calcwave
ModifyImage ROI_calcwave ctab= {*,0,Rainbow,0};DelayUpdate
ModifyImage ROI_calcwave minRGB=NaN,maxRGB=NaN; DoUpdate
DoUpDate; SizeImage(400)
if (ImageDims == 3)
	WMAppend3DImageSlider(); 
endif

doWindow /F ManThreshPanel

end

///////////////////////Image Update////////////////////

Static Function ImageUpdate(picwave, startlevels,radius,method)
	wave picwave
	variable startlevels,radius, method
	DFREF WF = root:Packages:ManThresh
	NVAR  g_ROICount=WF:g_ROICount, g_ImageDims=WF:g_ImageDims
	NVAR g_loop3D = WF:g_loop3D
	NVAR Laplace=WF:g_Laplace, SWT = WF:g_SWT, Stop=WF:g_levelcorr, g_MaxCorr=WF:g_MaxCorr, kFilter=WF:g_kFilter
	SVAR  g_ROICountStr=WF:g_ROICountStr
	
	DFREF saveDFR = GetDataFolderDFR()
	DFREF WF = root:Packages:ManThresh
	
	Variable nROIs
	
	Switch(method)
	
	case 1:	//SWT
		if(g_ImageDims==2)
			if(WaveExists (WF:Pie))
				Wave locPie=WF:Pie		
			else
				SetDataFolder WF
				SWT2D(picwave, filter=kFilter)
				Wave A_Wave, Wavelet
				
				BigPi2D(wavelet,stop=g_MaxCorr)
				Wave locPie=WF:Pie	
				 SetDataFolder saveDFR				
			 endif
			 
			 ImageStats locPie
			 startlevels *= v_sdev //scale for SD
			 Duplicate/o locPie, ROI_CalcWave
			 
			 MultiThread ROi_CalcWave=SelectNumber(locPie[p][q]>startlevels,1,0)		//Thresholding
			 g_ROICount=MultiROI(ROi_CalcWave,"ROi_CalcWave")								//MultiROI
			 			 
			 if (WinType("ManualThreshold"))
				doWindow /F ManualThreshold
			else
				display /n=ManualThreshold; appendimage picwave; appendimage ROI_calcwave
				ModifyImage ROI_calcwave ctab= {*,0,Rainbow,0};DelayUpdate
				ModifyImage ROI_calcwave minRGB=NaN,maxRGB=NaN;DelayUpdate
				DoUpdate
				SizeImage(400)
			endif
			
			
		elseif(g_ImageDims==3)
			 if(WaveExists (WF:Pie))
				Wave locPie=WF:Pie		
			else
				SetDataFolder WF
				SWT3D(picwave, filter=kFilter)
				Wave A_Wave, Wavelet
				
				BigPi3D(Wavelet,stop=2)
				Wave locPie=WF:Pie
				 SetDataFolder saveDFR				
			 endif
			 
			 ImageStats locPie
			 startlevels *= v_sdev //scale for SD
			 Duplicate locPie, ROI_CalcWave
			 
			 MultiThread ROi_CalcWave=SelectNumber(locPie[p][q][r]>startlevels,1,0)		//Thresholding
			g_ROICount=MultiROI(ROi_CalcWave,"ROi_CalcWave")							//MultiROI
			 			 
			 if (WinType("ManualThreshold"))
				doWindow /F ManualThreshold
			else
				display /n=ManualThreshold; appendimage picwave; appendimage ROI_calcwave
				ModifyImage ROI_calcwave ctab= {*,0,Rainbow,0};DelayUpdate
				ModifyImage ROI_calcwave minRGB=NaN,maxRGB=NaN;DelayUpdate
				WMAppend3DImageSlider(); 
				DoUpdate
				SizeImage(400)
			endif
			 			 
			 			 
		
		endif
	
		 if(radius)
			 	g_ROIcount = RemoveROI(ROI_calcwave,radius)
			 	wave ROI_edit
			 	duplicate /o ROI_edit, ROI_calcwave
			 	killwaves /z ROI_edit
		 endif
			
			 g_ROICountStr =  num2str(g_ROICount)+" ROIs"
			 CopyScaling(picwave,ROI_calcwave)
			 DoUpdate
	
	break
	
	default:	//Laplace
		if(g_ImageDims==2)
			 dif_image(picwave, targetname="DI_calcwave")
			 wave DI_calcwave
			 
			 imagestats DI_calcwave
			 startlevels *= v_sdev //scale for SD
			 
			 mod_img(DI_calcwave, startlevels, targetname="ROI_calcwave")
			 wave ROI_calcwave
			 
			
			 
			 g_ROICount = multiroi(ROI_Calcwave, "ROI_calcwave")
			
			
			
			 if(radius)
			 	g_ROIcount = RemoveROI(ROI_calcwave,radius)
			 	wave ROI_edit
			 	duplicate /o ROI_edit, ROI_calcwave
			 	killwaves /z ROI_edit
			 endif
			
			  g_ROICountStr =  num2str(g_ROICount)+" ROIs"
			 CopyScaling(picwave,ROI_calcwave)
			DelayUpdate
			
			if (WinType("ManualThreshold"))
				doWindow /F ManualThreshold
			else
				display /n=ManualThreshold; appendimage picwave; appendimage ROI_calcwave
				ModifyImage ROI_calcwave ctab= {*,0,Rainbow,0};DelayUpdate
				ModifyImage ROI_calcwave minRGB=NaN,maxRGB=NaN;DelayUpdate
				DoUpdate
				SizeImage(400)
				DoUpdate
			endif
		elseif(g_ImageDims==3)
			if(g_loop3D == 1)
				difloop(picwave, targetname="DI_calcwave")
			else
				dif_image3D(picwave, targetname="DI_calcwave")
			endif
			
			 wave DI_calcwave
			 
			 imagestats DI_calcwave
			 startlevels *= v_sdev //scale for SD
			 
			 mod_img(DI_calcwave, startlevels, targetname="ROI_calcwave")
			 wave ROI_calcwave
			 
			
			 
			 g_ROICount = Multiroi(ROI_Calcwave, "ROI_calcwave")
			
			
			
			 if(radius)
			 	g_ROIcount = RemoveROI(ROI_calcwave,radius)
			 	wave ROI_edit
			 	duplicate /o ROI_edit, ROI_calcwave
			 	killwaves /z ROI_edit
			 endif
			
			  g_ROICountStr =  num2str(g_ROICount)+" ROIs"
			 CopyScaling(picwave,ROI_calcwave)
			DelayUpdate
			
			if (WinType("ManualThreshold"))
				doWindow /F ManualThreshold
			else
				display /n=ManualThreshold; appendimage picwave; appendimage ROI_calcwave
				ModifyImage ROI_calcwave ctab= {*,0,Rainbow,0};DelayUpdate
				ModifyImage ROI_calcwave minRGB=NaN,maxRGB=NaN;DelayUpdate
				WMAppend3DImageSlider(); 
				DoUpdate
				SizeImage(400)
			endif
		
		
		endif
		
		break
	endswitch
	
	If (WinType("ManThreshPanel"))
		doWindow /F ManThreshPanel
		TitleBox ShowROINumTB win = ManThreshPanel, title =  g_ROICountStr, size = {120, 40}, fsize = 12
	endif
		
	DoUpdate

end

/////////////////////Checkbox Control/////////////////

Function MT_CBC (ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selelcted, 0 if not

	DFREF WF = root:Packages:ManThresh
	NVAR g_currentlevels=WF:g_currentlevels, g_radius=WF:g_radius, g_ThresholdLevelNumber=WF:g_ThresholdLevelNumber
	NVAR /z IACP_ThresholdLevelNumber=root:Packages:IACP:g_ThresholdLevelNumber 
	NVAR Laplace=WF:g_Laplace, SWT = WF:g_SWT, g_MaxCorr=WF:g_MaxCorr
	SVAR/z g_QAStatus=root:Packages:IACP:g_QAStatus
	SVAR g_PicWaveName=WF:g_PicWaveName
	
	Variable maxCorr
	
	DFREF saveDFR = GetDataFolderDFR()
	DFREF WF = root:Packages:ManThresh
	
	StrSwitch (ctrlName)
	
	Case "Laplace":
		Laplace=1
		SWT=0
		setVariable lCorr disable=1
		setVariable kFil disable=1
	break
	
	Case "SWT":
		Laplace=0
		SWT=1
		setVariable lCorr disable=0
		setVariable kFil disable=0
		
	break
	
	EndSwitch
	
	ImageUpdate($g_PicWaveName, g_currentlevels,g_radius,SWT)
	
	if(WaveExists (WF:Wavelet))
	
		Variable WD=WaveDims(WF:Wavelet)
	
		maxCorr=dimsize(WF:Wavelet,(WD-1))
			
		setVariable lCorr limits={2,maxCorr,2}
		g_MaxCorr=maxCorr
		
	endif
	

End

/////////////////////Button Control/////////////////
Function MTButton(ctlname) : ButtonControl
string ctlname
DFREF WF = root:Packages:ManThresh
NVAR g_currentlevels=WF:g_currentlevels, g_radius=WF:g_radius, g_ThresholdLevelNumber=WF:g_ThresholdLevelNumber
NVAR /z IACP_ThresholdLevelNumber=root:Packages:IACP:g_ThresholdLevelNumber 
SVAR/z g_QAStatus=root:Packages:IACP:g_QAStatus

strswitch(ctlname)
	case "CancelButton":
		killwaves /z ROI_calcwave, DI_calcwave
		If (WinType("ManualThreshold"))
			killwindow ManualThreshold
			KillDataFolder /z WF
		endif
		If (WinType("WMContrastAdjustGraph"))
			killwindow WMContrastAdjustGraph
		endif
		
		If (WinType("WMImageRangeGraph"))
			killwindow WMImageRangeGraph
		endif
		
		
		killvariables /z g_currentlevels
		killwindow ManThreshPanel
		killwaves /z ROI_calcwave, DI_calcwave
		g_QAStatus = "Thresholding cancelled"
		DoUpdate
		KillDataFolder/z WF

	break
	case "SaveButton":
	wave ROI_calcwave


	duplicate/o ROI_Calcwave MTROIWave
	killwaves /z ROI_calcwave
		If (WinType("ManualThreshold"))
			killwindow ManualThreshold
		endif
		If (WinType("WMContrastAdjustGraph"))
			killwindow WMContrastAdjustGraph
		endif
		If (WinType("WMImageRangeGraph"))
			killwindow WMImageRangeGraph
		endif
		killvariables /z g_currentlevels
		killwindow ManThreshPanel
		killwaves /z ROI_calcwave, DI_calcwave
		g_QAStatus = "Saved ROI Wave"
		g_ThresholdLevelNumber = g_currentlevels
		IACP_ThresholdLevelNumber= g_currentlevels
		DoUpdate
		KillDataFolder WF
	break
	case "IgContrast":
		WMCreateImageContrastGraph();
	break
	case "IgHist":
		WMCreateImageRangeGraph();
	break
	default:
	print "Undefined Button in ManThresh pressed:", ctlname
	break
endswitch

end


//////////////////////////Variable Control////////////////////////

Function MT_VC (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	DFREF WF = root:Packages:ManThresh
	NVAR g_currentlevels=WF:g_currentlevels, g_radius=WF:g_radius, g_radius=WF:g_radius
	SVAR g_PicWaveName=WF:g_PicWaveName
	NVAR/z IACP_ThresholdLevels=root:Packages:IACP:g_ThresholdLevelNumber
	NVAR  SWT=WF:g_SWT, g_ImageDims=WF:g_ImageDims, Stop=WF:g_levelcorr, g_MaxCorr=WF:g_MaxCorr, kFilter=WF:g_kFilter


	DFREF saveDFR = GetDataFolderDFR()
	DFREF WF = root:Packages:ManThresh
	
	wave picwave=$g_PicWaveName
	
	strswitch(ctrlname)
	case "LevelVar":
		g_currentlevels = varnum
		IACP_ThresholdLevels = g_currentlevels
		ImageUpdate(picwave, g_currentlevels,g_radius,SWT)
	break
	

	case "Radius":
		g_radius = round(varnum)
		ImageUpdate(picwave, g_currentlevels,g_radius,SWT)
	break
	
	case "lCorr":
	
	Stop=round(stop)
	
	if(g_ImageDims==2)
			if(WaveExists (WF:Wavelet))
				SetDataFolder WF
				Wave  Wavelet
				if(varNum>0)
					BigPi2D(Wavelet,stop=varNum)
				else
					BigPi2D(Wavelet,stop=g_MaxCorr)
				endif
				
			
				 SetDataFolder saveDFR	
			else
				SetDataFolder WF
				SWT2D(picwave, filter=kFilter)
				Wave A_Wave, Wavelet
				
				if(varNum>0)
					BigPi2D(Wavelet,stop=varNum)
				else
					BigPi2D(Wavelet,stop=g_MaxCorr)
				endif
				
				 SetDataFolder saveDFR				
			 endif
			 
		
			
			
		elseif(g_ImageDims==3)
			 if(WaveExists (WF:Pie))
				SetDataFolder WF
				Wave Wavelet
				if(varNum>0)
					BigPi3D(Wavelet,stop=varNum)
				else
					BigPi3D(Wavelet,stop=g_MaxCorr)
				endif
				 SetDataFolder saveDFR			
			else
				SetDataFolder WF
				SWT3D(picwave, filter=kFilter)
				Wave A_Wave, Wavelet
				
				if(varNum>0)
					BigPi3D(Wavelet,stop=varNum)
				else
					BigPi3D(Wavelet,stop=g_MaxCorr)
				endif
				
				 SetDataFolder saveDFR				
			 endif
			 
			 
		endif
	
				
		ImageUpdate(picwave, g_currentlevels,g_radius,SWT)
	
	
	break
	
	case "kFil":
		if(g_ImageDims==2)
				SetDataFolder WF
				SWT2D(picwave, filter=kFilter)
				Wave A_Wave, Wavelet
				
				BigPi2D(Wavelet,stop=Stop)
				
				 SetDataFolder saveDFR		
				 
		elseif(g_ImageDims==3)
				SetDataFolder WF
				SWT3D(picwave, filter=kFilter)
				Wave A_Wave, Wavelet
				
				BigPi3D(Wavelet,stop=Stop)
								
				 SetDataFolder saveDFR	
	
		endif
	
		ImageUpdate(picwave, g_currentlevels,g_radius,SWT)
	break
	
	
	default:
		print "Undefinded variable set:", ctrlname
	break
	endswitch
End