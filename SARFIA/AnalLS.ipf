#pragma rtGlobals=1		// Use modern global access method.
#include "LoadScanImage"

//	AnalLS analyses linescan data generated with ScanImage. These are usually
//	present as image stacks, only that different lines in an image represent
//	subsequent recordings.
//	LSwave is the image(stack) containing the data. Start and stop are the left
//	and right borders in pixels (!) of the ROI to be analysed. The resulting wave
//	will be named nameofwave(LSwave)+"_LS"
//
//	CallAnalLS() calls the AnalLS function and prompts the user for input.

Function/wave AnalLS(LSwave, start, stop)
	wave LSwave
	variable start, stop
	
	variable lines, pixels, sheets, lcount, scount, counter=0, spl
	
	lines = dimsize(lswave,1)
	pixels = dimsize(lswave,0)
	sheets = dimsize(lswave,2)
	
	
	if (sheets < 1)	// sheets = 0, if there is only one frame.
		sheets = 1	// --> to get the right number of points in the result wave.
	endif
	
	make /d/o/n=(lines*sheets)/free LSresult
	
	spl = sPerLineFromHeader(LSwave)
	
	if (NumType(spl) == 0)	//x dimension data in the header?
		setscale /p x,0,sPl,"s" LSresult
	else
		setscale /p x,dimoffset(LSWave,1),DimDelta(LSWave,1),WaveUnits(LSWave,1) LSresult
	endif
	
	
		
	for(scount=0;scount<sheets;scount+=1)
		for(lcount=0;lcount<lines;lcount+=1)
			
			ImageStats /m=1/p=(scount)/g={start,stop,lcount,lcount} LSwave
			
			if (v_flag <0)
				doalert 0, "Error with ImageStats in AnalLS"
				print scount, lcount
				Abort
			endif
			LSresult[counter]=v_avg
			counter +=1			
		endfor
	endfor
	
	
	string wvname = nameofwave(LSwave)+"_LS"
	
	duplicate /o lsresult, $wvname
	return $wvname
end


function CallAnalLS()

string wv
variable start, stop
string wvlist =  WaveList("*",";","DIMS:3")+";"+WaveList("*",";","DIMS:2")

prompt wv, "LineScan wave", popup, wvlist
prompt start, "Left point of ROI"
prompt stop, "Right point of ROI"

doprompt /help="AnalLS" "Analyze Linescan", wv,start,stop

if(v_flag)
	return -1
endif

if(start < stop)
	AnalLS($wv, start, stop)
else
	AnalLS($wv, stop,start)
endif
end