#pragma rtGlobals=1		// Use modern global access method.
#include <ImageSlider>

//Launches a control panel to create a lookup table for a grayscale graph
//to change the gamma. This does not change tha actual values of the image!

function DisplayGammaCorrCP()


variable left = 500, top = 0
variable /g g_Gamma = 1
string /g  g_windowname
string /g g_picwavename

g_windowname = WinName(0,1)
getwindow $g_windowname, wavelist
wave /t W_WaveList
g_picwavename = W_WaveList[0]

print g_picwavename

getminmax($g_picwavename)

variable /g g_min, g_max

NewPanel /K=1 /N=GammaCorrCP /W = (left,top,left+330, top+200) as "Gamma Adjustment"
Groupbox GBx1 pos={5,5}, size={320,190}
Button SaveButton pos={20, 160}, size = {100,20}, proc = GCCPButton, title = "Keep Settings"
Button CancelButton pos={230, 160}, size = {80,20}, proc = GCCPButton, title = "Revert"
setvariable GammaVar pos={20, 35}, size = {200,20}, win =GammaCorrCP, proc = GCCP_VC, limits = {0,inf,0.05}, value = g_Gamma, title = "Gamma Value", fsize = 12
//Popupmenu Waveselect pos={220,70}, bodywidth=180, mode=1, proc=GCCPPop, title="Image or Stack", popvalue="Select", value=WaveList("*",";","TEXT:0")

string cindexstring =g_picwavename+"_LUT"


imagegamma(g_gamma)

dowindow /f $g_windowname
ModifyImage $g_picwavename cindex= $cindexstring; delayupdate
//if (dimsize(picwave, 2))
//	WMAppend3DImageSlider();
//endif
doupdate

end

/////////////////////Button Control/////////////////
Function GCCPButton(ctlname) : ButtonControl
string ctlname
string /g g_windowname, g_picwavename

strswitch(ctlname)
	case "CancelButton":
		dowindow /f $g_windowname
		modifyimage $g_picwavename ctab={*, *, Grays, 0 }
		killwaves /z ROI_calcwave
		If (WinType("ManualThreshold"))
			killwindow ManualThreshold
		endif
		killvariables /z g_Gamma, g_min, g_max, g_gcpic
		killstrings /z g_windowname, g_picwavename
		killwindow GammaCorrCP
		DoUpdate

	break
	case "SaveButton":			//<------------------
	killwaves /z ROI_calcwave
		If (WinType("ManualThreshold"))
			killwindow ManualThreshold
		endif
		killvariables /z g_Gamma, g_min, g_max, g_gcpic
		killstrings /z g_windowname, g_picwavename
		killwindow GammaCorrCP
		DoUpdate
	break
	
	

	
	
	default:
	print "Undefined Button in GammaCorrCP:", ctlname
	break
endswitch




end

//////////////////////////Variable Control////////////////////////

Function GCCP_VC (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	variable /g g_Gamma
	
	
	string /g g_windowname
	
	strswitch(ctrlname)
	case "GammaVar":
		g_Gamma = varnum
		ImageGamma(g_Gamma)
		//dowindow/f $g_windowname
	break

	default:
		print "Undefinded variable set:", ctrlname
	break
	endswitch
End
////////////////////////MinMax/////////////////////////
static function GetMinMax(image)
wave image
//variable xdim, ydim, zdim, minval, maxval, xcount, ycount, zcount


imagestats /M=1 image

variable /g g_min = v_min
variable /g g_max = v_max

end
////////////////////////Image Update////////////////////
function GCCP_Update()



end
/////////////////////Gamma/////////////////////////////


function ImageGamma(gammavalue)

variable gammavalue
variable /g g_min, g_max
string /g g_picwavename

string LUT =  g_picwavename+"_LUT"

variable range, counter, gammastep

range = g_max - g_min

gammastep = 1 / range

make /o/n=(ceil(range),3) IG_tempwave

for (counter=0;counter<(ceil(range));counter+=1)

	IG_tempwave[counter][0] =  65535*(gammastep*counter)^gammavalue	//--> max = 65535!
	IG_tempwave[counter][1] = 65535*(gammastep*counter)^gammavalue
	IG_tempwave[counter][2] = 65535*(gammastep*counter)^gammavalue

endfor

	IG_tempwave[(ceil(range))][0] =  65535
	IG_tempwave[(ceil(range))][1] = 65535
	IG_tempwave[(ceil(range))][2] = 65535

duplicate /o IG_tempwave $LUT
killwaves /z IG_tempwave
end

