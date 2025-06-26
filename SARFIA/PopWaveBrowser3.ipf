#pragma rtGlobals=1		// Use modern global access method.
#include "ExpDataBase2"	//Also Displays ExpDataBase2 traces
#include "Name2Num"

Static StrConstant k_DontEdit = "ROINr;nPoints;XDelta;XOffSet;XUnit;OriginID"

Function PoPWaveBrowser([PopWave])
wave PopWave
variable screenright, screenbottom

//Initialise Folders/////////////////////////////////////////////////////////
		If(DataFolderRefStatus(root:Packages)!=1)
			NewDataFolder root:Packages
			NewDataFolder root:Packages:PopWB
		ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:PopWB)!=1)
			NewDataFolder root:Packages:PopWB
		ElseIf( DataFolderRefStatus(root:Packages:PopWB)==1)
			
		Else
			DoAlert 0, "PopWB_Initialise failed due to conflict with a free data folder."
			return -1
		EndIf
		
		DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()




SetDataFolder WF
	string /g g_popwavename, g_PopWaveIndexStr="No wave selected", g_pw2Name, g_ORiginID="Origin:", g_LabelName
	variable /g g_popWaveIndex=0, g_Pw2=0, g_DispNorm, g_Wave2Type = 1, g_FixAxis = 0, g_AxisMin, g_AxisMax
	variable/g g_logright=0, g_DispEventStats=0, g_MEExists
	
	
SetDataFolder SaveDFR

SVAR g_popwavename=WF:g_popwavename, g_PopWaveIndexStr=WF:g_PopWaveIndexStr, g_pw2Name=WF:g_pw2Name, g_OriginID=WF:g_OriginID
NVAR g_DispNorm=WF:g_DispNorm,  g_Wave2Type = WF:g_Wave2Type, g_FixAxis=WF:g_FixAxis, g_AxisMin=WF:g_AxisMin, g_AxisMax=WF:g_AxisMax
NVAR MEE=WF:g_MEExists


GetWindow kwFrameInner wsize			//get right border
	
	screenright = V_Right

MEE=CheckMEExists(SaveDFR)

variable left=round(screenright/2), top = round(screenbottom/2)
variable halfheight = 230, halfwidth = 370


If (WinType("PoPBrowser"))
	doWindow /F PoPBrowser
else
	NewPanel /K=2 /N=PoPBrowser /W = (left-halfwidth,top-halfheight,left+halfwidth, top+halfheight) as "Pop Browser"
	Groupbox GBx1 pos={5,5}, size={730,135}, win=PoPBrowser
	PopupMenu PopSelect, pos={150,15}, bodywidth=170, proc=PWB_PMC, mode=1, title="PoP", popvalue="Select a populationwave", value=WaveList("*",";","TEXT:0,DIMS:2")+";_none_", win=PoPBrowser
	Button Prev, pos={470,15}, bodywidth=40, proc=PWB_BC, title="<<", disable=2, win=PoPBrowser
	Button Next, pos={530,15}, bodywidth=40, proc=PWB_BC, title=">>", disable=2, win=PoPBrowser
	Button PWBQuit, pos={670,15}, bodywidth=60,  proc=PWB_BC, title="Quit", win=PoPBrowser
	Button PWB2Clip, pos={600,15}, size={60,20},  proc=PWB_BC, title=" To Clip ", win=PoPBrowser
	Display /Host=PopBrowser /n=PopTrace /w=(5,150,735,455)
	TitleBox PWBIndex, frame=0, pos={300,17}, size={140,15}, title="Index:", variable=g_PopWaveIndexStr, win=PoPBrowser
	SetVariable PWB_SV, disable=2, bodywidth=50,pos={240,17},proc=PWB_VC, title="Index:",limits={-inf,inf,1},value=g_popWaveIndex, win=PoPBrowser
	
	PopupMenu PopSelect2, pos={170,55}, bodywidth=170, proc=PWB_PMC, mode=1, title="Stim/Cat", popvalue="Select a stim or cat wave", value=WaveList("*",";","TEXT:0,MAXLAYERS:0")+";_none_", disable=2, win=PoPBrowser

	TitleBox OriginID, frame=0, pos={250,60}, size={140,15}, title="Index:", variable=g_OriginID,disable=1, win=PoPBrowser
	PopUpMenu EDB2_Label, pos={520,55}, bodywidth=150, proc=PWB_PMC, mode=1, title="Property", popvalue="Select a Label", disable=1, win=PoPBrowser
	SetVariable Property, disable=1, bodywidth=100,pos={660,55},noproc, win=PoPBrowser, limits={-inf,inf,0}, title=" ", win=PoPBrowser
	
	CheckBox DispNorm, pos = {420,18}, title="ÆF/F", variable = g_DispNorm, disable=1, proc = PWB_CBC, win=PoPBrowser
	
	CheckBox Cat2nd, pos = {15,87}, title="Stim", disable=1, proc = PWB_CBC, win=PoPBrowser, mode=1, value = 1
	CheckBox Overlay2nd, pos = {55,87}, title="Pop/DB",  disable=1, proc = PWB_CBC, win=PoPBrowser, mode=1, value = 0
	CheckBox FixAxis, pos = {15,113}, title="Fix y-Axis", proc = PWB_CBC
	CheckBox LogRight,  win=PoPBrowser, pos = {90,113}, title="Log right axis?", proc = PWB_CBC, disable=1,value=0
	
	CheckBox DispEventStats,  win=PoPBrowser, pos = {180,113}, title="Display EventStats?", proc = PWB_CBC, value=0
	
		if(MEE)
			CheckBox DispEventStats, disable=0
		else
			CheckBox DispEventStats, disable=1
		endif
	
