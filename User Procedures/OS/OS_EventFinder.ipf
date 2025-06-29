#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_EventFinder()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
// 2 //  check for Detrended Data stack
variable Channel = OS_Parameters[%Data_Channel]
if (waveexists($"wDataCh"+Num2Str(Channel)+"_detrended")==0)
	print "Warning: wDataCh"+Num2Str(Channel)+"_detrended wave not yet generated - doing that now..."
	OS_DetrendStack()
endif
// 3 //  check for ROI_Mask
if (waveexists($"ROIs")==0)
	print "Warning: ROIs wave not yet generated - doing that now (using correlation algorithm)..."
	OS_AutoRoiByCorr()
	DoUpdate
endif
// 4 //  check if Traces and Triggers are there
if (waveexists($"Triggertimes")==0)
	print "Warning: Traces and Trigger waves not yet generated - doing that now..."
	OS_TracesAndTriggers()
	DoUpdate
endif

// flags from "OS_Parameters"
variable Display_Stuff = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration]
variable Triggermode = OS_Parameters[%Trigger_Mode]
variable Ignore1stXseconds = OS_Parameters[%Ignore1stXseconds]
variable IgnoreLastXseconds = OS_Parameters[%IgnoreLastXseconds]
variable X_cut = OS_Parameters[%LightArtifact_cut]
variable maxPeaks = OS_Parameters[%Events_nMax]
variable peakfind_Threshold = OS_Parameters[%Events_Threshold]
variable Rate_Binssize_s = OS_Parameters[%Events_RateBins_s]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
string traces_name = "Traces"+Num2Str(Channel)+"_raw"
if (use_znorm==1)
	traces_name = "Traces"+Num2Str(Channel)+"_znorm"
endif
string tracetimes_name = "Tracetimes"+Num2Str(Channel)
duplicate /o $input_name InputStack
duplicate /o $traces_name InputTraces
duplicate /o $tracetimes_name InputTraceTimes

wave Triggertimes
variable nF = DimSize(InputTraces,0)
variable nRois = DimSize(InputTraces,1)
variable nX = DimSize(InputStack,0)
variable nY = DimSize(InputStack,1)
variable FrameDuration = nY*LineDuration // in seconds

string output_name1 = "Snippets"+Num2Str(Channel)
string output_name2 = "Averages"+Num2Str(Channel)
string output_name3 = "PeakTimes"+Num2Str(Channel)
string output_name4 = "PeakAmplitudes"+Num2Str(Channel)
string output_name5 = "EventSnippets"+Num2Str(Channel)
string output_name6 = "EventRates"+Num2Str(Channel)


variable tt,rr,ll,pp,xx,yy,ff

// Got through each full trace and identify "events"

make /o/n=(maxPeaks,nRois) PeakTimes = NaN
make /o/n=(maxPeaks,nRois) PeakAmplitudes = NaN

for (rr=0;rr<nRois;rr+=1)
	Make/O/N=(maxPeaks) peakPositionsX= NaN, peakPositionsY= NaN    
	make /o/n=(nF) Currenttrace = InputTraces[p][rr]
	Variable peaksFound=0
	Variable startP=0
	Variable endP= DimSize(Currenttrace,0)-1
	do
	    FindPeak/I/M=(peakfind_Threshold)/P/Q/R=[startP,endP] Currenttrace
	    // FindPeak outputs are V_Flag, V_PeakLoc, V_LeadingEdgeLoc,
	    // V_TrailingEdgeLoc, V_PeakVal, and V_PeakWidth. 
	    if( V_Flag != 0 )
	        break
	    endif
	    
	    peakPositionsX[peaksFound]=pnt2x(Currenttrace,V_PeakLoc)
	    peakPositionsY[peaksFound]=V_PeakVal
	    peaksFound += 1
	    
	    startP= V_TrailingEdgeLoc+1
	while( peaksFound < maxPeaks )

	PeakTimes[][rr]=peakPositionsX[p] * FrameDuration
	PeakAmplitudes[][rr]=peakPositionsY[p]
endfor


// Get Snippet Duration, nLoops etc..
variable nTriggers
variable Ignore1stXTriggers = 0
variable IgnoreLastXTriggers = 0
variable last_data_time_allowed = InputTraceTimes[nF-1][0]-IgnoreLastXseconds

for (tt=0;tt<Dimsize(triggertimes,0);tt+=1)
	if (NumType(Triggertimes[tt])==0)
		if (Ignore1stXseconds>Triggertimes[tt])
			Ignore1stXTriggers+=1
		endif
		if (Triggertimes[tt]<=last_data_time_allowed)
			nTriggers+=1
		endif
	else
		break
	endif
endfor
if (Ignore1stXTriggers>0)
	print "ignoring first", Ignore1stXTriggers, "Triggers"
endif
variable SnippetDuration = Triggertimes[TriggerMode+Ignore1stXTriggers]-Triggertimes[0+Ignore1stXTriggers] // in seconds

variable Last_Snippet_Length = (Triggertimes[nTriggers-1]-triggertimes[nTriggers-TriggerMode])/SnippetDuration
if (Last_Snippet_Length<SnippetDuration)
	IgnoreLastXTriggers = TriggerMode
