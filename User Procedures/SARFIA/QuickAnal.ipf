#pragma rtGlobals=1		// Use modern global access method.
#include "z-project"
#include "normalize"
#include "multiroi"
#include "ManThresh"
#include "ImGAnalCP"
#include "Customcolor"
#include "populationwave"
#include "RegisterStack"
#include "LoadScanImage"


//////////////////////////Quick Analysis/////////////////////////////////
Function QuickAnalysis(ImageStack)
wave ImageStack
variable xdim, ydim, roinumber, counter = 0

DFREF WF = root:Packages:IACP

NVAR  g_ThresholdLevelNumber=WF:g_ThresholdLevelNumber, g_AutoLayout=WF:g_AutoLayout, g_deltafbyf=WF:g_deltafbyf,BGSubtract=WF:g_BGSubtract
NVAR  g_AutoName=WF:g_AutoName, g_HeaderInfo=WF:g_HeaderInfo, g_Registration=WF:g_Registration, g_Axes=WF:g_Axes, g_DeltaFByF0=WF:g_DeltaFByF0

string targetname
SVAR  g_QAStatus=WF:g_QAStatus,g_NameOfROIWave=WF:g_NameOfROIWave, g_QAMethodType=WF:g_QAMethodType //"Average;SD;Raw Image"
SVAR g_NameOf3DWave=WF:g_NameOf3DWave

g_QAStatus = "Starting" 
DoUpdate; DoUpdate

if (g_AutoName)
targetname = NameOfWave(ImageStack)+"_"+g_QAMethodType[0,2]+"_QA"

else
	prompt targetname, "Enter name for target wave"
					doprompt "Graph wave", targetname
					if (V_Flag)
						g_QAStatus = "Cancelled" 
						DoUpdate
						return -1
					endif
endif

///////////////////Image Registration
if (g_Registration)
	g_QAStatus = "Image Registration"
	DoUpdate
	DoUpdate
	RegisterStack(ImageStack)
	duplicate /o ImageStack, $(nameofwave(ImageStack)+"_unreg")
	duplicate /o $(nameofwave(ImageStack)+"_reg"), $(nameofwave(ImageStack))

endif

strswitch(g_NameOfROIWave)
case "Automatic":



	if (waveexists(:MTROIWave) && (dimsize(:MTROIWave, 0) == dimsize(Imagestack, 0)) && (dimsize(:MTROIWave, 1) == dimsize(Imagestack, 1)))
		Wave MTROIWave
		duplicate /o MTROIWave QA_ROIMask
		g_QAStatus = "Using saved ROI"
		//print "Using saved ROI"						//debug only
		DoUpdate
		DoUpdate
	else
		
		
		strswitch(g_QAMethodType) //Average;SD;Raw Image
			Case "Average":
				g_QAStatus = "Calculating average"
				DoUpdate
				DoUpdate
				avgZ(ImageStack, "Threshold_Base")
			break
			
			Case "SD":
				g_QAStatus = "Calculating SD"
				DoUpdate
				DoUpdate
				stdevZ(ImageStack, "Threshold_Base")
			break
			
			Case "Raw Image":
				xdim = dimsize(ImageStack, 0)
				ydim = dimsize(ImageStack, 1)
				Duplicate /o ImageStack, Threshold_Base  
				Redimension /N=(xdim,ydim) Threshold_Base 
			break
			
			default:
				Print "Default Case, using Average"
				g_QAStatus = "Calculating average"
				DoUpdate
				DoUpdate
				avgZ(ImageStack, "Threshold_Base")
				break
		endswitch
	
		wave Threshold_Base
		g_QAStatus = "Thresholding"
		DoUpdate
		//M_Threshold(Threshold_Base, "Thresholded_Wave", g_ThresholdLevelNumber)
		
		 dif_image(Threshold_Base, targetname="DI_calcwave")		//was picwave
 		wave DI_calcwave
 
		 imagestats DI_calcwave
		variable startlevels =g_ThresholdLevelNumber* v_sdev //scale for SD
 
 		mod_img(DI_calcwave, startlevels, targetname="ROI_calcwave")
 		wave ROI_calcwave
 

 
		 multiroi(ROI_Calcwave, "ROI_calcwave")
		
		duplicate /o ROI_calcwave M_ROIMask
		killwaves /z DI_calcwave, ROI_calcwave
		
	
	endif	//waveexists...
break

