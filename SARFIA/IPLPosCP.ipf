#pragma rtGlobals=1		// Use modern global access method.
#include "IPLPOsition"
#include "CenterOfMass_custom"
#include "SaveTiff"
//	Popupmenu Waves_list2D,  pos={260,row2 + 80},bodywidth=180,proc = PopProc,mode=1, title="Image",popvalue="Select Image Wave", value=WaveList("*",";","TEXT:0,DIMS:2")


Function IPLPosCP()

DFREF saveDFR = GetDataFolderDFR()		//save current data folder

variable screenright, screenbottom

variable halfheight = 165, halfwidth = 330
variable left, top 

GetWindow kwFrameInner wsize
	
	screenright = V_Right
	screenbottom = V_Bottom
	top=V_Top
	left=screenright-2*halfwidth

If (WinType("IPLPosPanel"))
	doWindow /F IPLPosPanel
else

	If(DataFolderRefStatus(root:Packages)!=1)
		NewDataFolder root:Packages
		NewDataFolder root:Packages:IPLPosCP
		SetDataFolder root:Packages:IPLPosCP
	ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:IPLPosCP)!=1)
		NewDataFolder root:Packages:IPLPosCP
	ElseIf( DataFolderRefStatus(root:Packages:IPLPosCP)==1)
		//
	Else
		DoAlert 0, "IPLPosCP_Initialise failed due to conflict with a free data folder."
		return -1
	EndIf
	
	SetDataFolder root:Packages:IPLPosCP
	string /g g_image="_none_", g_CoM, g_TopY, g_TopX, g_BottomY, g_BottomX, g_ROI="_none_"
	variable /g g_red, g_cyan, g_yellow, g_method = 7, g_thr, g_DoLoess=1
	SetDataFolder saveDFR

	



	NewPanel /K=2 /N=IPLPosPanel /W = (left,top,screenright, top+2*halfheight) as "IPL Measurement Panel"
	Groupbox GBx1 pos={5,5}, size={320,280}
	PopupMenu ImageSelect, pos={195,15}, bodywidth=200, proc=IPLPosPopups, mode=1, title="Image", popvalue="Select an Image", value=WaveList("*",";","TEXT:0,DIMS:2")+";_none_"
	PopupMenu ROISelect, pos={195,45}, bodywidth=200, proc=IPLPosPopups, mode=1, title="ROI", popvalue="Select an ROI wave", value=WaveList("*ROI*",";","TEXT:0,DIMS:2")+";_none_"
	PopupMenu ThrMethod, pos ={145,75}, bodywidth=150, proc=IPLPosPopups, mode=1, title="Method", popvalue="Manual Drawing", value="Iterative;Bimodal;Adaptive;Fuzzy Entropy;Fuzzy Mean Gray;Manual Threshold;Manual Drawing", disable = 2 
	Button IPLDoIt, pos={50,105},size={100,20}, proc=IPLPosBC, title="Start", disable=2
	CheckBox LoessSmooth, pos={215,107.5}, noproc, title="Smoothing" , variable=g_DoLoess
	Display /Host=IPLPosPanel /n=OverView /w=(340,15,640,315)
	PopUpMenu Red, pos={195,135},  bodywidth=200, proc=IPLPosPopups, mode=1, title="Red", popvalue="Select an action", value="Top (PR);Bottom (GC);Reject", disable = 2
	PopUpMenu Cyan, pos={195,165},  bodywidth=200, proc=IPLPosPopups, mode=1, title="Cyan", popvalue="Select an action", value="Top (PR);Bottom (GC);Reject", disable = 2
	PopUpMenu Yellow, pos={195,195},  bodywidth=200, proc=IPLPosPopups, mode=1, title="Yellow", popvalue="Select an action", value="Top (PR);Bottom (GC);Reject", disable = 2
	Button IPLContinue, pos={50,225},size={100,20}, proc=IPLPosBC, title="Continue", disable=2
	Button IPLSave, pos={150,2*halfheight-25},size={100,20}, proc=IPLPosBC, title="Leave a mess!"
	Button IPLQuit, pos={25,2*halfheight-25},size={100,20}, proc=IPLPosBC, title="Clean up!"
	Button IPLResults, pos={50,255},size={100,20}, proc=IPLPosBC, title="Show Results", disable=2
	Setvariable ThrLevel, pos={270,75}, bodywidth = 60, noproc, limits={-inf, inf, .5}, Title="Threshold", variable = g_thr, disable=2

endif






end

//////////////////////PopupControl///////////////////////////

