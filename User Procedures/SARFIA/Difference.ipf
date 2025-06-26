#pragma rtGlobals=1                // Use modern global access method.
#include "z-project"

function GetTimes(stack3d, name)

wave stack3d
string name
Variable startbaselineT, stopbaselineT, startresponseT, stopresponseT, deltaTime
Variable startbaselineF, stopbaselineF, startresponseF, stopresponseF

        Prompt startbaselineT, "Time for start of baseline (s): "                // Set prompt for start of baseline 
        Prompt stopbaselineT, "Time for end of baseline (s): "                // Set prompt for end of baseline 
        Prompt startresponseT, "Time for start of response (s): "                // Set prompt for start of response
        Prompt stopresponseT, "Time for end of response (s): "                // Set prompt for end ofresponse 
        
        DoPrompt "Enter times please!", startbaselineT, stopbaselineT, startresponseT, stopresponseT

        if (V_Flag)
                return -1                                                                // User canceled
        endif

deltaTime=DimDelta(stack3d, 2)

startbaselineF=round(startbaselineT/deltaTime)
stopbaselineF=round(stopbaselineT/deltaTime)
startresponseF=round(startresponseT/deltaTime)
stopresponseF=round(stopresponseT/deltaTime)
 
RunDifference(stack3D,  startbaselineF, stopbaselineF, startresponseF, stopresponseF)

string DifImageName, AbsDifImageName
DifImageName=NameOfWave(stack3D)+"_RES"

duplicate /o $difimagename thr2
thr2=abs(thr2)

duplicate /o thr2 $name

killwaves /z thr2 
return 1
end

/////////////////////////////////////


function RunDifference(stack3D, startbaselineF, stopbaselineF, startresponseF, stopresponseF)

	variable startbaselineF, stopbaselineF, startresponseF, stopresponseF
	wave stack3D
	string DifImageName
	
	Variable blFrames, RFrames
	
	DifImageName=NameOfWave(stack3D)+"_RES"
	Duplicate/O stack3D baselineAVG, responseAVG
	Redimension/N=(-1, -1) baselineAVG, responseAVG
	Duplicate/O baselineAVG DifImage
	Duplicate/O/R=[][][startbaselineF, stopbaselineF] stack3D baselineAVG
	Duplicate/O/R=[][][startresponseF, stopresponseF] stack3D responseAVG
	
	blFrames=DimSize(baselineAVG,2)
	RFrames=DimSize(responseAVG,2)
	
	if(blFrames == 1)		//can't average only one frame
		redimension/n=(-1,-1) baselineAVG
		Duplicate/o baselineAVG baselineImage
	else
		avgZ(baselineAVG, "baselineImage")
		wave baselineImage
	
	endif
	
	if(RFrames == 1)		//can't average only one frame
		redimension/n=(-1,-1) responseAVG
		duplicate/o responseAVG responseImage
	else
		avgZ(responseAVG, "responseImage")
		wave responseImage
	endif	
	
	Duplicate/O responseImage DifImage
	DifImage = responseImage-baselineImage
	
	Duplicate/O DifImage $DifImageName
	KillWaves/Z baselineAVG, responseAVG, DifImage
end