default:	//g_NameOfROIWave


	if ((dimsize($g_NameOfROIWave, 0) == dimsize(Imagestack, 0)) & (dimsize($g_NameOfROIWave, 1) == dimsize(Imagestack, 1)))
	duplicate /o $g_NameOfROIWave, QA_ROIMask
		g_QAStatus = "Using "+ g_NameOfROIWave
		DoUpdate
		DoUpdate
		avgZ(ImageStack, "Threshold_Base")
		g_QAStatus = "Generating overlay"
		DoUpdate
		DoUpdate
	elseif (waveexists($g_NameOfROIWave))
	string err =  g_NameOfROIWave+" does not match "+nameofwave(imagestack)
	DoAlert 0, err
	return -1
		DoUpdate
		DoUpdate
	else
	DoAlert 0, "Something gone horribly wrong (QuickAnal)..."

	endif
break
endswitch



/////////////////////////BG Corr/////////////

String F0WaveName =NameOfWave(ImageStack)+"_FBG"


if (BGSubtract)		// ||1 --> always do bg corr!

	
	
	string tempwavename = nameofwave($g_NameOf3DWave)+"_THR" 
	
	
	if (!WaveExists($(NameofWave(ImageStack)+"_BGN")))
		if (waveexists($tempwavename))	
			Display /n=ManualROI /hide = 0;  appendimage $tempwavename
			modifygraph height = 300, width = 300
		elseif(waveexists(threshold_base))
		wave threshold_base
			Display /n=ManualROI /hide = 0; 
			appendimage threshold_base
			modifygraph height = 300, width = 300
			DoUpdate
		else
			Display /n=ManualROI /hide = 0; 
			appendimage Imagestack
			modifygraph height = 300, width = 300
			DoUpdate		
		endif
	
		WMCreateImageROIPanel();
		g_QAStatus = "Select Background & Kill ROI Window"
			DoUpdate
		PauseForUser WMImageROIPanel, $S_Name	
		wave /Z M_ROIMask
		
		if (!(waveexists(M_ROIMask)))
			g_QAStatus = "User Abort?"
			DoUpdate
			return -1
		endif
		
		string bgwavename = nameofwave($g_NameOf3DWave)+"_BGROI"
		duplicate /o m_roimask, $bgwavename 
		
//		if(waveexists (M_ROIMask))
//			duplicate /o M_ROIMask, M_BGMask
//			duplicate /o M_ROIMask2, M_ROIMask
//		endif
		
		if (wintype("IAControlPanel"))
			doWindow /F IAControlPanel
		endif
		if (wintype("ManualROI"))
			doWindow /k ManualROI
		endif
	endif
	
	
	if (WaveExists($(NameofWave(ImageStack)+"_BGN")))
		g_QAStatus = "Using <"+NameOfWave(ImageStack)+"_BGN>"
		doupdate; doupdate
	else
	g_QAStatus = "Removing Background"
	doupdate; doupdate
		//NormBG(ImageStack, NameOfWave(ImageStack)+"_BGN", $bgwavename)
		SubstBG(ImageStack, NameOfWave(ImageStack)+"_BGN", $bgwavename, F0Wave=F0WaveName)
		
	endif
	killwaves/z M_BGMask, m_roimask2
	


endif



imagestats /M=1 QA_ROIMask
if (v_min >= 0)
	MultiROI(QA_ROIMask, "QA_ROIMask")
endif

///////////////////stacking

doWindow /F IAControlPanel
g_QAStatus = "Generating Z stacks"
DoUpdate
DoUpdate


if (g_deltaFbyF && BGSubtract)
	roinumber = MultiROIZstack($NameOfWave(ImageStack)+"_BGN", targetname,QA_ROImask)

	
	elseif(g_deltaFByF)
		roinumber = MultiROIZstack($NameOfWave(ImageStack), targetname,QA_ROImask)
		
	else
	
	roinumber = MultiROIZstack(Imagestack, targetname,QA_ROIMask)
	
endif

duplicate/o QA_ROIMask, $targetname+"_ROI"
NaNBust($targetname)
normalizepop($targetname,targetname+"_Nor")

NaNBust($(targetname+"_Nor"))