endif

if(!ParamisDefault(PopWave))
	DisplayPopInCP(PopWave,0)
	g_popwavename=NameOfWave(PopWave)
	Button Prev, disable=0
	Button Next,  disable=0
	SetVariable PWB_SV, disable=0
	PopupMenu PopSelect2 disable=0
	g_popWaveIndex=0
	g_PopWaveIndexStr=g_popwavename+"[]["+num2str( g_popWaveIndex)+"]"
endif


End

///////////////////////////////////////////

Static Function DisplayPopInCP(popwave, index, [pw2])
	wave popwave, pw2
	variable index
	
	DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()
	SVAR g_OriginID=WF:g_OriginID, g_LabelName=WF:g_LabelName
	NVAR g_DispNorm=WF:g_DispNorm, g_Wave2Type = WF:g_Wave2Type, logright=WF:g_logright
	NVAR g_FixAxis=WF:g_FixAxis, g_AxisMin=WF:g_AxisMin, g_AxisMax=WF:g_AxisMax
	NVAR DES=WF:g_DispEventStats, MEE=WF:g_MEExists
	
	SetDataFolder WF
	Duplicate /o popWave w_DispTrace
	redimension /n=(-1)  w_DispTrace
	w_DispTrace=popwave[p][index]
	SetDataFolder SaveDFR
	
	if(g_Wave2Type==0  && !ParamIsDefault(pw2))
		SetDataFolder WF
		Duplicate /o pw2 w_DispTrace2
		redimension /n=(-1)  w_DispTrace2
		w_DispTrace2=pw2[p][index]
		SetDataFolder SaveDFR
		Wave DispTrace2=WF:w_DispTrace2
	endif
	
	Wave DispTrace=WF:w_DispTrace
	
	string TNL, Disp, WNote, buffer
	
	If(Wintype("PoPBrowser#PopTrace"))
		KillWindow PoPBrowser#PopTrace;delayupdate
	endif
	
	if(index>dimsize(popwave,1))
		index=0
	endif
	
	WNote=Note(PopWave)
	buffer=StringByKey("LabelList",WNote,"=","\r")
	if(StrLen(Buffer))		//checking if PopWave is an ExpDB
		SetDataFolder WF
		String quote = "\""	//used to put quotes inside the quote...
		buffer=quote+buffer+quote
		TraceFromDB(PopWave,Index,ResultName="w_DispTrace")
		g_OriginID="Origin: "+Num2Name(PopWave[%OriginID][index])
		TitleBox OriginID disable=0, win=PoPBrowser
		PopUpMenu EDB2_Label,win=PoPBrowser, disable=0, value=#buffer
		CheckBox DispNorm, disable = 0
		SetVariable Property, value=PopWave[%$g_LabelName][Index]
		
		if(whichListItem(g_LabelName,k_DontEdit) > -1)
			SetVariable Property, noedit = 1
		else
			SetVariable Property, noedit = 0
		endif
		
		if(g_DispNorm)
		
			Variable BaseLine = popwave[%BaseLine][index]
			 DispTrace = (DispTrace - BaseLine)/ BaseLine
	
		
		endif
		
		
		SetDataFolder SaveDFR
	else
		TitleBox OriginID disable=1, win=PoPBrowser
		PopUpMenu EDB2_Label,win=PoPBrowser, disable=1
		SetVariable Property, disable=1
		CheckBox DispNorm, disable = 1
		
	endif	
	
	//Display 2nd wave
	if(paramisdefault(pw2))
	
		Display /Host=PopBrowser /n=PopTrace /w=(5,150,735,455) DispTrace;delayupdate
		ModifyGraph /w=PoPBrowser#PopTrace rgb($NameofWave(DispTrace))=(0,0,0);delayupdate
	
	elseif((waveDims(pw2)==2) && g_Wave2Type== 1)
		
		Display /Host=PopBrowser /n=PopTrace /w=(5,150,735,455) /r  pw2[][0];delayupdate
		appendtograph /w=PoPBrowser#PopTrace /r pw2[][1];delayupdate
		appendtograph /w=PoPBrowser#PopTrace DispTrace;delayupdate
		
		Label right "Stimulus";delayupdate
		Label left WaveUnits(popwave,-1);delayupdate
		
		if(logright)
			ModifyGraph /w=PoPBrowser#PopTrace log(right)=1
			MatrixOP/o/free Pw2No0 = Replace(Pw2,0,NaN)
			Setaxis right (WaveMin(pw2No0)/3),*
		endif
		
		
		TNL=TraceNameList("PoPBrowser#PopTrace",";",1)
		Disp = StringFromList(0,TNL)	//amber
		ModifyGraph /w=PoPBrowser#PopTrace lsize($Disp)=2,rgb($disp)=(65535,43690,0),mode($disp)=6;delayupdate	
		Disp = StringFromList(1,TNL)	//blue
		ModifyGraph /w=PoPBrowser#PopTrace lsize($Disp)=2,rgb($disp)=(0,0,65535),mode($disp)=6;delayupdate	
		
		ModifyGraph /w=PoPBrowser#PopTrace rgb($NameOfWave(DispTrace))=(0,0,0),lsize($NameOfWave(DispTrace))=2;delayupdate
	elseif(DimSize(pw2,0)==DimSize(popWave,1))
			Display /Host=PopBrowser /n=PopTrace /w=(5,150,735,455) DispTrace;delayupdate
			ModifyGraph /w=PoPBrowser#PopTrace rgb($NameofWave(DispTrace))=(0,0,0);delayupdate
			SetVariable Property, disable=0, value=pw2[index], title=""
			
	elseif(g_Wave2Type==0)
		Display /Host=PopBrowser /n=PopTrace /w=(5,150,735,455) DispTrace, DispTrace2;delayupdate
		ModifyGraph /w=PoPBrowser#PopTrace rgb($NameofWave(DispTrace))=(0,0,0);delayupdate
	
	else
		Display /Host=PopBrowser /n=PopTrace /w=(5,150,735,455) DispTrace;delayupdate
		ModifyGraph /w=PoPBrowser#PopTrace rgb($NameofWave(DispTrace))=(0,0,0);delayupdate
	
	endif
	
	if(g_DispNorm)
		Label /w=PoPBrowser#PopTrace left "ÆF/F";delayupdate
	endif
	
	if(g_FixAxis)
		SetAxis/w=PoPBrowser#PopTrace left, g_AxisMin, g_AxisMax;delayupdate
	
	endif
	
	//Overlay EventStats
	if(DES)
		Wave MetaEvents, MetaStats
		MetaStatsOverlay(MetaEvents, MetaStats, DispTrace, index, 3)
		Wave Overlay=WF:MS_Overlay
		Wave Markers=WF:MS_Markers
		string tracename
		
		//Decay fits
		tracename=NameOfWave(Overlay)
		appendtograph  /w=PoPBrowser#PopTrace Overlay
		ModifyGraph rgb($tracename)=(1,16019,65535)
		
		//Peaks
		tracename=NameOfWave(Markers)
		appendtograph /w=PoPBrowser#PopTrace markers[][2] vs markers[][0]
		ModifyGraph  /w=PoPBrowser#PopTrace mode($tracename)=3,marker($tracename)=8
		
		//Baselines
		tracename+="#1"
		appendtograph  /w=PoPBrowser#PopTrace markers[][1] vs markers[][0]
		ModifyGraph  /w=PoPBrowser#PopTrace mode($tracename)=3,marker($tracename)=9, offset($tracename)={-0.5,0}
	
	endif
	
	
	MEE=CheckMEExists(SaveDFR)
	
	if(MEE)
			CheckBox DispEventStats, disable=0
	else
			CheckBox DispEventStats, disable=1
	endif
	
	DoUpDate

