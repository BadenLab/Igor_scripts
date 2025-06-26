#pragma rtGlobals=1		// Use modern global access method.
#INCLUDE "SaveTiff"
#include "RotateFunction"
#include <ImageSlider>

Function RotateGUI([image])
	Wave Image
	
	string Information = IgorInfo(0), infolist, infolist2, infolist3
	variable screenright, screenbottom
	
	If(DataFolderRefStatus(root:Packages)!=1)
			NewDataFolder root:Packages
			NewDataFolder root:Packages:RotateGUI
		ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:RotateGUI)!=1)
			NewDataFolder root:Packages:RotateGUI
		ElseIf( DataFolderRefStatus(root:Packages:RotateGUI)==1)
			//
		Else
			DoAlert 0, "RotateGUI_Initialise failed due to conflict with a free data folder."
			return -1
		EndIf
	
	DFREF WF=Root:Packages:RotateGUI, SaveDFR=GetDataFolderDFR()
	SetDataFolder WF
		variable /g g_Matrix=1, g_rImage=0, g_angle=0, g_warning=1,g_scaled=0
		string /g g_RotImg="_none_"
	SetDataFolder SaveDFR
	
		NVAR  g_Matrix=WF:g_Matrix, g_rImage=WF:g_rImage, g_angle=WF:g_angle, g_warning=WF:g_warning,g_scaled=WF:g_Scaled
		SVAR g_RotImg=WF:g_RotImg
		
		
	
	infolist = StringFromList(4,information,";")
	infolist2 = StringFromList(3,infolist,",")
	infolist3 = StringFromList(4,infolist,",")
	screenright = Str2Num(infolist2)
	screenbottom = Str2Num(infolist3)
	
	variable left=round(screenright/2), top = 200
	
	If(WinType("RotationGUI")>0)
		doWindow /f RotationGUI
	else
	
		NewPanel /K=2 /N=RotationGUI /W = (left,top,left+330, top+150) as "Rotate Image"
		Groupbox RIGBx pos={5,5}, size={320,140}
		PopupMenu RotImage  pos={245,15},bodywidth=240,mode=1,Proc=RGPopUp, title="Image",popvalue="Select Image/Stack", value=WaveList("*",";","TEXT:0,MINROWS:2")+"_none_"
		CheckBox Matrix pos={55,50}, title="Matrix Rotation", Proc=RGCBC, variable=g_Matrix,  mode=1
		CheckBox Img pos={155,50}, title="Image Rotation", Proc=RGCBC, variable=g_rImage,  mode=1
		SetVariable Angle, pos={85,80},title="Angle",Proc=RGVC,variable=g_angle, limits={-359,359,1}, bodywidth=80
		Button RGSaveButton pos={55, 110}, size = {100,20}, Proc=RGBC, title = "Save Settings"
		Button RGCancelButton pos={200, 110}, size = {80,20}, Proc=RGBC, title = "Cancel"
		CheckBox Scaled pos={155,75}, Title="Scaled image rotation?", Proc=RGCBC, variable=g_scaled, disable=2
	
	EndIf
	
	
	if(ParamisDefault(image))
		g_RotImg="_none_"
	else
		g_RotImg=NameOfWave(image)
		ShowRot(image,g_angle,g_matrix, g_scaled)
		PopupMenu RotImage, win=RotationGUI,popvalue="hello?", value=WaveList("*",";","TEXT:0,MINROWS:2")+"_none_"//g_RotImg
	endif

	
End

///////////////////////////////Display////////////////////////////////////////////

Static Function ShowRot(Image, Angle, Method,Scaled)
wave Image
variable angle, method, Scaled

DFREF WF=Root:Packages:RotateGUI, SaveDFR=GetDataFolderDFR()

NVAR  g_Matrix=WF:g_Matrix, g_rImage=WF:g_rImage, g_angle=WF:g_angle, g_warning=WF:g_warning,g_scaled=WF:g_Scaled
SVAR g_RotImg=WF:g_RotImg

if(dimdelta(image,0) != dimdelta(image,1) && g_warning)
	DoAlert 1, "You are attemting to rotate an image with non square pixels. This will screw up the scaling. Continue?"
	
		if(v_flag !=1)
			return -1
		else
			g_warning = 0
		endif

Endif

If(Mod(Angle,360)!=0)
	If(Method==1)	//Matrix
	
		RotateImage(image,angle)
		Wave W_RotatedImage
		Duplicate /o W_RotatedImage RotatedImage 
		Killwaves/z W_RotatedImage 
	
	Elseif(Scaled)			//Image
	
		ImageRotate /q/s/z/a=(angle)/e=(NaN) Image
		Wave M_RotatedImage
		Duplicate /o M_RotatedImage RotatedImage 
		Killwaves/z M_RotatedImage 
	Else
		ImageRotate /z/a=(-angle)/e=(NaN) Image
		Wave M_RotatedImage
		Duplicate /o M_RotatedImage RotatedImage 
		Killwaves/z M_RotatedImage 
	Endif
	
Else
	Duplicate /o image RotatedImage
Endif

If(WinType("ToBeRotated")>0)
		DoWindow /k ToBeRotated
Endif