Function IPLPosPopups(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	DFREF WF = root:Packages:IPLPosCP
	
SVAR g_image=WF:g_Image, g_CoM=WF:g_CoM, g_TopY=WF:g_Topy, g_TopX=WF:g_TopX, g_BottomY=WF:g_BottomY, g_BottomX=WF:g_BottomX, g_ROI=WF:g_ROI
NVAR g_red=WF:g_red, g_cyan=WF:g_cyan, g_yellow=WF:g_yellow, g_method=WF:g_method, g_thr=WF:g_thr

	
	StrSwitch (ctrlname)
	Case "ImageSelect":
		g_image = popStr
				
		if(stringmatch(g_image, "!_none_") &&stringmatch(g_ROI, "!_none_"))
			Button IPLDoIt disable = 0
			PopupMenu ThrMethod disable = 0
		else
			Button IPLDoIt disable =2
			PopupMenu ThrMethod disable = 2
		endif
		
	break
					
	Case "ROISelect":
		g_ROI= popStr
		if(stringmatch(g_image, "!_none_") &&stringmatch(g_ROI, "!_none_"))
			Button IPLDoIt disable = 0
			PopupMenu ThrMethod disable = 0
		else
			Button IPLDoIt disable =2
			PopupMenu ThrMethod disable = 2
		endif
	break	
	
	Case "Red":
		g_red = popnum
		If(g_red && g_yellow && g_cyan)
			Button IPLContinue disable = 0
		endif
	Break
	
	Case "Cyan":
		g_cyan = popnum
		If(g_red && g_yellow && g_cyan)
			Button IPLContinue disable = 0
		endif
	Break
	
	Case "Yellow":
		g_yellow = popnum
		If(g_red && g_yellow && g_cyan)
			Button IPLContinue disable = 0
		endif
	break
		
	Case "ThrMethod":
	
		if(popnum==7)
			
			g_method=popnum
			Setvariable ThrLevel disable = 2
		elseif(popnum == 6)
			g_method = 0
			imagestats /m=1 $g_image
			g_thr = round(v_avg)
			Setvariable ThrLevel disable = 0
		else
			g_method = popnum
			Setvariable ThrLevel disable = 2
		endif
	Break

	Default:
		print popstr, popnum, ctrlname
	Endswitch
	
	
End

//////////////////////ButtonControl///////////////////////////

Function IPLPosBC (ctrlName) : ButtonControl
	String ctrlName
	
	DFREF WF = root:Packages:IPLPosCP
	
SVAR g_image=WF:g_image, g_CoM=WF:g_CoM, g_TopY=WF:g_TopY, g_TopX=WF:g_TopX, g_BottomY=WF:g_BottomY, g_BottomX=WF:g_BottomX, g_ROI=WF:g_ROI
NVAR g_red=WF:g_red, g_cyan=WF:g_cyan, g_yellow=WF:g_yellow, g_method=WF:g_method, g_thr=WF:g_thr, g_DoLoess=WF:g_DoLoess


variable QuickPAResult, interpNumber
	
	StrSwitch(ctrlName)
	Case "IPLDoIt":
		if(stringmatch(g_image,"_none") || stringmatch(g_ROI,"_none_"))
			Doalert 0, "Please select an appropriate image and ROI."
		elseif(g_method < 7)
			Wave l_image = $g_image
			Wave l_ROI = $g_ROI
			CenterOfMass_custom(l_image,l_ROI)
			Wave CoM
			if(!WaveExists(CoM))
				DoAlert 0, "Couldn't calculate centers of mass"
				return -1
			endif
			
			
			QuickPAResult=QuickPA($g_image, 25, g_method, level=g_thr)
			
			If(QuickPAResult == -1)
				DoAlert 0, "Couldn't find any borders. Try different parameters."
				break
			Endif
			
			Wave TopX, TopY, BottomX, BottomY, ThirdX, ThirdY
		
			
			InterpNumber = 8*dimsize($g_image,0)
						
			if(horizontal(TopX, TopY))
				Reorder(TopX, TopY)
				InterpAndLoess(TopX, TopY, InterpNumber, DoLoess=g_DoLoess)
			else
				Reorder(TopY, TopX)
				InterpAndLoess(TopY, TopX, InterpNumber)
			endif
			
			if(horizontal(BottomX, BottomY))
				Reorder(BottomX, BottomY)
				InterpAndLoess(BottomX, BottomY, InterpNumber, DoLoess=g_DoLoess)
			else
				Reorder(BottomY, BottomX)
				InterpAndLoess(BottomY, BottomX, InterpNumber, DoLoess=g_DoLoess)
			endif
			
			if(horizontal(ThirdX, ThirdY))
				Reorder(ThirdX, ThirdY)
				InterpAndLoess(ThirdX, ThirdY, InterpNumber, DoLoess=g_DoLoess)
			else
				Reorder(ThirdY, ThirdX)
				InterpAndLoess(ThirdY, ThirdX, InterpNumber, DoLoess=g_DoLoess)
			endif
			
			// Simen note: I have in the following sections commented out any reference to 'increase contrast', as this screws with 
			// how images are displayed. Seems to be a bug with setting the range of contrast or something similar... Anyways, not neeeded! 
			
			Imagestats /m=1 $g_image
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Display /Host=IPLPosPanel /n=OverView /w=(340,15,640,315) as "OverView"; delayupdate
			appendimage $g_image; delayupdate
			//ModifyImage $g_image ctab={*,0.75*v_max,Grays,0};delayupdate				//increase contrast
			appendtograph CoM[][1] vs CoM[][0];delayupdate
			ModifyGraph mode=3,marker=8,rgb=(0,65535,0); delayupdate
			appendtograph TopY vs TopX; delayupdate
			appendtograph BottomY vs BottomX; delayupdate
			appendtograph ThirdY vs ThirdX; delayupdate
			ModifyGraph rgb(BottomY)=(0,65535,65535); delayupdate	//bottom = blue (cyan, really)
			ModifyGraph rgb(ThirdY)=(65535,65535,0); delayupdate				//third = yellow
			
			PopUpMenu Red disable = 0; delayupdate
			PopUpMenu Yellow disable = 0; delayupdate
			PopUpMenu Cyan disable = 0; delayupdate
			
			DoUpdate
			
		elseif(g_method ==7)	//manual drawing
			CenterOfMass_custom($g_image,$g_ROI)
			Wave CoM
			if(!WaveExists(CoM))
				DoAlert 0, "Couldn't calculate centers of mass"
				return -1
			endif
			
			Make/o TopY=0, TopX=0, BottomY=0, BottomX=0
			Imagestats /m=1 $g_image
			
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Display /Host=IPLPosPanel /n=OverView /w=(340,15,640,315) as "OverView"; delayupdate
			appendimage $g_image; delayupdate
			//ModifyImage $g_image ctab={*,0.75*v_max,Grays,0};delayupdate				//increase contrast
			appendtograph CoM[][1] vs CoM[][0];delayupdate
			ModifyGraph mode=3,marker=8,rgb=(0,65535,0); delayupdate
			appendtograph TopY vs TopX; delayupdate
			appendtograph BottomY vs BottomX; delayupdate
			ModifyGraph rgb(BottomY)=(0,65535,65535); delayupdate	//bottom = blue (cyan, really)
			SetAxis bottom dimoffset($g_image,0), dimdelta($g_image,0)*dimsize($g_image,0); delayupdate
			SetAxis left dimoffset($g_image,1), dimdelta($g_image,1)*dimsize($g_image,1); delayupdate
			DoUpdate
			
			
			Display /k=1/n=TopBorder /w=(340,15,740,415) as "First Border"; delayupdate
			ModifyGraph noLabel=2,axThick=0; delayupdate
			//ModifyGraph margin=-1; delayupdate
			appendimage $g_image; delayupdate
			//ModifyImage $g_image ctab={*,0.3*v_max,Grays,0};delayupdate				//increase contrast
			appendtograph CoM[][1] vs CoM[][0];delayupdate
			ModifyGraph mode=3,marker=8,rgb=(0,65535,0); delayupdate
			DoUpdate
			SizeImage(450)
			DoUpdate
			
			DoAlert 0, "Please draw the borders. Finish by closing the window."
			
			GraphWaveDraw /o/w=Topborder BottomY, BottomX
			PauseForUser TopBorder
			
			
			DoAlert 0, "Thanks, only once more, please"
			Display /k=1/n=BottomBorder /w=(340,15,740,415) as "Second Border"; delayupdate
			ModifyGraph noLabel=2,axThick=0; delayupdate
			//ModifyGraph margin=-1; delayupdate
			appendimage $g_image; delayupdate
			//ModifyImage $g_image ctab={*,0.3*v_max,Grays,0};delayupdate				//increase contrast
			appendtograph CoM[][1] vs CoM[][0];delayupdate
			ModifyGraph mode=3,marker=8,rgb=(0,65535,0); delayupdate
			appendtograph BottomY vs BottomX; delayupdate
			ModifyGraph rgb(BottomY)=(0,65535,65535); delayupdate
			DoUpdate
			SizeImage(450)
			DoUpdate
			
			GraphWaveDraw /o/w=BottomBorder TopY,TopX
			PauseForUser BottomBorder 
				
			PopUpMenu Red disable = 0; delayupdate
			PopUpMenu Cyan disable = 0; delayupdate
			g_yellow=3
			DoUpdate
			
			make /o/n=1 ThirdX, ThirdY	//to prevent errors later on
			ThirdX=0
			ThirdY=0
			
			duplicate /o topX DrawnTopX		//for Demonstration only
			duplicate /o topY DrawnTopY
			duplicate /o bottomX DrawnBottomX
			duplicate /o bottomY DrawnBottomY
			
			InterpNumber = 8*dimsize($g_image,0)
			if(horizontal(TopX, TopY))
				
				Reorder(TopX, TopY)
				InterpAndLoess(TopX, TopY, InterpNumber, DoLoess=g_DoLoess)
			else																		//Swap X/Y if vertical
				Reorder(TopY, TopX)
				InterpAndLoess(TopY, TopX, InterpNumber, DoLoess=g_DoLoess)
			endif
			
			if(horizontal(BottomX, BottomY))
				
				Reorder(BottomX, BottomY)
				InterpAndLoess(BottomX, BottomY, InterpNumber, DoLoess=g_DoLoess)
			else																		//Swap X/Y if vertical
				Reorder(BottomY, BottomX)
				InterpAndLoess(BottomY, BottomX, InterpNumber, DoLoess=g_DoLoess)
			endif
			
			if(horizontal(TopX, TopY) != horizontal(BottomX, BottomY))
				Reorder(TopX, TopY)				//reorder both again to make sure they run in the same direction
				Reorder(BottomX, BottomY)
			endif
			
			DoUpdate
			
			
			
		endif
	
	Break
	
	Case "IPLContinue":
		Wave CoM, BottomX, BottomY, TopY, TopX, ThirdX, ThirdY
		Button IPLResults disable = 0
		
		if(g_yellow == 3 && waveexists(ThirdX))
			ThirdX=0
			ThirdY=0
		endif
		if(g_cyan==3)
			BottomX=0
			BottomY=0
		endif
		if(g_red==3)
			TopY=0
			TopX=0
		endif
	
		if (g_red == 1 && g_cyan == 1 && g_yellow == 2)
			concatenate /o /np {TopX, BottomX}, NewTopX
			concatenate /o /np {TopY, BottomY}, NewTopY
			
			InterPAndLoess(ThirdX, ThirdY, numpnts(newtopx), doloess=0)
					
			MeasureDistances(CoM, ThirdX, ThirdY, NewTopx, NewTopY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 1 && g_cyan == 2 && g_yellow == 3)	
		
			MeasureDistances(CoM, BottomX, BottomY, Topx, TopY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 1 && g_cyan == 3 && g_yellow == 2)	
		
			MeasureDistances(CoM, ThirdX, ThirdY, Topx, TopY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 1 && g_cyan == 2 && g_yellow == 1)	
			concatenate /o /np {TopX, ThirdX}, NewTopX
			concatenate /o /np {TopY, ThirdY}, NewTopY
			
			InterPAndLoess(BottomX, BottomY, numpnts(newtopx), doloess=0)
		
			MeasureDistances(CoM, BottomX, BottomY, NewTopx, NewTopY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 1 && g_cyan == 2 && g_yellow == 2)	
			concatenate /o /np {BottomX, ThirdX}, NewBottomX
			concatenate /o /np {BottomY, ThirdY}, NewBottomY
			
			InterPAndLoess(TopX, TopY, numpnts(NewBottomX), doloess=0)
		
			MeasureDistances(CoM, NewBottomX, NewBottomY, Topx, TopY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
		
		elseif(g_red == 2 && g_cyan == 1 && g_yellow == 1)	
			concatenate /o /np {BottomX, ThirdX}, NewTopX
			concatenate /o /np {BottomY, ThirdY}, NewTopY
			
			InterPAndLoess(TopX, TopY, numpnts(newtopx), doloess=0)
		
			MeasureDistances(CoM, TopX, TopY, NewTopX, NewTopY)
				
			Wave Positions
			killwindow IPLPosPanel#Overview
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 2 && g_cyan == 1 && g_yellow == 2)	
			concatenate /o /np {TopX, ThirdX}, NewBottomX
			concatenate /o /np {TopY, ThirdY}, NewBottomY
			
			InterPAndLoess(BottomX, BottomY, numpnts(NewBottomX), doloess=0)
		
			MeasureDistances(CoM, NewBottomX, NewBottomY, BottomX, BottomY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 2 && g_cyan == 1 && g_yellow == 3)	
		
			MeasureDistances(CoM, TopX, TopY,BottomX,BottomY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 2 && g_cyan == 3 && g_yellow == 1)	
		
			MeasureDistances(CoM, ThirdX, ThirdY,TopX,TopY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 2 && g_cyan == 2 && g_yellow == 1)	
			concatenate /o /np {BottomX, TopX}, NewBottomX
			concatenate /o /np {BottomY, TopY}, NewBottomY
			
			InterPAndLoess(ThirdX, ThirdY, numpnts(NewBottomX), doloess=0)
		
			MeasureDistances(CoM, NewBottomX, NewBottomY,ThirdX,ThirdY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 3 && g_cyan == 1 && g_yellow == 2)	
		
			MeasureDistances(CoM, ThirdX, ThirdY,BottomX,BottomY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		elseif(g_red == 3 && g_cyan == 2 && g_yellow == 1)	
		
			MeasureDistances(CoM, BottomX,BottomY, ThirdX, ThirdY)
			Wave Positions
			if(wintype("IPLPosPanel#Overview"))
				killwindow IPLPosPanel#Overview
			endif
			Edit /Host=IPLPosPanel /n=DistTable /w=(340,15,640,315) Positions
			
		//Function MeasureDistances(CoM, BottomX, BottomY, Topx, TopY)
		else
			Doalert 0, "Illegal actions selected - please revise your selection"
			Button IPLResults disable = 2
		endif
	break
	
	Case "IPLResults":
		Wave TopX, TopY, BottomX, BottomY, ThirdX, ThirdY, CoM, Positions, Percentiles
		Display /k=1/n=IPLPositions as "IPL positions"; delayupdate
		ModifyGraph height = 300, width = 300; delayupdate
		appendimage $g_image; delayupdate
		DrawCoMNumbers(CoM, $g_image, S_Name, fontsize=10)	
		//appendtograph CoM[][1] vs CoM[][0];delayupdate
		//ModifyGraph mode=3,marker=8,rgb=(0,65535,0); delayupdate
		appendtograph Percentiles[][1][0] vs Percentiles[][0][0];  delayupdate
		appendtograph Percentiles[][1][20] vs Percentiles[][0][20];  delayupdate
		appendtograph Percentiles[][1][40] vs Percentiles[][0][40];  delayupdate
		appendtograph Percentiles[][1][60] vs Percentiles[][0][60];  delayupdate
		appendtograph Percentiles[][1][80] vs Percentiles[][0][80];  delayupdate
		appendtograph Percentiles[][1][100] vs Percentiles[][0][100]; delayupdate
		//appendtograph ThirdY vs ThirdX; delayupdate
		ModifyGraph rgb=(65535,65535,65535); delayupdate	//bottom = blue (cyan, really)
		appendtograph CoM[][1] vs CoM[][0]; delayupdate
		ModifyGraph rgb(CoM)=(65535,65535,0);delayupdate
		ModifyGraph mode(CoM)=3,marker(CoM)=8;delayupdate
		//ModifyGraph rgb(Topy)=(65535,65535,65535)
		Edit positions
		if(WinType("IPLPosPanel#DistTable"))
			Killwindow IPLPosPanel#DistTable
		endif
		Button IPLResults win=IPLPosPanel, disable=2
	break
	
	
	Case "IPLQuit":
	
		Killwindow IPLPosPanel
		DoUpdate
		DFREF saveDFR = GetDataFolderDFR()		//save current data folder
		if(DataFolderRefStatus(WF))
			SetDataFolder WF
			Killstrings /z g_image, g_CoM, g_TopY, g_TopX, g_BottomY, g_BottomX, g_ROI
			KillVariables /z  g_red, g_cyan, g_yellow, g_method, g_ thr, g_DoLoess
			Killwaves /z  CoM, BottomX, BottomY, TopY, TopX, ThirdX, ThirdY 
			KillWaves /z NewBottomX, NewBottomY, NewTopX, NewTopY
			SetDataFolder root:Packages
			KillDataFolder/z WF
			Variable ObjectCount=CountObjects("root:packages",1)+CountObjects("root:packages",2)+CountObjects("root:packages",3)+CountObjects("root:packages",4)
			if(ObjectCount==0)
				KillDataFolder root:packages
			endif	
			
		endif
		SetDataFolder saveDFR
	Break
	
	Case "IPLSave":
	
		Killwindow IPLPosPanel
		DoUpdate
		Killstrings /z g_image, g_CoM, g_TopY, g_TopX, g_BottomY, g_BottomX, g_ROI
		KillVariables /z  g_red, g_cyan, g_yellow, g_method, g_thr, g_DoLoess
	
	Break
	
	Default:
		Print "No action defined for "+ctrlName
	
	EndSwitch
	
	
	
End