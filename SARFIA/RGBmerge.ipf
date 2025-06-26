#pragma rtGlobals=1		// Use modern global access method.
#include "normalize"

/////////////////////////////////////////////////
//RGBMerge(Red,Green,Blue) needs already scaled (i.e. 16 bit) images

Function RGBMerge(Red,Green,Blue)
	Wave Red,Green,Blue
	
	Variable rx,ry,gx,gy,bx,by,rz,gz,bz
	
	rx=dimsize(Red,0)
	ry=dimsize(Red,1)
	rz=dimsize(Red,2)
	gx=dimsize(Green,0)
	gy=dimsize(Green,1)
	gz=dimsize(Green,2)
	bx=dimsize(Blue,0)
	by=dimsize(Blue,1)
	bz=dimsize(Blue,2)
	
	
	if((rx-gx)^2 || (rx-bx)^2 || (ry-by)^2 || (ry-gy)^2 || (rz-bz)^2 || (rz-gz)^2)
		DoAlert 0,"Dimension mismatch"
		Return -1
	endif
	
	//normalise channels to 16 bit
	wave rNorm=normalise(Red,0,65535)
	wave gNorm=normalise(Green,0,65535)
	wave bNorm=normalise(Blue,0,65535)
	
	if(rz>0)			//make 4D RGB
		
		redimension/n=(rx,ry,1,rz)/e=1 rNorm,gNorm,bNorm			
		concatenate/o/np=2 {rNorm,gNorm,bNorm}, M_RGBMerged
		setscale/p x,DimOffset(Red,0),Dimdelta(Red,0),WaveUnits(Red,0) M_RGBMerged
		setscale/p y,DimOffset(Red,1),Dimdelta(Red,1),WaveUnits(Red,1) M_RGBMerged
		setscale/p t,DimOffset(Red,2),Dimdelta(Red,2),WaveUnits(Red,2) M_RGBMerged
	
	else				//make 3D RGB
	
		Duplicate /o Red, M_RGBMerged
		redimension /n=(-1,-1,3)  M_RGBMerged
	
		multithread M_RGBMerged[][][0]=RNorm[p][q]
		multithread M_RGBMerged[][][1]=GNorm[p][q]
		multithread M_RGBMerged[][][2]=BNorm[p][q]
	
	endif

	KillWaves /z rNorm,gNorm,bNorm
End



///////////////////////////////////////////
// LookUp16bit(Image,From,To)


Function LookUp16bit(Image,[From,To])
Wave Image
Variable From, To

if(paramisdefault(from))
	from=0
endif
if(paramisdefault(to))
	imagestats /m=1 image
	to=v_max
endif

Duplicate /o Image, Image_LU

Image_LU-=From
Multithread Image_LU=SelectNumber(Image_LU[p][q]<0,Image_LU,0)
wavestats /q/m=1 Image_LU


Image_Lu *= (2^16-1)/To
Multithread Image_LU=SelectNumber(Image_LU[p][q]>2^16-1,Image_LU,2^16-1)

End


///////////////////////////////////////////

Function RGBmergePanel()
	string Information = IgorInfo(0), infolist, infolist2, infolist3
	variable screenright, screenbottom
	
	DFREF saveDFR = GetDataFolderDFR()		//save current data folder
	DFREF WF
	
	infolist = StringFromList(4,information,";")
	infolist2 = StringFromList(3,infolist,",")
	infolist3 = StringFromList(4,infolist,",")
	screenright = Str2Num(infolist2)
	screenbottom = Str2Num(infolist3)
	
	variable left=screenright - 700, top = 270
	If (WinType("RGBmergePanel"))
		doWindow /F RGBmergePanel
	else
