#pragma rtGlobals=1		// Use modern global access method.
#include "SlidingMedAvg"

///////////////////////////////////////////////////////////////////////////////
//																							//
// Function EventDetection(trace, bin, durationr, durationd,  direction, thr,[show, verbose])	//
// Event detection using the 2nd derivative to find peaks.	It returns the resulting	 			//
//		wave, Events.																		//
// trace: 1D wave to be analysed																//
// bin: number of points to be averaged - reduces the number of points; set to 1 to			//
//		analyse non-smoothed trace.															//
// durationr, durationd times for rise and decay  - The baseline is measured between			//
// 		-durationd and durationr, decacays are fitted from -durationr to peak and from		//
//		peak to	durationd.																	//
// direction: 1 for positive going peaks, -1 for negative going ones.							//
// thr: threshold on the 2nd derivative (normalised by SD) to detect peaks.					//
// show: show=1 displays results															//
// verbose: prints errors and keeps intermediate results for debugging/demonstration		//
//																							//
// Results are stored in the wave events with 5 columns and nevents rows.					//
// Column 0 (tpeak): time of peak (scaled).													//
// Column 1 (baseline): local baseline (treat with care).										//
// Column 2 (amplitude): relative amplitude, i.e. abspeak - basline (treat with care)			//
// Column 3 (abspeak): absolute amplitude													//
// Column 4 (risetime): tau of single exp. fit (check for fitting errors)						//
// Column 5 (decaytime): : tau of single exp. fit  (check for fitting errors)					//
//																							//
// EventStats(events) calculates average, SD, SEM, Median, Q25, Q75 and nEvents for 		//
//		inter-event-intervals (IEI), loc. baseline, loc. amplitude, absolute amplitude, 		//
//		rise- and decay times. Returns the wave EventsStats.									//
//																							//
// By Mario Dorostkar; MRC-LMB 2010													//
//////////////////////////////////////////////////////////////////////////////


Function/wave EventDetectionMT(trace, bin, durationr,durationd, direction, thr,[globalBL, show, verbose,xing])
	wave trace
	variable bin, durationr, durationd, direction, thr, globalBL, show, verbose,xing

//Declare local variables & strings
	variable npoints,  newnum, ii, nevents = 0, r_duration, d_duration, locthresh
	variable tpeak, baseline, amplitude, risetime, decaytime, abspeak, deltaF
	variable xloc, peakloc, delta, ErrorNum, nThreads
	Variable fitstart, fitend
	Variable tgID, ThreadStatus, ThreadWait
	
		
	string Error, ErrorList="", currentError
	
	nThreads=ThreadProcessorCount
	
	if(nThreads<2)
		Abort "No MT"
	endif
	
	
//Check optional parameters	
	if(paramisdefault(xing))
		xing=0
	endif


	if(paramisdefault(globalBL))
		globalBL=0
	endif

	if(paramisdefault(show))
		show=0
	endif
	
	if(paramisdefault(verbose))
		verbose=0
	endif
	
	if(direction >0)
		direction=1
	else
		direction=-1
	endif
	
	bin=round(bin)
	
	
//Analyze crossings?
	if(xing>0)
			
		return XDetection(trace, bin, direction, thr,GlobalBL=GlobalBL)
	
	endif
	
	
//Set local variables
	r_duration=round(durationr/dimdelta(trace,0))		//duration in points
	d_duration=round(durationd/dimdelta(trace,0))
	npoints = numpnts(trace)							//numbr of points (in x)

//Make local and global waves
	
	duplicate/o/free trace, fitted					//fitted trace
	duplicate/o trace, fitsd, fitsr					//fits (decay and rise)
	fitsd=NaN
	fitsr=NaN
	duplicate/o/free trace, loctrace						//make local copy of trace	
	
	make/o/free/n=1 taud, taur						//decay tau and rise tau
	
//Calculate running average/binned wave
	
	wave av=slidingAvg(trace,bin)
	newnum = dimsize(av,0)						//number of points after binning

	
