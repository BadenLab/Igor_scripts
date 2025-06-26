#pragma rtGlobals=1		// Use modern global access method.
#include "EqualizeScaling"
#include "Name2Num"
#include "ROISIze"
#include "Normalize"

//Update 20100629 #MMD: added DB_CountEntries(DataBase)


///////Global constants///////////////////////////////////////////////

StrConstant k_LabelList="ROINr;Age;Position;Size;ONOFF;TSus;Stim;BaseLine;Experimenter;AnalysisBitMask;nPoints;XDelta;XOffSet;XUnit;OriginID"
StrConstant k_NaturalUnits="s;g;m;mol;A;K;cd;N;Pa;Gy;Sv;J;W;Bq;Hz;kat;Wb;H;T;C;V;¼C;F;Ohm;S;lx;lm;sr;rad"		//add more at the end only!
StrConstant k_Experimenter="IGOR;Elena;Ilaria;Anton;Ben;Federico;Manu;Tom;Zhao"								//add more at the end only!

//AnalysisBitMask//////////////////////////////////////////////////
//Least significantdigit right
//10^4			--10^3          -- 10^2       -- 10^1            -- 10^0
//BGSubtract	--IgnoreROIs -- Filtering -- Registration -- ImageThreshold.ImageThreshold

///////Local Constants///////////////////////////////////////////////

Static StrConstant k_Template="^[a-zA-z]\d\d\d\d[a-zA-z_]\d\d\d_Ave_QA$"	//e.g. d0727e001_Ave_QA or D0727_001_Ave_QA	see GrepString and Regular Expressions
Static StrConstant k_Suffixes="Age=_Age;Position=_pos;Size=_ROI_ROISize;ONOFF=_ONOFF;TSus=_TSus;BaseLine=_BL;Stim=_Stim"
Static StrConstant k_AutoDetect="Age;Position;Size;ONOFF;TSus;BaseLine;Stim"

///////Global Functions///////////////////////////////////////////////////

Function/wave DBFooter(PopWave,[LabelList,ResultName])			//Adds a footer to a populationwave (i.e. makes it a basic database)
	Wave PopWave
	String LabelList, ResultName
	
	String NewName, buffer, Units
	Variable XDim, nLabels,ii, YDim,FDL,jj
	
	If(ParamIsDefault(ResultName))
 		NewName="F0_"+NameOfWave(PopWave)
 	Else
 		NewName=ResultName
 	Endif
 	
 	If(ParamIsDefault(LabelList))
 		LabelList=k_LabelList
 	EndIf
 	
 	
 	nLabels=ItemsInList(LabelList)
 	
	XDim=DimSize(PopWave,0)
	YDim=DimSize(PopWave,1)
	Units=WaveUnits(PopWave,0)

	For(ii=0;ii<nLabels;ii+=1)
		Buffer=StringFromList(ii,LabelList)
		FDL=FindDimLabel(PopWave,0,buffer)
		if(FDL>-2)
			DoAlert 1, "Some DimLabels are already present. Overwrite all? (Scaling and other information will be lost.)" 
				if(v_flag==1)
					break
				else
					Abort
				endif		
		endif
	EndFor
	
	Make/d/o/free/n=(dimsize(popwave,0),dimsize(popwave,1)) PWHeader=PopWave		//Remove all scaling
	
	For(ii=0;ii<XDim;ii+=1)
		SetDimLabel 0,ii,Time,PWHeader
	EndFor
	
	if(YDim)
		SetDimLabel 1,-1,ROINumber,PWHeader
	endif
	
	InsertPoints /M=0 XDIM, nLabels,PWHeader
	
		For(ii=0;ii<nLabels;ii+=1)
			Buffer=StringFromList(ii,LabelList)		
			SetDimLabel jj,XDIM+ii,$buffer,PWHeader
			PWHeader[XDIM+ii][]=NaN
		EndFor
	
	variable n2n=Name2Num(NameofWave(PopWave),nChar=10)

	
	PWHeader[%ROINr][]=q
	PWHeader[%XDelta][]=DimDelta(PopWave,0)
	PWHeader[%XOffSet][]=DimOffSet(PopWave,0)
	PWHeader[%XUnit][]=WhichListItem(Units,k_NaturalUnits,";",0,0)
	PWHeader[%BaseLine][]=NaN
	PWHeader[%nPoints][]=XDim
	PWHeader[%OriginID][]=n2n

	
	
	Note PWHeader, "LabelList="+LabelList
	Duplicate/o PWHeader, $NewName
	Wave w=$NewName
	return w