//Data Folders///////////////////////////////////////////
		If(DataFolderRefStatus(root:Packages)!=1)
			NewDataFolder root:Packages
			NewDataFolder root:Packages:RGBMP
			SetDataFolder root:Packages:RGBMP
		ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:RGBMP)!=1)
			NewDataFolder root:Packages:RGBMP
		ElseIf( DataFolderRefStatus(root:Packages:RGBMP)==1)
			//
		Else
			DoAlert 0, "RGBMP_Initialise failed due to conflict with a free data folder."
			return -1
		EndIf
		WF=root:Packages:RGBMP
//Global Variables////////////////////////////////////////	
		SetDataFolder WF
		Variable /g g_RedMin=0, g_RedMax=2^16-1, g_BlueMin=0, g_BlueMax=2^16-1, g_GreenMin=0, g_GreenMax=2^16-1
		String/g g_RedName="_none_", g_BlueName="_none_", g_GreenName="_none_"
		
		
		SetDataFolder SaveDFR

//NVAR/SVAR////////////////////////////////////////////
		
		NVAR RedMin=WF:g_RedMin, RedMax=WF:g_RedMax, BlueMin=WF:g_BlueMin, BlueMax=WF:g_BlueMax, GreenMin=WF:g_GreenMin, GreenMax=WF:g_GreenMax
		SVAR RedName=WF:g_RedName, BlueName=WF:g_BlueName, GreenName=WF:g_GreenName
//GUI//////////////////////////////////////////////////		
	
		NewPanel /K=1 /N=RGBmergePanel /W = (left,top,left+600, top+350) as "Merge RGB"
		Groupbox GBx1 pos={5,5}, size={590,340}
		
		Popupmenu RedWaves, pos={180,20},bodywidth=180,mode=1,proc = RGBPopProc, title="Red",popvalue="Select Red Image", value=WaveList("*",";","TEXT:0,DIMS:2")+"_none_"
		Popupmenu GreenWaves, pos={180,60},bodywidth=180,mode=1,proc = RGBPopProc, title="Green",popvalue="Select Green Image", value=WaveList("*",";","TEXT:0,DIMS:2")+"_none_"
		Popupmenu BlueWaves, pos={180,100},bodywidth=180,mode=1,proc = RGBPopProc, title="Blue",popvalue="Select Blue Image", value=WaveList("*",";","TEXT:0,DIMS:2")+"_none_"
	
	
		Slider RMinSlide, pos={250, 20}, size={300,30},vert=0,variable=RedMin, limits={0,2^16-1,1}, thumbcolor=(65535,0,0), ticks=0, help={"Red Minimum"}, proc=RGBSliderProc
		Slider RMaxSlide, pos={250, 60}, size={300,30},vert=0,variable=RedMax, limits={0,2^16-1,1}, thumbcolor=(65535,0,0), ticks=0, help={"Red Minimum"}, proc=RGBSliderProc
		Slider GMinSlide, pos={250, 110}, size={300,30},vert=0,variable=GreenMin, limits={0,2^16-1,1}, thumbcolor=(0,65535,0), ticks=0, help={"Red Minimum"}, proc=RGBSliderProc
		Slider GMaxSlide, pos={250, 150}, size={300,30},vert=0,variable=GreenMax, limits={0,2^16-1,1}, thumbcolor=(0,65535,0), ticks=0, help={"Red Minimum"}, proc=RGBSliderProc
		Slider BMinSlide, pos={250, 200}, size={300,30},vert=0,variable=BlueMin, limits={0,2^16-1,1}, thumbcolor=(0,0,65535), ticks=0, help={"Red Minimum"}, proc=RGBSliderProc
		Slider BMaxSlide, pos={250, 240}, size={300,30},vert=0,variable=BlueMax, limits={0,2^16-1,1}, thumbcolor=(0,0,65535), ticks=0, help={"Red Minimum"}, proc=RGBSliderProc
	
		
	
	endif


End

////////////////////////

Function RGBPopProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
	DFREF WF=root:Packages:RGBMP
	
	NVAR RedMin=WF:g_RedMin, RedMax=WF:g_RedMax, BlueMin=WF:g_BlueMin, BlueMax=WF:g_BlueMax, GreenMin=WF:g_GreenMin, GreenMax=WF:g_GreenMax
	SVAR RedName=WF:g_RedName, BlueName=WF:g_BlueName, GreenName=WF:g_GreenName
	