Display /n=ToBeRotated
Appendimage /w=ToBeRotated RotatedImage

SizeImage(300,WindowName="ToBeRotated")

if(WaveDims(Image)==3)
	WMAppend3DImageSlider();delayupdate
EndIf


End



////////////////////////////////Popup Control////////////////////////////////////////

Function RGPopUp(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
	DFREF WF=Root:Packages:RotateGUI, SaveDFR=GetDataFolderDFR()

NVAR  g_Matrix=WF:g_Matrix, g_rImage=WF:g_rImage, g_angle=WF:g_angle, g_warning=WF:g_warning,g_scaled=WF:g_Scaled
SVAR g_RotImg=WF:g_RotImg
	
//Print "CtrlName=", ctrlname	//Name of the PopMenu
//Print "PopNum=",popnum		
//print "PoPStr=",popstr			//Name of the Choice

	g_RotImg=popStr
	
	If(StringMatch(popStr,"!_none_"))
	
		ShowRot($g_RotImg,g_angle,g_matrix, g_scaled)
		
	Else
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
	Endif


End

////////////////////////////////CheckBox Control////////////////////////////////////////

Function RGCBC (ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selelcted, 0 if not
	
	DFREF WF=Root:Packages:RotateGUI, SaveDFR=GetDataFolderDFR()

NVAR  g_Matrix=WF:g_Matrix, g_rImage=WF:g_rImage, g_angle=WF:g_angle, g_warning=WF:g_warning,g_scaled=WF:g_Scaled
SVAR g_RotImg=WF:g_RotImg

	StrSwitch(ctrlName)
	
	Case "Matrix":
		g_matrix=1
		g_rImage=0
		CheckBox Scaled  disable=2
		
		If(StringMatch(g_RotImg,"!_none_"))
	
		ShowRot($g_RotImg,g_angle,g_matrix, g_scaled)
		
	Else
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
	Endif
	
	Break
	
	Case "Img":
		g_matrix=0
		g_rImage=1
		CheckBox Scaled  disable=0
		
		If(StringMatch(g_RotImg,"!_none_"))
	
		ShowRot($g_RotImg,g_angle,g_matrix, g_scaled)
		
	Else
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
	Endif
	
	Break
	
	Case "Scaled":
		g_scaled=checked
		
		If(StringMatch(g_RotImg,"!_none_"))
	
		ShowRot($g_RotImg,g_angle,g_matrix, g_scaled)
		
	Else
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
	Endif
	
	Break
	
	Default:
	
		Print "Undefined checkbox checked in RotateGIU.ipf: "+ctrlName
	
	Break
		
	EndSwitch


End

////////////////////////////////Variable Control////////////////////////////////////////


Function RGVC (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	DFREF WF=Root:Packages:RotateGUI, SaveDFR=GetDataFolderDFR()

NVAR  g_Matrix=WF:g_Matrix, g_rImage=WF:g_rImage, g_angle=WF:g_angle, g_warning=WF:g_warning,g_scaled=WF:g_Scaled
SVAR g_RotImg=WF:g_RotImg
	
	If(StringMatch(g_RotImg,"!_none_"))
	
		ShowRot($g_RotImg,g_angle,g_matrix, g_scaled)
		
	Else
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
	Endif
	
End


////////////////////////////////Button Control////////////////////////////////////////

Function RGBC (ctrlName) : ButtonControl
	String ctrlName
	
	DFREF WF=Root:Packages:RotateGUI, SaveDFR=GetDataFolderDFR()

NVAR  g_Matrix=WF:g_Matrix, g_rImage=WF:g_rImage, g_angle=WF:g_angle, g_warning=WF:g_warning,g_scaled=WF:g_Scaled
SVAR g_RotImg=WF:g_RotImg
	Wave /z RotatedImage
	
	Variable ObjectCount
	
	StrSwitch(ctrlName)
	
	Case "RGSaveButton":
	
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
		
		If(WaveExists(RotatedImage))
			
			Duplicate /o RotatedImage $(g_RotImg+"_"+num2str(g_angle))
			Display /k=1;AppendImage $(g_RotImg+"_"+num2str(g_angle))
			SizeImage(300)
			if(WaveDims($(g_RotImg+"_"+num2str(g_angle)))==3)
				WMAppend3DImageSlider();delayupdate
			EndIf
		Endif
		
	
		DoWindow /k RotationGUI
		KillDataFolder WF
		ObjectCount=CountObjects("root:packages",1)+CountObjects("root:packages",2)+CountObjects("root:packages",3)+CountObjects("root:packages",4)
			if(ObjectCount==0)
				KillDataFolder root:packages
			endif	
	
	Break
	
	Case "RGCancelButton":
	
	
		If(WinType("ToBeRotated")>0)
			DoWindow /k ToBeRotated
		Endif
		
		DoWindow /k RotationGUI
		KillDataFolder WF
		ObjectCount=CountObjects("root:packages",1)+CountObjects("root:packages",2)+CountObjects("root:packages",3)+CountObjects("root:packages",4)
			if(ObjectCount==0)
				KillDataFolder root:packages
			endif	
	
	Break
	
	
	Default:
		Print "Undefined button pressed in RotateGUI: "+ctrlName
	Break
	EndSwitch
	
End