End



////////////////////////////////////////////

Function/wave TraceFromDB(DataBase, index,[df, ResultName])		//Makes a traces for displaying/analysing etc. from the database
	wave Database
	Variable Index, df
	String ResultName
	
	
	if(ParamisDefault(df))			//return df/f
		df=0
	endif
	
	if(ParamisDefault(ResultName))
		resultName=Num2Name(DataBase[%OriginID][index])+"_"+Num2Str(index)
	endif
	
	Variable nPoints, XDelta,XOffSet, UnitPos, BaseLine
	String XUnit
	
	nPoints=DataBase[%nPoints][index]
	XDelta=DataBase[%XDelta][index]
	XOffset=DataBase[%XOffset][index]
	UnitPos=DataBase[%XUnit][index]
	
	make /d/n=(nPoints)/o $ResultName
	wave trace=$ResultName
	
	if(UnitPos==-1)
		XUnit=""
	else
		XUnit=StringFromList(UnitPos,k_NaturalUnits)
	endif
	
	SetScale /p x,XOffset,XDelta,XUnit, Trace
	
	Trace=DataBase[p][index]
	
	if(df)
	
		BaseLine=DataBase[%BaseLine][index]
		Trace=(Trace-BaseLine)/BaseLine		//dF/F
	
	endif
	
	return Trace
End

////////////////////////////////////////////

Function/wave PopFromDB(DataBase,[ResultName])		//Makes a Populationwave for displaying/analysing etc. from the database
	wave Database
	String ResultName
	
	if(ParamisDefault(ResultName))
		resultName=NameOfWave(DataBase)+"_Pop"
	endif
	
	Variable nTraces = DimSize(DataBase,1)
	
	Make/o/free/n=(nTraces) nPoints, XDelta,XOffSet, UnitPos, xShift
	String XUnit
	
	nPoints=DataBase[%nPoints][p]
	XDelta=DataBase[%XDelta][p]
	XOffset=DataBase[%XOffset][p]
	UnitPos=DataBase[%XUnit][p]
	
	WaveStats/q/m=1 nPoints
	if(v_max-v_min!=0)
		Abort "Mixing waves with different numbers of points is a bad idea..."
	endif
	
	WaveStats/q/m=1 XDelta
	if(v_max-v_min!=0)
		Abort "Mixing waves with different sample frequencies is a bad idea..."
	endif
	
		
	make /d/n=(nPoints[0],nTraces)/o $ResultName
	wave trace=$ResultName
	
	if(UnitPos[0]==-1)
		XUnit=""
	else
		XUnit=StringFromList(UnitPos[0],k_NaturalUnits)
	endif
	
		SetScale /p x,XOffset[0],XDelta[0],XUnit[0], Trace

	
	Trace=DataBase[p][q]
	
	return Trace
End


//////////////////////////////////