end


///////////////////Popup Control///////////////////////////


Function PWB_PMC (ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
	DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()

	
	NVAR  g_popWaveIndex=WF:g_popWaveIndex, g_Pw2=WF:g_Pw2
	SVAR g_popwavename=WF:g_popwavename, g_PopWaveIndexStr=WF:g_PopWaveIndexStr, g_pw2Name=WF:g_pw2Name
	SVAR g_LabelName=WF:g_LabelName
	
	StrSwitch(ctrlName)
	
	Case "PopSelect":
	
	g_popWaveName=popStr
	g_popWaveIndex=0
	g_PopWaveIndexStr=g_popwavename+"[]["+num2str( g_popWaveIndex)+"]"
	
		if(!stringmatch(popStr, "_none_"))
			DisplayPopInCP($popStr, g_popWaveIndex)
			g_popWaveName=popStr
			Button Prev, disable=0
			Button Next,  disable=0
			SetVariable PWB_SV, disable=0
			PopupMenu PopSelect2 disable=0
			
	
		else
			PopupMenu PopSelect2 disable=2
			Button Prev, disable=2
			Button Next,  disable=2
			SetVariable PWB_SV, disable=2
			PopupMenu PopSelect2 disable=2
			
		endif
	
	Break
	
	Case "PopSelect2":
	
	if(stringmatch(popStr, "_none_"))
	
		DisplayPopInCP($g_popWaveName, g_popWaveIndex)
		g_Pw2=0
		CheckBox Cat2nd, disable = 1
		CheckBox Overlay2nd disable = 1
		
	else
	
		g_pw2Name=popStr
		DisplayPopInCP($g_popWaveName, g_popWaveIndex,pw2=$g_pw2Name)
		g_Pw2=1
		CheckBox Cat2nd, disable = 0
		CheckBox Overlay2nd disable = 0
		
		
		if(dimsize($g_pw2Name,1) == 2)
			CheckBox LogRight,  win=PoPBrowser, disable=0
		else
			CheckBox LogRight,  win=PoPBrowser, disable=1
		endif
		
		
	endif
	
	
	
	Break
	
	Case "EDB2_Label":
		wave Pwv=$g_popWaveName
		g_LabelName=popstr	
		SetVariable Property, value=Pwv[%$g_LabelName][g_popWaveIndex], disable=0
		if(whichListItem(g_LabelName,k_DontEdit) > -1)
			SetVariable Property, noedit = 1
		else
			SetVariable Property, noedit = 0
		endif
	break
	
	EndSwitch
	
End

///////////////////Button Control///////////////////////////


Function PWB_BC(ctrlName) : ButtonControl
	String ctrlName
	
	DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()

	
	NVAR  g_popWaveIndex=WF:g_popWaveIndex, g_Pw2=WF:g_Pw2
	SVAR g_popwavename=WF:g_popwavename, g_PopWaveIndexStr=WF:g_PopWaveIndexStr, g_pw2Name=WF:g_pw2Name
	
	StrSwitch (ctrlName)
	
	Case "Next":
		g_popWaveIndex += 1
		if(g_PopWaveIndex >= dimsize($g_popwavename, 1))
			g_popWaveIndex = 0
		endif
		g_PopWaveIndexStr=g_popwavename+"[]["+num2str( g_popWaveIndex)+"]"
		
		if(g_pw2)
			DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
		else
			DisplayPopInCP($g_popwavename, g_popwaveindex)
		endif
			
	Break
	
	Case "Prev":
		g_popWaveIndex -= 1
		if(g_PopWaveIndex < 0) 
			g_popWaveIndex = dimsize($g_popwavename, 1)-1
		endif
		g_PopWaveIndexStr=g_popwavename+"[]["+num2str( g_popWaveIndex)+"]"
		
		if(g_pw2)
			DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
		else
			DisplayPopInCP($g_popwavename, g_popwaveindex)
		Endif
	
	Break
	
	Case "PWBQuit":
		
		KillWindow PoPBrowser
			if(DataFolderRefStatus(WF))	//Clean Folders
			KillDataFolder/z WF	
			//SetDataFolder root:Packages
			Variable ObjectCount=CountObjects("root:packages",1)+CountObjects("root:packages",2)+CountObjects("root:packages",3)+CountObjects("root:packages",4)
			if(ObjectCount==0)
				KillDataFolder root:packages
			endif	
		
			SetDataFolder saveDFR
		endif
	Break
	Break
	
	Case "PWB2Clip":
	
		PutScrapText g_popwavename+"[]["+num2str( g_popWaveIndex)+"]"
	
	Break
	
	
	Default:
		Print "Pressed undefined button: "+ctrlName
	
	EndSwitch
	
	
End

///////////////////Variable Control///////////////////////////


Function PWB_VC (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()

	
	NVAR  g_popWaveIndex=WF:g_popWaveIndex, g_Pw2=WF:g_Pw2
	SVAR g_popwavename=WF:g_popwavename, g_PopWaveIndexStr=WF:g_PopWaveIndexStr, g_pw2Name=WF:g_pw2Name
	
	StrSwitch(ctrlName)
	
	Case "PWB_SV":
		if(VarNum >= dimsize($g_popwavename, 1))
			g_popWaveIndex = 0
		endif
		if(g_PopWaveIndex < 0) 
			g_popWaveIndex = dimsize($g_popwavename, 1)-1
		endif
		
		g_PopWaveIndexStr=g_popwavename+"[]["+num2str( g_popWaveIndex)+"]"
		
		if(g_pw2)
			DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
		else
			DisplayPopInCP($g_popwavename, g_popwaveindex)
		Endif
	
	
	Break
	
	
	Default:
		Print "Set undefined variable: "+ctrlName
	Break
	EndSwitch
	
	
End

///////////////////Checkbox Control///////////////////////////

Function PWB_CBC (ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selelcted, 0 if not
	
	DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()

	
	NVAR g_popWaveIndex=WF:g_popWaveIndex, g_Pw2=WF:g_Pw2, g_Wave2Type = WF:g_Wave2Type 
	NVAR g_FixAxis=WF:g_FixAxis, g_AxisMin=WF:g_AxisMin, g_AxisMax=WF:g_AxisMax, logright=WF:g_logright
	NVAR DES=WF:g_DispEventStats
	SVAR g_popwavename=WF:g_popwavename, g_PopWaveIndexStr=WF:g_PopWaveIndexStr, g_pw2Name=WF:g_pw2Name
	SVAR g_LabelName=WF:g_LabelName
	
	
	StrSwitch(ctrlName)
	
		Case "DispNorm":
			if(g_pw2)
				DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
			else
				DisplayPopInCP($g_popwavename, g_popwaveindex)
			Endif
		Break
		
		Case "Cat2nd":
			CheckBox Cat2nd, value = 1
			CheckBox Overlay2nd, value = 0
			g_Wave2Type  = 1
			if(g_pw2)
				DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
			else
				DisplayPopInCP($g_popwavename, g_popwaveindex)
			Endif
		Break
		
		Case "Overlay2nd":
			CheckBox Cat2nd,  value = 0
			CheckBox Overlay2nd,  value = 1
			g_Wave2Type = 0
			if(g_pw2)
				DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
			else
				DisplayPopInCP($g_popwavename, g_popwaveindex)
			Endif
		break
		
		Case "FixAxis":
			g_FixAxis = checked
			GetAxis /q/w=PoPBrowser#PopTrace left
			g_AxisMin = v_min
			g_axisMax = v_max	
			
			if(g_pw2 & !g_fixaxis)		//update graph if FixAxis is unchecked
				DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
			elseif(g_fixaxis==0)
				DisplayPopInCP($g_popwavename, g_popwaveindex)
			Endif
				
		Break
		
		Case "LogRight":
			logright = checked
			if(g_pw2)
				DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
			else
				DisplayPopInCP($g_popwavename, g_popwaveindex)
			Endif
		Break
		
		Case "DispEventStats":
			DES=Checked
			if(g_pw2)
				DisplayPopInCP($g_popwavename, g_popwaveindex,pw2=$g_pw2Name)
			else
				DisplayPopInCP($g_popwavename, g_popwaveindex)
			Endif
		
		Break
		
		Default:
			Print "Undefined checkbox checked (PWB_CBC): "+ctrlName
		Break
	
	
	EndSwitch
	
End

///////////////////MetaStats Overlay///////////////////////////

Static Function MetaStatsOverlay(MetaEvents, MetaStats, trace, index, maxlen)
	Wave MetaEvents, MetaStats, trace
	Variable index, maxlen
	
	Variable nEvents, start, stop, ii, len
	Variable y0, A, tCP, pCP, tau
	
	DFREF WF = root:Packages:PopWB, SaveDFR = GetDataFolderDFR()
	
	duplicate/o/free/r=[][7] MetaEvents, traceIndices			//Trace numbers; %TraceNr

	MatrixOP /o/free CurrentIndices = equal(traceindices, index)
	redimension/b/u CurrentIndices
	
	WaveStats /q/m=1 CurrentIndices
	
	FindValue /i=(index) CurrentIndices
	
	start=v_maxloc
	stop=start+v_sum		//cond < stop
	
	
	duplicate /o/free trace MS_Overlay
	Make/o/free/n=(stop-start,3) MS_Markers
	
	MS_Overlay=NaN
		
	SetDimLabel 1,0,tPeak, MS_Markers
	SetDimLabel 1,1,Baseline, MS_Markers
	SetDimLabel 1,2,absPeak, MS_Markers

	
	MS_Markers[][%tPeak]=MetaEvents[p+start][%tPeak]
	MS_Markers[][%BaseLine]=MetaEvents[p+start][%BaseLine]
	MS_Markers[][%absPeak]=MetaEvents[p+start][%absPeak]
	
	for(ii=start;ii<stop;ii+=1)
	
		tCP=MetaEvents[ii][%tPeak]
		pCP=(tCP-DimOffset(trace,0))/DimDelta(trace,0)
		y0=MetaEvents[ii][%BaseLine]
		A=MetaEvents[ii][%Amplitude]
		tau=MetaEvents[ii][%DecayTime]
		
		len=min((4*tau*ln(2))/DimDelta(trace,0),(maxlen/DimDelta(trace,0)))		//display decay until 1/16 of amplitude
	
		MS_Overlay[pCP,pCP+len]=y0+A*exp(-(x-tCP)/tau)
	
	endfor
	
	duplicate/o MS_Overlay WF:MS_Overlay
	duplicate/o MS_Markers WF:MS_Markers

End

////////////////////////////////////////////////////////

Static Function CheckMEExists(Folder)
	DFREF Folder

	if (WaveExists(Folder:MetaStats) && WaveExists(Folder:MetaEvents))
		return 1
	else
		return 0
	endif

end





 