endif
variable nLoops = floor((nTriggers-Ignore1stXTriggers-IgnoreLastXTriggers) / TriggerMode)

print nTriggers, "Triggers, ignoring 1st",  Ignore1stXTriggers, "and last", IgnoreLastXTriggers, "and skipping in", TriggerMode, "gives", nLoops, "complete loops"
print "Note: Last", IgnoreLastXseconds, "s are also clipped"


// make line precision timestamped trace arrays

variable nPoints = (nF * FrameDuration) / LineDuration
make /o/n=(nPoints,nRois) OutputTracesUpsampled = 0 // in line precision - deafult 500 Hz
make /o/n=(nPoints,nRois) OutputTracesUpsampled2 = 0 // in line precision - deafult 500 Hz - event markers
make /o/n=(nPoints,nRois) OutputTracesUpsampled3 = 0 // in line precision - deafult 500 Hz - event rates

for (rr=0;rr<nRois;rr+=1)
// for linear interpolation
	make /o/n=(nF*nY) CurrentTrace = NaN
	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
	for (ff=0;ff<nF-1;ff+=1)
		for (yy=0;yy<nY; yy+=1)
			CurrentTrace[ff*nY+yy]=(InputTraces[ff+1][rr]*yy+InputTRaces[ff][rr]*(nY-yy))/nY
		endfor
	endfor

// for hanned interpolation
//	make /o/n=(nF) CurrentTrace = InputTraces[p][rr]
//	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
//	Resample/RATE=(1/LineDuration) CurrentTrace


	variable lineshift = round(InputTraceTimes[0][rr] / LineDuration)
	OutputTracesUpsampled[lineshift,nPoints-4*FrameDuration/LineDuration][rr] = CurrentTrace[p-lineshift] // ignores last 4 frames of original recording to avoid Array overrun

	variable smoothwindowsize = (Rate_Binssize_s/LineDuration)/2
	for (pp=0;pp<maxPeaks;pp+=1)
		if (Numtype(PeakTimes[pp][rr])!=2)
			variable currenttime_line = PeakTimes[pp][rr]/LineDuration
			OutputTracesUpsampled2[currenttime_line][rr]=1
			OutputTracesUpsampled3[currenttime_line-smoothwindowsize,currenttime_line+smoothwindowsize][rr]+=1/nLoops
		endif
	endfor

endfor

// Snipperting and Averaging

make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTraceEventSnippets = 0 // in line precision
make /o/n=(SnippetDuration * 1/LineDuration,nRois) OutputTraceEventRates = 0 // in line precision
make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTraceSnippets = 0 // in line precision
make /o/n=(SnippetDuration * 1/LineDuration,nRois) OutputTraceAverages = 0 // in line precision
setscale /p x,0,LineDuration,"s" OutputTraceSnippets,OutputTraceAverages,OutputTraceEventRates,OutputTraceEventSnippets

for (rr=0;rr<nRois;rr+=1)
	for (ll=0;ll<nLoops;ll+=1)
		OutputTraceSnippets[][ll][rr]=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]
		OutputTraceEventSnippets[][ll][rr]=OutputTracesUpsampled2[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]		
		OutputTraceAverages[][rr]+=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]/nLoops
		OutputTraceEventRates[][rr]+=OutputTracesUpsampled3[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]/nLoops			
	endfor
endfor
OutputTraceEventSnippets[][][]=(OutputTraceEventSnippets[p][q][r]==0)?(NaN):(OutputTraceEventSnippets[p][q][r])

//
//
//// export handling
duplicate /o OutputTraceSnippets $output_name1
duplicate /o OutputTraceAverages $output_name2
duplicate /o PeakTimes $output_name3
duplicate /o PeakAmplitudes $output_name4
duplicate /o OutputTraceEventSnippets $output_name5
duplicate /o OutputTraceEventRates $output_name6

//