Function/wave CombineDataBases(ListWave)		//Automatically compiles a DataBase from waves listed in ListWave 
	Wave/Wave ListWave
	
	Variable nItems, ii, MaxDim=0, Dim,TotalTraces=0, CurrentTraces=0, jj, nLabels
	Variable nPoints, TraceCount=0
	String Buffer, LabelList
	
	nItems=DimSize(ListWave,0)				//Number of Waves to put in the DB
	
	if(nItems==0 || NumType(nItems)==2)
		Abort NameOfWave(ListWave)+" has no points. Aborting..."
	endif

	Make/o/free/t/n=(nItems) LabelListWave	//holds labels for each wave
	
	
	For(ii=0;ii<nItems;ii+=1)				
		buffer=NameOfWave(Listwave[ii])
		LabelListWave=StringByKey("LabelList",Note(ListWave[ii]),"=","\r")		//fill LabelListWave
	EndFor
	
	LabelList=LabelsFromListWave(LabelListWave)
	nLabels=ItemsInList(LabelList)

	For(ii=0;ii<nItems;ii+=1)				//Determine dimensions of DB
		Wave w=ListWave[ii]
		Dim=DimSize(w,0)
		MaxDim=max(MaxDim,Dim)		//Max number of points
		 CurrentTraces=DimSize(w,1)		//Number of traces
		 
		 
		 if(CurrentTraces)
		 	TotalTraces+=CurrentTraces		//Total number of traces
		 else								//if 1D wave
		 	TotalTraces+=1
		 endif	  
	EndFor
	
	Make/d/o/n=(MaxDim,TotalTraces) w_BDWave
	For(ii=0;ii<nLabels;ii+=1)
			Buffer=StringFromList(ii,LabelList)		
			SetDimLabel jj,MaXDIM+ii-nLabels,$buffer,w_bdwave
	EndFor
		
		
	w_BDWave=NaN
	
	
	For(ii=0;ii<nItems;ii+=1)
		Wave w=ListWave[ii]		
		nPoints=DimSize(w,0)-nLabels
		Dim=DimSize(w,0)
		CurrentTraces=DimSize(w,1)
	
		duplicate/o/free w, wcut
		DeletePoints /m=0 nPoints,nLabels, wcut
		
		w_BDWave[0,Dim-nLabels-1][TraceCount,TraceCount+CurrentTraces]=wcut[p][q-TraceCount]		//copy data
		
		For(jj=0;jj<nLabels;jj+=1)																		//copy other information
			Buffer=StringFromList(jj,LabelList)
			w_BDWave[%$buffer][TraceCount,TraceCount+CurrentTraces]=w[%$buffer][q-TraceCount]
		EndFor
		
		if(currenttraces)
			TraceCount+=Currenttraces
		else
			TraceCount+=1
		endif
		
	
	EndFor
	
	Note /k w_bdwave, "LabelList="+LabelList
	return w_bdwave
End

/////////////////////////////////////////


Function/wave MakeDataBase(wList,[LabelList])			//Automatically compiles a DataBase from waves listed in wList and adds information from associated waves, if they exist
	Wave/wave WList
	String LabelList
	
	Variable nLabels, nWaves, ii,jj, nAutoLabels
	string wName, Property, PropSuffix
	
	If(ParamIsDefault(LabelList))
		LabelList=k_LabelList
	EndIf
	
	
	If(DataFolderRefStatus(root:DataBase)!=1)
		NewDataFolder root:DataBase
	Endif
	
	DFREF WF=root:DataBase, CurrentDFR
	DFREF SaveDFR=GetDataFolderDFR()
	
	SetDataFolder WF
	
	nWaves=DimSize(wList,0)
	nLabels=ItemsInList(LabelList)
	nAutoLabels=ItemsInList(k_AutoDetect)
	
	Make/WAVE/n=(nWaves)/free FooterWaves
	
	For(ii=0;ii<nWaves;ii+=1)
		//buffer=StringFromList(ii,wList)
		Wave w= wList[ii]
		CurrentDFR=GetWavesDataFolderDFR(w)
		FooterWaves[ii]=DBFooter(w,LabelList=LabelList)
		
		For(jj=0;jj<nAutoLabels;jj+=1)
			Property=StringFromList(jj,k_AutoDetect)
			PropSuffix=StringByKey(Property,k_Suffixes,"=",";",0)
			wName=NameOfWave(w)+PropSuffix
			if(WaveExists(CurrentDFR:$wName))
				Wave fw=FooterWaves[ii]
				Wave PropW=CurrentDFR:$wName
				fw[%$Property][]=PropW[q]
			endif
		
		EndFor
		
	
	EndFor
	
	
	
	wave ret=CombineDataBases(FooterWaves)
	
	SetDataFolder SaveDFR
	return ret