End

////////////////////////////

Function RGBSliderProc(name, value, event) : SliderControl
	String name	// name of this slider control
	Variable value	// value of slider
	Variable event	// bit field: bit 0: value set; 1: mouse down, 
					//   2: mouse up, 3: mouse moved
					
					
	DFREF WF=root:Packages:RGBMP	
	NVAR RedMin=WF:g_RedMin, RedMax=WF:g_RedMax, BlueMin=WF:g_BlueMin, BlueMax=WF:g_BlueMax, GreenMin=WF:g_GreenMin, GreenMax=WF:g_GreenMax			
	
	
	StrSwitch(Name)
		Case "RMinSlide":
			RedMax=Max(RedMin,RedMax)
		Break
		
		Case "RMaxSlide":
			RedMin=Min(RedMin, RedMax)
		Break
		
		Case "GMinSlide":
			GreenMax=Max(GreenMin,GreenMax)
		Break
		
		Case "GMaxSlide":
			GreenMin=Min(GreenMin,GreenMax)
		Break
		
		Case "BMinSlide":
			BlueMax=Max(BlueMin,BlueMax)
		Break
		
		Case "BMaxSlide":
			BlueMin=Min(BlueMin,BlueMax)
		Break
			
		Default:
			Print Name
		Break
		
		
	EndSwitch
		
		if(event & 4)		//button released
			print name, value
		endif			
							
	return 0	// other return values reserved
End



Static Function RGBImageUpDate()
	DFREF WF=root:Packages:RGBMP
	
	NVAR RedMin=WF:g_RedMin, RedMax=WF:g_RedMax, BlueMin=WF:g_BlueMin, BlueMax=WF:g_BlueMax, GreenMin=WF:g_GreenMin, GreenMax=WF:g_GreenMax
	SVAR RedName=WF:g_RedName, BlueName=WF:g_BlueName, GreenName=WF:g_GreenName

	Wave Red=$RedName,Green=$GreenName,Blue=$BlueName
	
	Variable rx,ry,gx,gy,bx,by
	
	rx=dimsize(Red,0)
	ry=dimsize(Red,1)
	gx=dimsize(Green,0)
	gy=dimsize(Green,1)
	bx=dimsize(Blue,0)
	by=dimsize(Blue,1)
	
	if((rx-gx)^2 || (rx-bx)^2 || (ry-by)^2 || (ry-gy)^2)
		DoAlert 0,"Dimension mismatch"
		Return -1
	endif
	
	Duplicate /o Red, M_RGBMerged
	redimension /n=(-1,-1,3)  M_RGBMerged
	
	wave rNorm=normalise(Red,0,65535)
	wave gNorm=normalise(Green,0,65535)
	wave bNorm=normalise(Blue,0,65535)
	
	MultiThread rNorm=SelectNumber(rnorm[p][q]>RedMax,rNorm[p][q],RedMax)
	MultiThread rNorm=SelectNumber(rnorm[p][q]<RedMin,rNorm[p][q],RedMin)
	MultiThread gNorm=SelectNumber(gnorm[p][q]>GreenMax,rNorm[p][q],GreenMax)
	MultiThread gNorm=SelectNumber(gnorm[p][q]<GreenMin,rNorm[p][q],GreenMin)
	MultiThread bNorm=SelectNumber(bnorm[p][q]>BlueMax,rNorm[p][q],BlueMax)
	MultiThread bNorm=SelectNumber(bnorm[p][q]<BlueMin,rNorm[p][q],BlueMin)
	
	
	M_RGBMerged[][][0]=RNorm[p][q]
	M_RGBMerged[][][1]=GNorm[p][q]
	M_RGBMerged[][][2]=BNorm[p][q]

	KillWaves /z rNorm,BNorm,GNorm



End