//Threshold 2nd derivative 
	FastOP av=(direction)*av					//adjust sign for negative peaks
	FastOP loctrace=(direction)*trace			//adjust sign for negative peaks

	duplicate /o/free av, av_d1, av_d2
	
	differentiate av /d=av_d1					//first derivative
	differentiate av_d1 /d=av_d2				//second derivative
	
	wavestats /m=2/q av_d2
	
	locthresh = thr*v_sdev*-1					//normalise threshold
	
	matrixop /o/free eventlocator = -greater(av_d2, locthresh)+1		//do thresholding
	copyscales av, eventlocator
	
	
//Initialise results
	make /o/n=(1,7) events = NaN
	
	SetDimLabel 1, 0, tPeak, events
	SetDimLabel 1, 1, Baseline, events
	SetDimLabel 1, 2, Amplitude, events
	SetDimLabel 1, 3, absPeak, events
	SetDimLabel 1, 4, Risetime, events
	SetDimLabel 1, 5, Decaytime, events
	SetDimLabel 1, 6, DeltaF, events
	
	

//define minimum distance between two peaks	
	delta = dimdelta(trace,0)
	
//Calculate global baseline
	if(globalBL)
		baseline=GlobalBaseLine(trace)
		duplicate trace BLTrace
		BLTrace=baseline
	else 
		variable n=round(DimSize(trace,0)/20)
		wave BLTrace=slidingMed(trace, n)
	endif