End

////////////////////////////////////////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

Function/wave BuildDatabaseFromSubFolders([Template])	//screens subfolders for waves matching a template and compiles a database of them
	String Template

//Initialise//////////////////////////////////////////

	Variable nFolders,ii, nWaves=0, index=0, nItemsInList,jj
	String Buffer, WList, FolderList="", DataFolderStr

	If(ParamIsDefault(Template))
		Template=k_Template
	Endif
	
	If(DataFolderRefStatus(root:DataBase)!=1)
		NewDataFolder root:DataBase
	Endif
	
	DFREF WF=root:DataBase, CurrentFolder
	DFREF SaveDFR=root://GetDataFolderDFR()

//Get a list of all waves that match the template////////////////

	nFolders=CountObjectsDFR(SaveDFR,4)				//number of Folders in current directory
	
	make/o/n=(nFolders)/free/DF FolderWave
	
	For(ii=0;ii<nFolders;ii+=1)
		Buffer=GetIndexedObjNameDFR(SaveDFR,4,ii)	//Fill FolderWave with DataFolder references
		FolderWave[ii]=$buffer
	EndFor
	


	For(ii=0;ii<nFolders;ii+=1)

		CurrentFolder=FolderWave[ii]
		SetDataFolder CurrentFolder
		DataFolderStr=GetDataFolder(1,CurrentFolder)
		index=0

		do					//make a list of all waves in the current folder
			buffer=GetIndexedObjNameDFR(CurrentFolder, 1, index)	
		
			
			if (GrepString(buffer,Template) >0)
				
				FolderList=FolderList+DataFolderStr+buffer+";"
			endif
			
			index+=1
		While(strlen(buffer))
		
		
		SetDataFolder SaveDFR
	EndFor
	
//make a wave reference wave out of WList////////////////////////////
	
	nItemsInList=ItemsInList(FolderList)
	make/o/n=(nItemsInList)/wave WF:w_WaveRefWave
	wave/wave WaveRefWave=WF:w_WaveRefWave
		
	WaveRefWave=$StringFromList(p,FolderList)		
	
		
//Build DataBase///////////////////////////////////
	
	wave ret=MakeDataBase(WaveRefWave)
	return ret
End

////////////////////////////////////////////////


Function DBLaunch()


	wave DB=BuildDatabaseFromSubFolders()
	edit/k=1 DB.ld

End




//Local Functions//////////////////////////////////////////

Static Function /t LabelsFromListWave(LabelListWave)		//Makes a label-list that contains all the labels from all the waves
	Wave/t LabelListWave
	
	String LabelStr="", buffer, currentLabel
	Variable ii, nLabels, nWaves,jj,index
	
	nWaves=DimSize(LabelListWave,0)
	LabelStr=LabelListWave[0]
	
	For(ii=1;ii<nWaves;ii+=1)
		buffer=LabelListWave[ii]
		nLabels=ItemsInList(buffer)
		
		For(jj=0;jj<nLabels;jj+=1)
			currentLabel=StringFromList(jj,buffer)
			index=WhichListItem(currentLabel,LabelStr)
			if(index==-1)
				LabelStr=LabelStr+";"+currentLabel
			endif
		EndFor
	EndFor
	
	
	Return LabelStr
End


/////Control Panel//////////////////////////////////////////////

Function EDB2_CP()

//Make DataFolder for global variables/////////////////////////

	DFREF SaveDFR=GetDataFolderDFR(), WF
	Variable initialise=1
	
	If(DataFolderRefStatus(root:Packages)!=1)
		NewDataFolder root:Packages
		NewDataFolder root:Packages:EDB2CP
	ElseIf(DataFolderRefStatus(root:Packages)==1 && DataFolderRefStatus(root:Packages:EDB2CP)!=1)
		NewDataFolder root:Packages:EDB2CP
	ElseIf( DataFolderRefStatus(root:Packages:EDB2CP)==1)
		Initialise=0
	Else
		DoAlert 0, "EDB2CP_Initialise failed due to conflict with a free data folder."
		return -1
	EndIf
	
	WF=root:Packages:EDB2CP
	