/////////////////////////Auto Layout
variable counter2 = 6 //graphs/layout
if (g_AutoLayout)
	g_QAStatus = "Auto Layout"
	DoUpdate
	string Layoutname, expdate, age = "", construct = "", filename , settings = "", notes = "", graphname, name2, mtName
	SVAR  g_NameOf3DWave=WF:g_NameOf3DWave
	string tempwavename2 = nameofwave($g_NameOf3DWave)+"_THR" 
	variable zoom=0, x_res = 0, y_res, z_res, timeperline, layoutnumber = 1, xrel,yrel,zrel, headerexists
	
	
	
	string colorwavename = nameofwave(imagestack)+"_colorLUT"
	RainbowLUT(roinumber+1,colorwavename)
	
	
	duplicate /o $colorwavename, tempcolorwave
	setscale /P x,0,-1,"" $colorwavename
	

	
	

		zoom = ZoomFromHeader(ImageStack)
		x_res = ImageLength / zoom / dimsize(ImageStack,0)			//µm
		y_res=  ImageLength / zoom / dimsize(ImageStack,1)			//µm
		// z_res =  sPerLineFromHeader(ImageStack)* dimsize(ImageStack,1) //msec 2 sec
		z_res = dimdelta(imagestack, 2)		//<-------------------------------------------
		timeperline = msPerLineFromHeader(ImageStack)					//ms
		

		expdate = ExpDateFromHeader(ImageStack)
		filename =FilenameFromHeader(ImageStack)
		Xrel=XRelFromHeader(ImageStack)
		Yrel=YRelFromHeader(ImageStack)
		Zrel=ZRelFromHeader(ImageStack)
		
		if (zoom)
		headerexists = 1
		else
		headerexists = 0
		endif
	
	
	/////
	
	counter = 0
	
	layoutname = targetname+"_Layout"
	
	variable lcounter = 0
	do
		if (wintype(layoutname))
		layoutname = targetname+"_"+num2str(lcounter)+"_Layout"
		lcounter +=1
		else
		lcounter = 1001
		endif
	while (lcounter < 1000)
	
	
	NewLayout /k=0 /p=landscape /n=$layoutname	//S_name = name

	
	
	
	
	
	if (waveexists($tempwavename2))
		if (headerexists &  g_HeaderInfo)
			setscale /p x 0,x_res,"µm", $tempwavename2; delayupdate
			setscale /p y 0,y_res,"µm", $tempwavename2; delayupdate
			setscale /p x 0,x_res,"µm", $targetname+"_ROI"; delayupdate
			setscale /p y 0,y_res,"µm", $targetname+"_ROI"; delayupdate
		endif
		Display /k=0/hide = 1; 
		name2=s_name
		appendimage $tempwavename2; delayupdate
		appendimage $targetname+"_ROI"; delayupdate	//S_name = name
		ModifyImage $targetname+"_ROI" minRGB=0,maxRGB=NaN; delayupdate
		ModifyImage $targetname+"_ROI" cindex=$colorwavename; delayupdate	//ctab= {*,0,Rainbow,0}
		TextBox /W=$s_name /A=MT "ROIs"; delayupdate
		ModifyGraph height = 250, width = 250; delayupdate
		ModifyGraph tick=0,standoff=0; delayupdate
		drawroinumbers($targetname+"_ROI", name2)	; delayupdate					//<-----------------------
		AppendLayoutObject /W=$layoutname graph $s_name; delayupdate
	
	elseif (waveexists(threshold_base))
		if (headerexists &  g_HeaderInfo)
			setscale /p x 0,x_res,"µm", threshold_base; delayupdate
			setscale /p y 0,y_res,"µm", threshold_base; delayupdate
			setscale /p x 0,x_res,"µm", $targetname+"_ROI"; delayupdate
			setscale /p y 0,y_res,"µm", $targetname+"_ROI"; delayupdate
		endif
		Display /k=0 /hide = 1; ; delayupdate
		name2=s_name
		appendimage threshold_base; delayupdate
		appendimage $targetname+"_ROI"; delayupdate	//S_name = name
		ModifyImage $targetname+"_ROI" minRGB=0,maxRGB=NaN; delayupdate
		ModifyImage $targetname+"_ROI" cindex=$colorwavename; delayupdate	//ctab= {*,0,Rainbow,0}
		TextBox /W=$s_name /A=MT "ROIs"; delayupdate
		ModifyGraph height = 250, width = 250; delayupdate
		ModifyGraph tick=0,standoff=0; delayupdate
		drawroinumbers($targetname+"_ROI", name2)		; delayupdate				//<----------------------
		AppendLayoutObject /W=$layoutname graph $s_name; delayupdate
		
	else
		print "No image for overlaying ROI (Auto Layout)"
	endif
	
	
	string popresult
	
	if(g_deltafbyf0)
		popresult=targetname+"_norF0"
	elseif(g_deltafbyf)
		popresult=targetname+"_nor"
	else
		popresult = targetname
	endif

	variable axismin, axismax
	imagestats /M=1 $popresult
	axismin = v_min
	axismax = v_max

	setscale /p y,0,1,"ROI #", $popresult; delayupdate
	if (headerexists)
		setscale /p x,0,z_res,"s", $popresult; delayupdate
	endif
	Display /k=0/hide = 1; delayupdate
	appendimage $popresult; delayupdate
	ColorScale/C/N=text3/A=RC /E lblRot=180;DelayUpdate
	
	if(g_deltafbyf0)
		ColorScale/C/N=text3 "ÆF/F\\B0"; delayupdate
	elseif(g_deltafbyf)
		ColorScale/C/N=text3 "ÆF/F"; delayupdate
	else
		ColorScale/C/N=text3 "Fluorescence (A.U.)"; delayupdate
	endif
	setaxis /w=$s_name /A/R left ; delayupdate
	AppendLayoutObject /W=$layoutname graph $s_name; delayupdate
	
	
	
	Do
		if (headerexists & g_HeaderInfo)
			setscale /p x,0,z_res,"s", $targetname+"_"+num2str(counter); delayupdate
		endif
		
		
		//-.-.-.-.-.		Add stimulus waves
		if(waveexists(:stim))
			Wave stim
			display /k=0/hide = 1 /r stim[][0];delayupdate
			appendtograph /r stim[][1];delayupdate
			//Label right "Light intensity\rW/m\S2";delayupdate
			Label right "Light intensity [AU]";delayupdate
			ModifyGraph lsize=3,rgb(stim)=(65535,43690,0),rgb(stim#1)=(0,0,65535);delayupdate
			ModifyGraph lstyle(stim#1)=1;delayupdate
			ModifyGraph mode=6;delayupdate
			ModifyGraph log(right)=1;delayupdate
			MatrixOP/o/free Pw2No0 = Replace(stim,0,NaN)
			SetAxis right (wavemin(PW2No0)/3),*;delayupdate
			
			
			appendtograph $popresult[][counter];delayupdate
			if (g_axes)
				SetAxis left axismin, axismax; delayupdate		//equalize axes
			endif
			ModifyGraph rgb($popresult) =(0,0,0); delayupdate
			graphname = s_name
			mtName = targetname+"_"+num2str(counter)

		
		elseif(waveexists(:train))
			Wave train
			display /k=0/hide = 1 /r train[][0]; delayupdate 
			appendtograph /r train[][1];delayupdate
			Label right "Light intensity\rW/m\S2";delayupdate
			ModifyGraph lsize=1,rgb(train)=(65535,43690,0),rgb(train#1)=(0,0,65535);delayupdate
			ModifyGraph lstyle(train#1)=1;delayupdate
			ModifyGraph mode=6;delayupdate
			ModifyGraph log(right)=1;delayupdate
			MatrixOP/o/free Pw2No0 = Replace(train,0,NaN)
			SetAxis right (wavemin(Pw2No0)/3),*;delayupdate
			
			appendtograph $popresult[][counter];delayupdate
			if (g_axes)
				SetAxis left axismin, axismax;delayupdate		//equalize axes
			endif
			ModifyGraph rgb($popresult) =(0,0,0); delayupdate
			graphname = s_name
			mtName = targetname+"_"+num2str(counter)


		
		else //-.-.-.-.-.-.-.-.-.-
		
			Display /k=0/hide = 1 $popresult[][counter];delayupdate	//S_name = name
			if (g_axes)
				SetAxis left axismin, axismax;delayupdate		//equalize axes
			endif
			ModifyGraph rgb =(0,0,0); delayupdate
			graphname = s_name
			mtName = targetname+"_"+num2str(counter)
			//ModTrace($mtname, s_name)					//do some modification
			
		endif
		
		if(g_deltafbyf0)
			if((axismax >=1) && (axismin <= 0))
				ModifyGraph noLabel(left)=2,axThick(left)=0,standoff(left)=0;DelayUpdate
				SetDrawEnv xcoord= rel,ycoord= left,linethick= 2.00;DelayUpdate
				DrawLine 0.1,0,0.1,1;DelayUpdate
				SetDrawEnv xcoord= rel,ycoord= left,textxjust= 1,textyjust= 1,textrot= 90;DelayUpdate
				DrawText 0.07,0.5,"1 ÆF/F\\B0";DelayUpdate
			else	
				Label left "ÆF/F\\B0"; delayupdate
			endif
		
		elseif(g_deltafbyf)
			if((axismax >=1) && (axismin <= 0))
				ModifyGraph noLabel(left)=2,axThick(left)=0,standoff(left)=0;DelayUpdate
				SetDrawEnv xcoord= rel,ycoord= left,linethick= 2.00;DelayUpdate
				DrawLine 0.1,0,0.1,1;DelayUpdate
				SetDrawEnv xcoord= rel,ycoord= left,textxjust= 1,textyjust= 1,textrot= 90;DelayUpdate
				DrawText 0.07,0.5,"1 ÆF/F";DelayUpdate
			else	
				Label left "ÆF/F"; delayupdate
			endif
		else
			label left "Fluorescence (A.U.)"; delayupdate
		endif
		
		
		TextBox /W=$graphname /A=RT  /b=(tempcolorwave[counter+1][0],tempcolorwave[counter+1][1],tempcolorwave[counter+1][2]) "ROI #"+num2str(counter); delayupdate
		
		
		
		if (mod(counter2, 6) > 0) //graphs/layout
			AppendLayoutObject /W=$layoutname graph $graphname;delayupdate
		elseif (mod(counter2, 6) == 0) //graphs/layout
			DoWindow /F $layoutname;delayupdate
			Execute /Q/Z "Tile /A=(3,2)" ;delayupdate //graphs/layout
			dowindow /hide=1 $layoutname; delayupdate
			NewLayout  /k=0/p=landscape /n=$targetname+"_Layout"+num2str(layoutnumber);delayupdate	//S_name = name
			layoutname = s_name
			AppendLayoutObject /W=$layoutname graph $graphname;delayupdate
			layoutnumber +=1
		else
		print "This shouldn't happen (Auto Layout / naming)"
		doupdate
		endif
		
		
	
		counter2 +=1
		
		counter +=1
	while (counter < roinumber)
	
	DoWindow /F $layoutname; delayupdate
	Execute /Q/Z "Tile /A=(3,2)" ; delayupdate //graphs/layout
	dowindow /hide=1 $layoutname; delayupdate
	doupdate
	
	//------------------------Notebook-----------------------
	string notebookname
	variable theendisnigh = 0
		counter = 0
		do
			if (!(counter))
				notebookname = "Summary_"+nameofwave(imagestack)
			else
				notebookname = "Summary_"+nameofwave(imagestack)+num2str(counter)
			endif
			
			if (wintype(notebookname))
				counter +=1
			else
				theendisnigh = 1
			endif
		
		while (!(theendisnigh))
	

	NewNotebook /f=1 /n=$(notebookname) as nameofwave(imagestack)+"_summary"; delayupdate
	Notebook $(notebookname), fsize = 11, fstyle = 0, textrgb=(65535,65535,65535), magnification=2; delayupdate
	
	Notebook $(notebookname), text="Summary of: "; delayupdate
	Notebook $(notebookname), fsize = 11, fstyle = 1, textrgb=(65535,65535,65535); delayupdate
	Notebook $(notebookname), text=nameofwave(imagestack)+"\r", fstyle=1; delayupdate
	Notebook $(notebookname), fsize = 11, fstyle = 0, textrgb=(65535,65535,65535); delayupdate
	Notebook $(notebookname), text="Date: "+expdate	+"\r"; delayupdate
	Notebook $(notebookname), text="Filename: "+filename	+"\r"; delayupdate
	
	Notebook $(notebookname), text="Threshold level: "+Num2Str(g_ThresholdlevelNumber)	+"\r"; delayupdate
	Notebook $(notebookname), text="Thresholding method: "+g_QAMethodType	+"\r"; delayupdate
	Notebook $(notebookname), text="ÆF/F: "+Num2Str(g_DeltaFByF)+"\r"; delayupdate
	Notebook $(notebookname), text="BG Subtraction: "+Num2Str(BGSubtract)	+"\r"; delayupdate
	

	
	
	if (headerexists)		//read Header Info
		//	Notebook $(notebookname), text=+"\r"			//<---- for copy/paste

		Notebook $(notebookname), text="Zoom: \t"+num2str(zoom)+"\r"
		
		if (x_res >= 1)
			Notebook $(notebookname), text="X resolution: "+num2str(x_res)+" µm per pixel"+"\r"; delayupdate
		else
			Notebook $(notebookname), text="X resolution: "+num2str(x_res*1000)+" nm per pixel"+"\r"; delayupdate
		endif
		if (y_res>1)
			Notebook $(notebookname), text="Y resolution: "+num2str(y_res)+" µm per pixel"+"\r"; delayupdate
		else
			Notebook $(notebookname), text="Y resolution: "+num2str(y_res*1000)+" nm per pixel"+"\r"; delayupdate
		endif
		
		Notebook $(notebookname), text=num2str(timeperline)+" ms per line"+"\r"; delayupdate
		Notebook $(notebookname), text="Framerate: "+num2str(1/z_res)+" Hz"+"\r"; delayupdate
		//Notebook $(notebookname), text="1 frame every "+num2str(1000*z_res)+" ms"	+"\r"; delayupdate
		Notebook $(notebookname), text="Rel. Stage position: X="+num2str(Xrel)+", Y="+num2str(Yrel)+", Z="+num2str(Zrel)+"\r"; delayupdate
		Notebook $(notebookname), text="Age of test subject: "+age	+"\r"; delayupdate
		Notebook $(notebookname), text="Construct: "+construct	+"\r"; delayupdate
		Notebook $(notebookname), text="Settings: "+settings	+"\r"; delayupdate
		Notebook $(notebookname), text="Notes: "	+notes+"\r"; delayupdate
	endif
	
	
	counter = 1
	Notebook $(notebookname), text= "---------------------------------------------------------------------------------------------------------\r"; delayupdate
	Notebook $(notebookname), text= "\r"	; delayupdate
	Notebook $(notebookname), scaling = {58,60}, picture={$targetname+"_Layout", 1,1}; delayupdate
	//dowindow /hide=1 $targetname+"_Layout"
	do
		
			
		Notebook $(notebookname), scaling={58,60}, picture={$targetname+"_Layout"+num2str(counter), 1,1}; delayupdate
		
		//dowindow /hide = 1 $targetname+"_Layout"+num2str(counter)
		counter +=1
	while (counter < layoutnumber) 
	
	
	
	
	
	
endif


g_QAStatus = "Finished. Generated "+Num2Str(roinumber)+" Traces"
killwaves /z Threshold_Base, Thresholded_Wave, M_ROIMask, headcalcwave, stringheadwave, tempcolorwave, m_colors, QA_ROIMask
doupdate
return roinumber

end


//////////////////////////////////////////////////////////////

function DrawROINumbers(roiwave, windowname,[fontsize])
wave roiwave
string windowname
variable fontsize

variable xdim, ydim, xcount = 0, ycount = 0, minval, maxval

if (paramisdefault(fontsize))
	fontsize = 10
endif

xdim = dimsize(roiwave, 0)
ydim = dimsize(roiwave, 1)



minval = roiwave[0][0]
maxval = roiwave[0][0]

//getting min/max values

do
	ycount = 0
	do
	if (roiwave[xcount][ycount] < minval)
		minval = roiwave[xcount][ycount]
	elseif (roiwave[xcount][ycount] > maxval)
		maxval = roiwave[xcount][ycount]
	endif
	ycount +=1
	while (ycount < ydim)
xcount +=1
while (xcount < xdim)


variable roinumber = -minval
if (roinumber == 0)
	return -1
endif

make /o /c /n=(roinumber) roistartwave = -1

ycount = 0
do
	xcount = 0
	do
	
		if((roiwave[xcount][ycount] < 0))// & (roistartwave[(roiwave[xcount][ycount])] != -1))
			roistartwave[-(roiwave[xcount][ycount])-1] = cmplx(xcount,ycount)
		endif
	
	xcount +=1
	while (xcount < xdim)
ycount +=1
while (ycount < ydim)

variable counter = 0, xpos, ypos


for (counter=0;counter<roinumber;counter+=1)
	xpos = real(roistartwave[counter]) / xdim
	ypos = 1-imag(roistartwave[counter]) / ydim			//remove '1-' for reverse y axis
	
	
	setdrawEnv /w=$windowname textRGB=(65535,0,0), fstyle = 0, fsize = fontsize, fname="Helvetica"
	
	drawtext /w=$windowname xpos,ypos, num2str(counter)

endfor


killwaves /z roistartwave

end






end