//Calculate properties of events
	
	tgID=ThreadGroupCreate(2)		//spawn threads

	for(ii=0;ii<newnum;ii+=1)
	
		if(eventlocator[ii])
			
		
			xloc = ii*dimdelta(eventlocator,0)+dimoffset(eventlocator,0)		//x location of event (scaled)
			
			//baseline
			baseline=bltrace[ii]
			
			
			//time of peak, amplitude
			wavestats/q/m=1 /r=(xloc-delta, xloc+delta) loctrace
			
			tpeak = v_maxloc
			amplitude = v_max-baseline
			
			if(tpeak-events[nevents-1][0]<2*delta)		//do not log event, if peak is too close to previous
				continue
			endif
			
			peakloc=x2pnt(trace,tpeak)
			abspeak=v_max			
			
			
			//fitting decay
			fitstart=peakloc
			fitend=peakloc+d_duration

			ThreadStart tgID,0, ED_MTfitting(loctrace,fitstart,fitend,fitted,fitsd,taud)
		
			
			
			//fitting rise
			fitstart=peakloc-r_duration
			fitend=peakloc

			ThreadStart tgID,1, ED_MTfitting(loctrace,fitstart,fitend,fitted,fitsr,taur)
			
			ThreadWait+=ThreadGroupWait(tgID,inf)			//wait for threads to finish
			
			decaytime=taud[0]
			riseTime=taur[0]
			deltaF=amplitude/baseline
			
			events[nevents][]={{tpeak}, {baseline}, {amplitude}, {abspeak}, {risetime}, {decaytime},{deltaF}}
			nevents+=1
			
		endif
	

	endfor
	
	ThreadStatus=ThreadGroupRelease(tgID)		//kill threads
	
	FastOP fitsd=(direction)*fitsd			//adjust sign for negative peaks
	FastOP fitsr=(direction)*fitsr			//adjust sign for negative peaks
	events[][1,3]*=direction				//adjust sign for negative peaks
	
	nevents=dimsize(events,0)				//number of events found

	
	
	//display results
	if(show)
		string tracename=NameOfWave(trace)
		edit/k=1 events.ld
	
		display /k=1 trace
		ModifyGraph lsize($tracename)=2
		
		appendtograph events[][1] vs events[][0]	//baseline
		ModifyGraph mode(events)=3,marker(events)=9,rgb(events)=(0,0,0)
		ModifyGraph offset(events)={-durationd+durationr,0}
		
		appendtograph events[][3] vs events[][0]	//peaks
		ModifyGraph mode(events#1)=3,marker(events#1)=8,rgb(events#1)=(0,0,0)
		
		appendtograph fitsd, fitsr
		ModifyGraph rgb(fitsd)=(0,0,0), rgb(fitsr)=(1,12815,52428)
		
	endif
	
	if(verbose)
		printf "Local threshold: %g\r  Number of events: %g\r", locthresh, nevents
		if(strlen(ErrorList))
			printf "List of errors:\r " 
			print errorList
		endif
		
		printf "ThreadStatus: %g\r  ThreadWait Sum:%g\r",ThreadStatus, ThreadWait
		
		//waves for debugging
		duplicate /o av av_trace
		duplicate/o av_d2 d2trace
		duplicate/o eventlocator EventLocations
		duplicate/o BLtrace BaselineTrace
		
	endif
	
	Killwaves /z w_coef, W_fitConstants, av_d1, av_d2, BLtrace
		
	return Events
end 

/////////////////////////////////////////////////////////////////////////////////

ThreadSafe Static Function ED_MTfitting(loctrace,fitstart,fitend,fitted,fits,tau)
	wave loctrace, fitted, fits, tau
	variable fitstart, fitend
	
	variable decaytime, ErrorNum
	
	try
		CurveFit/q/n/NTHR=1 exp_XOffset  loctrace[fitstart,fitend] /D=fitted
		ErrorNum=GetRTError(1)
		wave/z w_coef
		AbortOnValue ErrorNum, 1
		decaytime=w_coef[2]
	
		fits[fitstart,fitend]=fitted(x)
		ErrorNum=GetRTError(1)
		AbortOnValue ErrorNum, 1
	catch
		//If fit doesn't work, return NaN
		decaytime=NaN

	endtry

	tau[0]=decaytime
end

/////////////////////////////////////////////////////////////////////////////////

Function/wave XDetection(trace, bin, direction, thr,[GlobalBL])		//detects level crossings
	Wave trace
	Variable bin, direction, thr
	Variable GlobalBL
	
//Local Variables	
	Variable locThr, baseline, edge
	
	if(bin<1)
		bin=1
	endif

//Calculate global baseline

		baseline=GlobalBaseLine(trace)
		WaveStats/Q trace
		locThr=baseline+thr*v_sdev
		

//Find Levels
	if(direction>0)
		edge=1
	else
		edge=2
	endif
	
	
	FindLevels/b=(bin)/edge=(edge)/Q trace, locthr
	Wave W_FindLevels
	
//Initialise results
	make /o/n=(NumPnts(W_FindLevels),7) events = NaN
	
	SetDimLabel 1, 0, tPeak, events
	SetDimLabel 1, 1, Baseline, events
	SetDimLabel 1, 2, Amplitude, events
	SetDimLabel 1, 3, absPeak, events
	SetDimLabel 1, 4, Risetime, events
	SetDimLabel 1, 5, Decaytime, events
	SetDimLabel 1, 6, DeltaF, events

//Write Results
	events[][%tPeak]=W_FindLevels[p]
	events[][%BaseLine]=baseline
	events[][%AbsPeak]=locThr
	
		
	return Events
end 


//////////////////////////////////////////////////////////////////////////////


Function/wave EventStats(events)
	Wave events	
	
	variable ii
	
	variable IEI_avg, IEI_sd, bl_avg, bl_sd, ampl_avg, ampl_sd, abspeak_avg, abspeak_sd, nEvents
	variable risetime_avg, risetime_sd, decaytime_avg, decaytime_sd
	variable nEntries
	
	nevents=dimsize(events,0)
	nEntries=dimsize(events,1)
	
	
	
	make /o/n=(7,7) EventsStats = NaN
	
	
	
	SetDimLabel 1, 0, IEI, eventsStats
	SetDimLabel 1, 1, Baseline, eventsStats
	SetDimLabel 1, 2, Amplitude, eventsStats
	SetDimLabel 1, 3, absPeak, eventsStats
	SetDimLabel 1, 4, Risetime, eventsStats
	SetDimLabel 1, 5, Decaytime, eventsStats
	SetDimLabel 1, 6, DeltaF, eventsStats
	
	SetDimLabel 0,0, Avg, EventsStats
	SetDimLabel 0,1, Sdev, EventsStats
	SetDimLabel 0,2, SEM, EventsStats
	SetDimLabel 0,3, Median, EventsStats
	SetDimLabel 0,4, Q25, EventsStats
	SetDimLabel 0,5, Q75, EventsStats
	SetDimLabel 0,6,nEvents, EventsStats
	
	if(nEvents == 0)
		return EventsStats
	elseif(nEvents == 1)					//can't calculate statistics on n=1 (or shouldn't, really)
		EventsStats[%nEvents][]=1
		EventsStats[%nEvents][%IEI]=0
		EventsStats[%Avg][%baseline]=events[%baseline]		
		EventsStats[%Sdev][%baseline]=0
		EventsStats[%SEM][%baseline]=0		
		EventsStats[%Median][%baseline]=events[%baseline]
		
		EventsStats[%Avg][%amplitude]=events[%Amplitude]
		EventsStats[%Sdev][%amplitude]=0
		EventsStats[%SEM][%amplitude]=0
		EventsStats[%Median][%amplitude]=events[%Amplitude]

		EventsStats[%Avg][%abspeak]=events[%AbsPeak]
		EventsStats[%Sdev][%abspeak]=0
		EventsStats[%SEM][%abspeak]=0
		EventsStats[%Median][%abspeak]=events[%AbsPeak]

		EventsStats[%Avg][%risetime]=events[%Risetime]
		EventsStats[%Sdev][%risetime]=0
		EventsStats[%SEM][%risetime]=0
		EventsStats[%Median][%risetime]=events[%Risetime]

		EventsStats[%Avg][%decaytime]=events[%Decaytime]
		EventsStats[%Sdev][%decaytime]=0
		EventsStats[%SEM][%decaytime]=0
		EventsStats[%Median][%decaytime]=events[%Decaytime]
		
		EventsStats[%Avg][%DeltaF]=events[%DeltaF]
		EventsStats[%Sdev][%DeltaF]=0
		EventsStats[%SEM][%DeltaF]=0
		EventsStats[%Median][%DeltaF]=events[%DeltaF]
	
		return EventsStats
	endif
	
	if(nEntries>7)			//analysing MetaEvents
		Wave IEI=MetaEventIEI(Events)
	else
		make/o/free/n=(nevents-1) IEI
		MultiThread IEI=events[p+1][%tpeak]-events[p][%tpeak]
	endif
	
	
	wavestats/q/m=2 IEI
	EventsStats[%nEvents][%IEI]=V_npnts
	EventsStats[%Avg][%IEI]=v_avg
	EventsStats[%Sdev][%IEI]=v_sdev
	EventsStats[%SEM][%IEI]=v_sdev/sqrt(V_npnts)
	if(V_npnts>2)
		statsQuantiles /q/iNaN IEI
		EventsStats[%Median][%IEI]=v_Median
		EventsStats[%Q25][%IEI]=v_Q25
		EventsStats[%Q75][%IEI]=v_Q75
	else 
		EventsStats[%Median][%IEI]=v_avg
	endif
	
	imagestats /m=2 /g={0,nevents-1,1,1} events
	EventsStats[%nEvents][%baseline]=V_npnts
	EventsStats[%Avg][%baseline]=v_avg
	EventsStats[%Sdev][%baseline]=v_sdev
	EventsStats[%SEM][%baseline]=v_sdev/sqrt(V_npnts)	
	if(V_npnts>2)
		duplicate/o/free/r=[0,*][1] events, calc_Med
		statsQuantiles /q/iNaN calc_Med
		EventsStats[%Median][%baseline]=v_Median
		EventsStats[%Q25][%baseline]=v_Q25
		EventsStats[%Q75][%baseline]=v_Q75
	else 
		EventsStats[%Median][%Baseline]=v_avg
	endif
	
	imagestats /m=2 /g={0,nevents-1,2,2} events
	EventsStats[%nEvents][%amplitude]=V_npnts
	EventsStats[%Avg][%amplitude]=v_avg
	EventsStats[%Sdev][%amplitude]=v_sdev
	EventsStats[%SEM][%amplitude]=v_sdev/sqrt(V_npnts)
	if(V_npnts>2)
		duplicate/o/free/r=[0,*][2] events, calc_Med
		statsQuantiles /q/iNaN calc_Med
		EventsStats[%Median][%amplitude]=v_Median
		EventsStats[%Q25][%amplitude]=v_Q25
		EventsStats[%Q75][%amplitude]=v_Q75
	else 
		EventsStats[%Median][%amplitude]=v_avg
	endif
	
	imagestats /m=2 /g={0,nevents-1,3,3} events
	EventsStats[%nEvents][%abspeak]=V_npnts
	EventsStats[%Avg][%abspeak]=v_avg
	EventsStats[%Sdev][%abspeak]=v_sdev
	EventsStats[%SEM][%abspeak]=v_sdev/sqrt(V_npnts)
	if(V_npnts>2)
		duplicate/o/free/r=[0,*][3] events, calc_Med
		StatsQuantiles /q/iNaN calc_Med
		EventsStats[%Median][%abspeak]=v_Median
		EventsStats[%Q25][%abspeak]=v_Q25
		EventsStats[%Q75][%abspeak]=v_Q75	
	else 
		EventsStats[%Median][%abspeak]=v_avg
	endif
	
	imagestats /m=2 /g={0,nevents-1,4,4} events
	EventsStats[%nEvents][%risetime]=V_npnts
	EventsStats[%Avg][%risetime]=v_avg
	EventsStats[%Sdev][%risetime]=v_sdev
	EventsStats[%SEM][%risetime]=v_sdev/sqrt(V_npnts)
	if(V_npnts>2)
		duplicate/o/free/r=[0,*][4] events, calc_Med
		StatsQuantiles /q/iNaN calc_Med
		EventsStats[%Median][%risetime]=v_Median
		EventsStats[%Q25][%risetime]=v_Q25
		EventsStats[%Q75][%risetime]=v_Q75	
	else 
		EventsStats[%Median][%risetime]=v_avg
	endif
	
	imagestats /m=2 /g={0,nevents-1,5,5} events
	EventsStats[%nEvents][%decaytime]=V_npnts
	EventsStats[%Avg][%decaytime]=v_avg
	EventsStats[%Sdev][%decaytime]=v_sdev
	EventsStats[%SEM][%decaytime]=v_sdev/sqrt(V_npnts)
	if(V_npnts>2)
		duplicate/o/free/r=[0,*][5] events, calc_Med
		StatsQuantiles /q/iNaN calc_Med
		EventsStats[%Median][%decaytime]=v_Median
		EventsStats[%Q25][%decaytime]=v_Q25
		EventsStats[%Q75][%decaytime]=v_Q75	
	else 
		EventsStats[%Median][%decaytime]=v_avg
	endif	
	
	
	imagestats /m=2 /g={0,nevents-1,6,6} events
	EventsStats[%nEvents][%DeltaF]=V_npnts
	EventsStats[%Avg][%DeltaF]=v_avg
	EventsStats[%Sdev][%DeltaF]=v_sdev
	EventsStats[%SEM][%DeltaF]=v_sdev/sqrt(V_npnts)
	if(V_npnts>2)
		duplicate/o/free/r=[0,*][6] events, calc_Med
		StatsQuantiles /q/iNaN calc_Med
		EventsStats[%Median][%DeltaF]=v_Median
		EventsStats[%Q25][%DeltaF]=v_Q25
		EventsStats[%Q75][%DeltaF]=v_Q75	
	else 
		EventsStats[%Median][%DeltaF]=v_avg
	endif	
	

	return EventsStats
end	

/////////////////////////////////////////////////////////////////////////////////

Function/wave MetaEventIEI(MetaEvents)
	Wave MetaEvents
	
	variable nEvents, ii
	
	nEvents=DimSize(MetaEvents,0)
	
	make/o/n=(nEvents) ME_IEI
	ME_IEI=NaN
	
	For(ii=0;ii<nEvents;ii+=1)
	
		if(MetaEvents[ii][%TraceNr] == MetaEvents[ii+1][%TraceNr])
			ME_IEI[ii]=MetaEvents[ii+1][%tPeak]-MetaEvents[ii][%tPeak]
		endif	
	
	endfor
	
	return ME_IEI
end

/////////////////////////////////////////////////////////////////////////////////

Function DB_Eventanalysis(DataBase, bin, durationr,durationd, direction, thr,[df, globalBL,show, verbose, xing])
	wave DataBase
	variable bin, durationr, durationd, direction, thr,df, globalBL, show, verbose,xing
	
	Variable nTraces, ii, isDB, refNum, nEvents
	Variable BaseLine
	String WNote, buffer
	
	//Check optional parameters	
	if(paramisdefault(df))			//calculate as dF/F
		df=1
	endif
	
	if(paramisdefault(xing))		
		xing=0
	endif
	
	if(paramisdefault(globalBL))
		globalBL=0
	endif
	
	if(paramisdefault(show))
		show=0
	endif
	
	if(paramisdefault(verbose))
		verbose=0
	endif
	
	if(verbose)
		Open refNum as "DB_Debug.txt"
		if(refnum==0)
			verbose=0
		endif
		
		printf "Saving log as %s\r", s_filename

	endif
	
	
	WNote=Note(DataBase)
	buffer=StringByKey("LabelList",WNote,"=","\r")
	if(StrLen(Buffer))		//checking if PopWave is an ExpDB
		isDB=1
	else
		isDB=0
	endif
	
	nTraces=DimSize(DataBase,1)
	
	make/o/n=(7,7,nTraces) MetaStats
	
	SetDimLabel 1, 0, IEI, MetaStats
	SetDimLabel 1, 1, Baseline, MetaStats
	SetDimLabel 1, 2, Amplitude, MetaStats
	SetDimLabel 1, 3, absPeak, MetaStats
	SetDimLabel 1, 4, Risetime, MetaStats
	SetDimLabel 1, 5, Decaytime, MetaStats
	SetDimLabel 1, 6, DeltaF, MetaStats
	
	
	SetDimLabel 0,0, Avg, MetaStats
	SetDimLabel 0,1, Sdev, MetaStats
	SetDimLabel 0,2, SEM, MetaStats
	SetDimLabel 0,3, Median, MetaStats
	SetDimLabel 0,4, Q25, MetaStats
	SetDimLabel 0,5, Q75, MetaStats
	SetDimLabel 0,6,nEvents, MetaStats
	


	For(ii=0;ii<nTraces;ii+=1)
	
		if(isDB)
			Wave trace=TraceFromDB(DataBase,ii,df=df)
		else
			duplicate/o/free/r=[0,*][ii,ii] DataBase, trace
			redimension /n=(-1) trace
		endif
	
		wave locEvents=EventDetectionMT(trace, bin, durationr,durationd, direction, thr,globalBL=globalBL, show=show, verbose=0,xing=xing)
		wave locStats=EventStats(locEvents)
	
		if(ii==0)
			duplicate/o locEvents, MetaEvents
		else
			concatenate/o/np=0 {MetaEvents, locEvents}, combinedEvents
			duplicate/o combinedEvents, MetaEvents
		endif
			
	
		MetaStats[][][ii]=locStats[p][q]
	
		
		if(verbose)
			nEvents=dimsize(locEvents,1)
			fprintf refNum, "Detected %g events in line %g\r",nEvents, ii
	
		endif
	
		
		killwaves/z trace, locEvents, locStats, combinedEvents
	EndFor
	
	
	AnnotateMetaEvents(DataBase, MetaEvents, MetaStats)				//adds TraceNr information
	
	if(verbose)
		Close refNum
	endif
	
	killwaves/z fitsd, fitsr, w_StatsQuantiles
End

/////////////////////////////////////////////////////////////////////////////////

Static Function AnnotateMetaEvents(DB, MetaEvents, MetaStats)		//adds TraceNr information
	Wave DB, MetaEvents, MetaStats
	
	variable nEntries, ii, nTraces, currentTrace, start=0, stop
	
	nEntries=dimsize(MetaEvents, 1)
	nTraces=dimsize(MetaStats, 2)
	
	redimension /n=(-1,nEntries+9) MetaEvents
	
	SetDimLabel 1, nEntries, TraceNr, MetaEvents
	SetDimLabel 1, nEntries+1, Age, MetaEvents
	SetDimLabel 1, nEntries+2, Position, MetaEvents
	SetDimLabel 1, nEntries+3, Size, MetaEvents
	SetDimLabel 1, nEntries+4, OnOff, MetaEvents
	SetDimLabel 1, nEntries+5, TSus, MetaEvents
	SetDimLabel 1, nEntries+6, Stim, MetaEvents	
	SetDimLabel 1, nEntries+7, ROINr, MetaEvents
	SetDimLabel 1, nEntries+8, OriginID, MetaEvents
	
	For(ii=0;ii<nTraces;ii+=1)
		if(numtype(MetaStats[%nEvents][%IEI][ii]))	//skip if NaN
			continue
		endif
		stop=start+MetaStats[%nEvents][%IEI][ii]
		
		MetaEvents[start,stop][%TraceNr]=ii
		MetaEvents[start,stop][%Age]=DB[%Age][ii]
		MetaEvents[start,stop][%Position]=DB[%Position][ii]
		MetaEvents[start,stop][%Size]=DB[%Size][ii]
		MetaEvents[start,stop][%OnOff]=DB[%ONOFF][ii]
		MetaEvents[start,stop][%OriginID]=DB[%OriginID][ii]
		MetaEvents[start,stop][%TSus]=DB[%TSus][ii]
		MetaEvents[start,stop][%Stim]=DB[%Stim][ii]
		MetaEvents[start,stop][%ROINr]=DB[%ROINr][ii]
		
		start=stop+1
		
	EndFor
	
end


/////////////////////////////////////////////////////////////////////////////////

Static Function GlobalBaseLine(trace)
	wave trace

	Make/o/free Histo
	Histogram /c/b=3 trace, Histo
	wavestats /q/m=1 histo
		
	return v_maxloc


End

/////////////////////////////////////////////////////////////////////////////////

Function MetaEventsbyAge(MetaEvents, Age)
	wave MetaEvents
	variable Age
	
	variable nEvents, ii, counter=0
	string newName="MEbA"+num2str(Age)
	
	nEvents=DimSize(MetaEvents,0)

	Duplicate/o/free MetaEvents MEbA
	MEbA=NaN

	For(ii=0;ii<nEvents;ii+=1)
	
		if(MetaEvents[ii][%Age]!=Age)
			continue
		endif
		
		MEbA[counter][]=MetaEvents[ii][q]
		counter+=1
	
	EndFor

	if(counter)
		redimension /n=(counter,-1) MEbA
	endif
	
	duplicate/o MEbA $newName

end


/////////////////////////////////////////////////////////////////////////////////

Function MEfilter_Time(MetaEvents, minT, [ResultName])				//remove events at intervals < minT
	Wave MetaEvents
	Variable minT
	String ResultName
	
	Variable nEvents, delta, trace0, trace1, ii, t0, t1, a0, a1, dim
	
	If(ParamIsDefault(ResultName))
		ResultName = NameOfWave(MetaEvents)		//overwrite
	Endif
	
	
	Duplicate/o/free MetaEvents, ME
	
	nEvents = DimSize(MetaEvents, 0)
	dim = DimSize(MetaEvents, 1)
	
	Make/o/free/n=(nEvents) KillEm=0
	
	For(ii=0;ii<nEvents-1;ii+=1)
		trace0=ME[ii][%TraceNr]
		trace1=ME[ii][%TraceNr]
		
		if(trace1-trace0>0)		//comapring different traces
			continue
		endif
		
		t0 = ME[ii][%tPeak]
		t1 = ME[ii+1][%tPeak]
		a0 = ME[ii][%Amplitude]
		a1 = ME[ii+1][%Amplitude]
		
		if(t1-t0<minT)			// delta T smaller than minT
					
			if(a1>a0)			//remove smaller peak
				Killem[ii]=1
			else
				Killem[ii+1]=1
			endif
		endif
		
		
	EndFor

	//Delete points
	For(ii=nEvents-1;ii>=0;ii-=1)		//backwards loop
		If(KillEm[ii])
			DeletePoints/M=0 ii,1,ME
		Endif
	EndFor
	
	//2nd run
		nEvents = DimSize(ME, 0)
		dim = DimSize(ME, 1)
	
	Make/o/free/n=(nEvents) KillEm=0
	
	For(ii=0;ii<nEvents-1;ii+=1)
		trace0=ME[ii][%TraceNr]
		trace1=ME[ii][%TraceNr]
		
		if(trace1-trace0>0)		//comapring different traces
			continue
		endif
		
		t0 = ME[ii][%tPeak]
		t1 = ME[ii+1][%tPeak]
		a0 = ME[ii][%Amplitude]
		a1 = ME[ii+1][%Amplitude]
		
		if(t1-t0<minT)			// delta T smaller than minT
					
			if(a1>a0)			//remove smaller peak
				Killem[ii]=1
			else
				Killem[ii+1]=1
			endif
		endif
		
		
	EndFor

	//Delete points
	For(ii=nEvents-1;ii>=0;ii-=1)		//backwards loop
		If(KillEm[ii])
			DeletePoints/M=0 ii,1,ME
		Endif
	EndFor
		
		
	
	
	
	Duplicate/o ME, $ResultName
End



/////////////////////////////////////////////////////////////////////////////////
//remove events with maxA < amplitude < minA (set NaN for no min or max amplitude)
//e.g.,  MEfilter_Amplitude(MetaEvents, 0.5, NaN)

Function MEfilter_Amplitude(MetaEvents, minA, maxA, [ResultName])			
	Wave MetaEvents
	Variable minA, maxA
	String ResultName
	
	Variable nEvents, delta, a0, dim, ii
	
	If(ParamIsDefault(ResultName))
		ResultName = NameOfWave(MetaEvents)		//overwrite
	Endif
	
	
	Duplicate/o/free MetaEvents, ME
	
	nEvents = DimSize(MetaEvents, 0)
	dim = DimSize(MetaEvents, 1)
	
	Make/o/free/n=(nEvents) KillEm=0
	
	For(ii=0;ii<nEvents;ii+=1)
		a0 = ME[ii][%Amplitude]
	
		if(a0<minA)
			KillEm[ii]=1
		elseif(a0>maxA)
			KillEm[ii]=1
		else
			KillEm[ii]=0
		endif
		
		
	EndFor

	//Delete points
	For(ii=nEvents-1;ii>=0;ii-=1)		//backwards loop
		If(KillEm[ii])
			DeletePoints/M=0 ii,1,ME
		Endif
	EndFor
		
	
	
	
	Duplicate/o ME, $ResultName
End


/////////////////////////////////////////////////////////////////////////////////
//remove events with maxA < absPeak < minA (set NaN for no min or max amplitude)
//e.g.,  MEfilter_Amplitude(MetaEvents, 0.5, NaN)

Function MEfilter_absPeak(MetaEvents, minA, maxA, [ResultName])			
	Wave MetaEvents
	Variable minA, maxA
	String ResultName
	
	Variable nEvents, delta, a0, dim, ii
	
	If(ParamIsDefault(ResultName))
		ResultName = NameOfWave(MetaEvents)		//overwrite
	Endif
	
	
	Duplicate/o/free MetaEvents, ME
	
	nEvents = DimSize(MetaEvents, 0)
	dim = DimSize(MetaEvents, 1)
	
	Make/o/free/n=(nEvents) KillEm=0
	
	For(ii=0;ii<nEvents;ii+=1)
		a0 = ME[ii][%absPeak]
	
		if(a0<minA)
			KillEm[ii]=1
		elseif(a0>maxA)
			KillEm[ii]=1
		else
			KillEm[ii]=0
		endif
		
		
	EndFor

	//Delete points
	For(ii=nEvents-1;ii>=0;ii-=1)		//backwards loop
		If(KillEm[ii])
			DeletePoints/M=0 ii,1,ME
		Endif
	EndFor
		
	
	
	
	Duplicate/o ME, $ResultName
End