//Set Global Variables///////////////////////////////////////////////////	
	
	SetDataFolder WF
	
		String/g g_NameOfDB, g_NameOfPosition, g_NameOfROIMask, g_NameOfONOFF, g_NameOfTSus
		String/g g_NameOfNorm, g_Experimenter, g_PopList, g_NameOfPop
		Variable/g g_Age, g_Stim, g_Registration, g_Filtering, g_Threshold, g_IgnoreROIs, g_BGSubtract
		
	SetDataFolder SaveDFR
	
		
	
//Make local references and variables///////////////////////////////////////////////////
	String NameOfPop
	String NameOfDB, NameOfPosition, NameOfROIMask, NameOfONOFF, NameOfTSus, NameOfNorm, Experimenter, NameOfNewDB
	Variable Age, Stim, Registration, Filtering, Threshold, IgnoreROIs, PressedCancel=0, skip=0, NewDB=0, BGSubtract
	SVAR g_NameOfDB=WF:g_NameOfDB, g_NameOfPosition=WF:g_NameOfPosition, g_NameOfROIMask=WF:g_NameOfROIMask, g_NameOfONOFF=WF:g_NameOfONOFF
	SVAR g_NameOfTSus=WF:g_NameOfTSus, g_NameOfNorm=WF:g_NameOfNorm, g_Experimenter=WF:g_Experimenter, g_PopList=WF:g_PopList, g_NameOfPop=WF:g_NameOfPop
	NVAR g_Age=WF:g_Age, g_Stim=WF:g_Stim, g_Registration=WF:g_Registration, g_Filtering=WF:g_Filtering, g_Threshold=WF:g_Threshold, g_IgnoreROIs=WF:g_IgnoreROIs
	NVAR g_BGSubtract=WF:g_BGSUbtract
	
	if(initialise==0)
		NameOfDB=g_NameofDB
		NameOfPosition=g_NameOfPosition
		NameOfROIMask=g_NameofROIMask
		NameOfONOFF=g_NameOfONOFF
		NameOfTSus=g_NameOfTSus
		NameOfNorm=g_NameOfNorm
		Experimenter=g_Experimenter
		NameOfPop=g_NameOfPop
		
		Age=g_Age
		Stim=g_Stim
		Registration=g_Registration
		Filtering=g_Filtering
		Threshold=g_Threshold
		IgnoreROIs=g_IgnoreROIs
		BGSubtract=g_BGSubtract
	Else
		NameOfDB="_new_"
		NameOfPosition=GuessNames(3)
		NameOfROIMask=GuessNames(1)
		NameOfPop=GuessNames(0)
		NameOfONOFF="_none_"
		NameOfTSus="_none_"
		NameOfNorm=GuessNames(2)
		Experimenter="Enter your name here"
		
		Age=NaN
		Stim=NaN
		Registration=0
		Filtering=0
		Threshold=3
		IgnoreROIs=0
		BGSUbtract=1
		
	EndIf
	
	