//// display
//
if (Display_Stuff==1)
	// full traces with points
	display /k=1
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	
	//ModifyGraph fSize=8,noLabel(StimY)=2,axThick(StimY)=0,lblPos(StimY)=47;DelayUpdate
	//ModifyGraph axisEnab(StimY)={0.05,0.15},freePos(StimY)={0,kwFraction}

	for (rr=0;rr<nRois;rr+=1)
		string YAxisName = "YAxis_Roi"+Num2Str(rr)
		string tracename
		
		Appendtograph /l=$YAxisName $traces_name[][rr] vs $tracetimes_name[][rr]
		Appendtograph /l=$YAxisName $output_name4[][rr] vs $output_name3[][rr]
		
		tracename = traces_name+"#"+Num2Str(rr)
		if (rr==0)
			tracename = traces_name
		endif
		variable colorposition = 255 * (rr+1)/nRois
		ModifyGraph rgb($tracename)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
		tracename = output_name4+"#"+Num2Str(rr)
		if (rr==0)
			tracename = output_name4
		endif
		ModifyGraph mode($tracename)=3,marker($tracename)=19;DelayUpdate
		ModifyGraph msize($tracename)=1, rgb($tracename) = (0,0,0)
		
		variable plotfrom = (1-((rr+1)/nRois))*0.8+0.2
		variable plotto = (1-(rr/nRois))*0.8+0.2
		
		ModifyGraph fSize($YAxisName)=8,axisEnab($YAxisName)={plotfrom,plotto};DelayUpdate
		ModifyGraph freePos($YAxisName)={0,kwFraction};DelayUpdate
		Label $YAxisName "\\Z10"+Num2Str(rr)
		ModifyGraph noLabel($YAxisName)=1,axThick($YAxisName)=0;DelayUpdate
		ModifyGraph lblRot($YAxisName)=-90
	endfor
	ModifyGraph fSize(bottom)=8,axisEnab(bottom)={0.05,1};DelayUpdate
	Label bottom "\\Z10Time (\U)"
	
	// Snippets
	display /k=1
	
	for (rr=0;rr<nRois;rr+=1)
		YAxisName = "YAxis_Roi"+Num2Str(rr)
		for (ll=0;ll<nLoops;ll+=1)
			tracename = output_name1+"#"+Num2Str(rr*nLoops+ll)
			if (ll==0 && rr==0)
				tracename = output_name1
			endif
			Appendtograph /l=$YAxisName $output_name1[][ll][rr]
			ModifyGraph rgb($tracename)=(52224,52224,52224)
		endfor	
		tracename = output_name2+"#"+Num2Str(rr)
		if (rr==0)
			tracename = output_name2
		endif
		Appendtograph /l=$YAxisName $output_name2[][rr]
		colorposition = 255 * (rr+1)/nRois
		ModifyGraph rgb($tracename)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
		ModifyGraph lsize($tracename)=1.5
		
		plotfrom = (1-((rr+1)/nRois))*0.8+0.2
		plotto = (1-(rr/nRois))*0.8+0.2
		
		ModifyGraph fSize($YAxisName)=8,axisEnab($YAxisName)={plotfrom,plotto};DelayUpdate
		ModifyGraph freePos($YAxisName)={0,kwFraction};DelayUpdate
		Label $YAxisName "\\Z10"+Num2Str(rr)
		ModifyGraph noLabel($YAxisName)=1,axThick($YAxisName)=0;DelayUpdate
		ModifyGraph lblRot($YAxisName)=-90
	endfor
	ModifyGraph fSize(bottom)=8,axisEnab(bottom)={0.05,1};DelayUpdate
	Label bottom "\\Z10Time (\U)"
	
	// Event Snippets
	display /k=1
	
	for (rr=0;rr<nRois;rr+=1)
		YAxisName = "YAxis_Roi"+Num2Str(rr)
		string YAxisName2 = "YAxis_Roi_Events"+Num2Str(rr)		
		for (ll=0;ll<nLoops;ll+=1)
			tracename = output_name5+"#"+Num2Str(rr*nLoops+ll)
			if (ll==0 && rr==0)
				tracename = output_name5
			endif
			Appendtograph /l=$YAxisName2 $output_name5[][ll][rr]
			ModifyGraph rgb($tracename)=(0,0,0)
			ModifyGraph mode($tracename)=3,marker($tracename)=19, msize($tracename)=1;DelayUpdate
			ModifyGraph offset($tracename)={0,nLoops-ll}, mrkThick($tracename)=1
			
		endfor	
		tracename = output_name6+"#"+Num2Str(rr)
		if (rr==0)
			tracename = output_name6
		endif
		Appendtograph /l=$YAxisName $output_name6[][rr]
		colorposition = 255 * (rr+1)/nRois
		ModifyGraph rgb($tracename)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
		ModifyGraph lsize($tracename)=1.5
		
		plotfrom = (1-((rr+1)/nRois))*0.8+0.2
		plotto = (1-(rr/nRois))*0.8+0.2
		
		ModifyGraph fSize($YAxisName)=8,axisEnab($YAxisName)={plotfrom,plotto};DelayUpdate
		ModifyGraph freePos($YAxisName)={0,kwFraction};DelayUpdate
		Label $YAxisName "\\Z10"+Num2Str(rr)
		ModifyGraph noLabel($YAxisName)=1,axThick($YAxisName)=0;DelayUpdate
		ModifyGraph lblRot($YAxisName)=-90
		
		ModifyGraph fSize($YAxisName2)=8,axisEnab($YAxisName2)={plotfrom,plotto};DelayUpdate
		ModifyGraph freePos($YAxisName2)={0,kwFraction};DelayUpdate
		ModifyGraph noLabel($YAxisName2)=1,axThick($YAxisName2)=0;DelayUpdate
		SetAxis $YAxisName2 0,nLoops*5
		
	endfor
	ModifyGraph fSize(bottom)=8,axisEnab(bottom)={0.05,1};DelayUpdate
	Label bottom "\\Z10Time (\U)"
	
endif
//
//
//// cleanup
killwaves InputTraces, InputTraceTimes,CurrentTrace,OutputTracesUpsampled,OutputTraceSnippets,OutputTraceAverages,OutputTracesUpsampled2,OutputTracesUpsampled3
killwaves peakPositionsX, peakPositionsY,PeakTimes,PeakAmplitudes

end