//Prompts//////////////////////////////////////////////////////////////
	
	Prompt NameOfDB, "Database", popup, "_new_;"+WaveList("*",";","DIMS: 2")
	Prompt NameOfPop, "Data to add (PopulationWave)", popup, WaveList("*",";", "MAXLAYERS: 1")
	Prompt NameOfNorm, "Normalized data (PopulationWave)", popup, "_none_;"+WaveList("*",";", "MAXLAYERS: 1")
	Prompt NameOfPosition, "Positions", popup, "_none_;"+WaveList("*",";","DIMS: 1")
	Prompt NameOfROIMask, "ROI Mask or Sizes", popup, "_none_;"+WaveList("*",";","MAXLAYERS: 1")
	Prompt NameOfONOFF, "ON/OFF", popup, "_none_;"+WaveList("*",";","DIMS: 1")
	Prompt NameOfTSus, "Transient/Sustained", popup, "_none_;"+WaveList("*",";","DIMS: 1")
	Prompt Experimenter, "Iam am IGOR. Who are you?", popup, k_Experimenter
	
	Prompt Age, "Age of test subject"
	Prompt Stim, "ID number of stimulus "
	Prompt Registration, "Was the image registered (0/1)?"
	Prompt Filtering, "Was the image filtered (0/1)?"
	Prompt BGSubtract, "Background Subtracted (0/1)?"
	Prompt Threshold, "What was the threshold for detecting ROIs (<10)?"
	Prompt IgnoreROIs, "ROIs smaller than what number were ignored (0-9)?"
	
	Prompt NameOfNewDB, "Name of the Database"


	DoPrompt/help="" "Basic Data",  NameOfDB, NameOfPop, NameOfROIMask, NameOfNorm
	skip+=v_flag
	
	if(skip==0)	
		DoPrompt/help="" "General information", Age, Stim, Registration, Filtering, BGSubtract, Threshold, IgnoreROIs
		skip+=v_flag
	endif
	
	if(skip==0)
		DoPrompt/help="" "Advanced Data", NameOfPosition, NameOfOnOFF, NameOfTsus, Experimenter
		skip+=v_flag
	endif

	g_NameOfDB=NameofDB
	g_NameOfPop=NameOfPop
	g_NameOfPosition=NameOfPosition
	g_NameOfROIMask=NameofROIMask
	g_NameOfONOFF=NameOfONOFF
	g_NameOfTSus=NameOfTSus
	g_NameOfNorm=NameOfNorm
	g_Experimenter=Experimenter
	
	g_Age=Age
	g_Stim=Stim
	g_Registration=Registration
	g_Filtering=Filtering
	g_Threshold=Threshold
	g_IgnoreROIs=IgnoreROIs
	g_BGSubtract=BGSubtract
	
	if(skip)		//if cancel was pressed terminate here
		return -1
	endif
	
	if(stringmatch(NameOfDB, "_new_"))
		NameOfNewDB=GuessNames(4)
		DoPrompt/help="" "Name of New Database" NameOfNewDB
		g_NameOfDB=NameofNewDB
		NewDB=1
	else
		NewDB=0
		g_NameOfDB=NameofDB
	endif
	
	if(v_flag==1)
		return -1
	endif

//Make DataBase//////////////////////////////////////////////////////

	Variable AnalysisBitMask=10^4*g_BGSubtract+10^3*g_IgnoreROIs+10^2*g_Filtering+10^1*g_Registration+g_Threshold

	Wave PopWithFooter=DBFooter($g_NameOfPop)
	PopWithFooter[%Age]=g_Age
	PopWithFooter[%Experimenter]=WhichListItem(g_Experimenter,k_Experimenter)
	PopWithFooter[%AnalysisBitMask]=AnalysisBitMask
	PopWithFooter[%Stim]=g_Stim
	
	
	wave/z PropWv=$g_NameOfPosition
	if(WaveExists(PropWv))
		PopWithFooter[%Position][]=PropWv[q]
	endif
	
	wave/z PropWv=$g_NameOfONOFF
	if(WaveExists(PropWv))
		PopWithFooter[%ONOFF][]=PropWv[q]
	endif
	
	wave/z PropWv=$g_NameOfTSus
	if(WaveExists(PropWv))
		PopWithFooter[%TSus][]=PropWv[q]
	endif
	
	wave/z PropWv=$g_NameOfNorm
	if(WaveExists(PropWv))
		if(WaveDims(PropWv)==2)			//calculate baseline from normalised Pop
			wave bl=BaseLineFromNor($g_NameOfPop,PropWv)
			PopWithFooter[%BaseLine][]=bl[q]
		else
			PopWithFooter[%BaseLine][]=PropWv[q]	//Take baseline from 1D property-wave
		endif
	endif
	
	wave/z PropWv=$g_NameOfROIMask
	if(WaveExists(PropWv))
		if(WaveDims(PropWv)==2)			//calculate baseline from normalised Pop
			wave size=ROISize(PropWv,resultname=g_NameOfPop+"_ROISize")
			size*=dimdelta(PropWv,0)*dimdelta(PropWv,1)	//scale sizes
			PopWithFooter[%Size][]=size[q]
		else
			PopWithFooter[%Size][]=PropWv[q]	//Take baseline from 1D property-wave
		endif
	endif
	
	
	if(NewDB)
		if(WaveExists($g_NameOfDB))
			DoAlert 1, "Overwrite "+g_NameOfDB+"?"
			if(v_flag==1)
				duplicate /o PopWithFooter, $g_NameOfDB
			else
				duplicate /o PopWithFooter, w_DB
			endif
		else
			duplicate PopWithFooter, $g_NameOfDB
		endif
	else
		Make/o /Wave ListWv={$g_NameOfDB,PopWithFooter}
		Wave Combined=CombineDataBases(ListWv)
		Duplicate/o Combined, $g_NameOfDB
		KillWaves/z Combined
	endif

	KillWaves/z  size, bl, PopWithFooter, ListWv
	Edit/k=1 $g_NameOfDB.ld
End


////////////////////////////////////////////////

Static Function/s GuessNames(mode)		//returns the name of waves with associated information, if present, else "_none_"
	variable mode

	DFREF WF=root:Packages:EDB2CP
	SVAR g_NameOfDB=WF:g_NameOfDB, g_NameOfPosition=WF:g_NameOfPosition, g_NameOfROIMask=WF:g_NameOfROIMask, g_NameOfONOFF=WF:g_NameOfONOFF
	SVAR g_NameOfTSus=WF:g_NameOfTSus, g_NameOfNorm=WF:g_NameOfNorm, g_Experimenter=WF:g_Experimenter, g_PopList=WF:g_PopList, g_NameOfPop=WF:g_NameOfPop

	String objName, suffix, ROIName, NorName,matchstr
	Variable index = 0, len, found=0, us
	DFREF dfr = GetDataFolderDFR()	// Reference to current data folder
		do
			objName = GetIndexedObjNameDFR(dfr, 1, index)
			len=strlen(objName)
			if (len == 0)
				break
			endif
			
			suffix="_QA"
			matchStr=objName[len-3,len-1]
			If(StringMatch(suffix, matchStr))
				found=1			//found a wave's name ending with _QA (ie Quick Analysis result)
				break
			
			endif
				
			index += 1
		while(1)

	if(found==1)					
	//checking if waves with associated information are present
	
		Switch (Mode)
			Case 0:		//NameOfPoP
				Return objName
			break
			
			Case 1:		//Name of ROIMask
				ROIName=objName+"_ROI"
				if(WaveExists($ROIName))
					return ROIName
				else
					return "_none_"
				endif
			break
			
			Case 2:		//Name of Norm
				NorName=objName+"_Nor"
				if(WaveExists($NorName))
					return NorName
				else
					return "_none_"
				endif
			break
			
			Case 3:		//Name of Positions
				if(WaveExists(:Positions))
					return "Positions"
				else
					return "_none_"
				endif
			break
			
			Case 4:		//Name of New DB
				us=StrSearch(objName,"_",0)
				if(us==-1)
					us=len
				endif
				
				return objName[0,us-1]+"_DB"
			break
					
		EndSwitch
		
		
	elseif(Mode==4)
		return "DataBase"
	else
		return "_none_"	
	endif



End


////////////////////////////////////////////////

Function DB_CountEntries(DataBase)
	wave DataBase
	
	variable ii, n
	Variable ExpCount=1
	string CurrentName, LastName, wName
	
	n=DimSize(DataBase,1)
	
	
	LastName=Num2Name(DataBase[%OriginID][0])
	LastName=LastName[0,8] //ymmddexxx
	
	For(ii=0;ii<n;ii+=1)
	
		CurrentName=Num2Name(DataBase[%OriginID][ii])
		CurrentName=CurrentName[0,8]
		
		If(!StringMatch(CurrentName, LastName))	//New Exp
			ExpCount+=1
			LastName=CurrentName
		Endif

		
	EndFor
	
	
	Return ExpCount

	
End