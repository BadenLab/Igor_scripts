#pragma rtGlobals=1		// Use modern global access method.
#include <ImageSlider>

//Function Pop2Movie(PoP,ROI,Stack3D,[name]) makes a new 3D stack called name
//(default: nameofwave(Stack3D)+"_mov") where it displays the values in the populationwave
//pop in the location of each respective ROI in wave ROI.

Function Pop2Movie(PoP,ROI,Stack3D,[name])

wave pop, roi, Stack3D
string name

wavestats /q /m=1 roi
variable ROInumber=abs(v_min)

if(paramisdefault(name))
	name=nameofwave(Stack3D)+"_mov"
endif


duplicate/o Stack3D, Mov_calcwave
duplicate /o PoP, PoP_smth

smooth /dim=0 5, PoP_smth

variable counter, framecount

for (framecount=0;framecount<dimsize(Stack3D,2);framecount+=1)
		
	Mov_Calcwave[][][framecount]=selectnumber(ROI[p][q]==1,PoP_smth[framecount][abs(ROI[p][q]+1)],NaN)	
		
endfor

wavestats /q /m=1 mov_calcwave

	Mov_calcwave=selectnumber(numtype(Mov_calcwave[p][q][r])==2,Mov_calcwave[p][q][r],v_min)	//cooment this line out if you want to have the background set to NaN rather than v_min


duplicate /o mov_calcwave, $name
killwaves /z mov_calcwave, pop_smth
end

//////////////////////////////////////////////////

Function MakeMoviePresentable(Stack3D, LuT,[name])

wave stack3D, LuT
string name

string name2

if(paramisdefault(name))
	name=nameofwave(Stack3D)+"_nice"
	name2=nameofwave(Stack3D)+"_niceLUT"
else
	name2=name+"_LUT"
endif

duplicate /o Stack3D MMP_calcwave
duplicate /o LuT, MMP_LuT
wavestats /q /m=1 Stack3D

setscale /i x,v_min, v_max, "" MMP_Lut


duplicate /o MMP_calcwave $name
duplicate /o MMP_Lut $name2

display;delayupdate
appendimage $name;delayupdate
WMAppend3DImageSlider();delayupdate
ModifyGraph noLabel=2,axThick=0,standoff=0;delayupdate
ModifyGraph height=300, width=300; delayupdate
ModifyImage $name cindex=$name2;delayupdate
SetDrawEnv xcoord= bottom,linefgc= (65535,65535,65535),linethick= 3.00;DelayUpdate
DrawLine 5,0.9,30,0.9;DelayUpdate

Print "Scalebar = 25 µm"

killwaves/z MMP_calcwave, MMP_LuT
end


////////////////////////////////////////////////

Function AddStimToMovie(movie, stimulus, x1,y1,size, name)
wave movie, stimulus
variable x1,y1,size
string name

wavestats /q /m=1 movie

variable ii, xpos, ypos, timepoint, spot=v_max, xsize, ysize

duplicate /o movie, StimMovie
duplicate /o stimulus, interp_stim

redimension /n=(dimsize(movie,2)) interp_stim
setscale /i x,dimoffset(movie,2), dimdelta(movie,2)*dimsize(movie,2)-dimoffset(movie,2), WaveUnits(movie,2) interp_stim

interpolate2 /i=3 /t=1 /y= interp_stim stimulus

xpos = round((x1-DimOffset(movie,0))/Dimdelta(movie,0))
ypos = round((y1-Dimoffset(movie,1))/Dimdelta(movie,1))
Xsize=round(size/dimdelta(movie,0))
Ysize=round(size/dimdelta(movie,1))

for(ii=0;ii<numpnts(interp_stim);ii+=1)

	if(interp_stim[ii]>0)
		
		StimMovie[xpos,xpos+XSize][yPos,YPos+YSize][ii] = spot *  interp_stim[ii]		//scales stimulus
	
	endif

endfor

duplicate /o StimMovie $name
killwaves /z interp_stim, StimMovie

end


////////////////////////////////////////////////



 Function Pop2MovieFromMenu()
 
 
string pop, roi, Stack3D, LuT, Stimulus
variable x1,y1,size

Prompt pop, "The Populationwave that contains the data", popup,WaveList("*",";","DIMS:2")
Prompt roi, "The ROI wave", popup,WaveList("*ROI*",";","DIMS:2")
Prompt Stack3D, "The original Image Stack",popup,WaveList("*",";","DIMS:3")
Prompt LuT, "A fancy lookup table",popup,WaveList("*",";","DIMS:2,MINCOLS:3,MAXCOLS:3")

DoPrompt "Give me something to work on", stack3d,pop,roi,lut

string result=stack3d+"_mov"

if(v_flag)
	return -1		// user abort
endif

Prompt Stimulus, "A wave containing the stiumulus (0/1)", popup, WaveList("*",";","DIMS:1")+"_none_"
prompt x1, "Lower left X coordinate of the stimulus spot (scaled)"
prompt y1, "Lower left Y coordinate of the stimulus spot (scaled)"
prompt size, "Size of the stimulus spot (scaled)"

DoPrompt "Is there more work?", Stimulus, x1,y1,size 

if(v_flag)
	return -1		// user abort
endif


 Pop2Movie($PoP,$ROI,$Stack3D)
 MakeMoviePresentable($result, $LuT)
 
 result=result+"_nice"
 
 if (stringmatch(Stimulus, "_none_"))
 	return 1
 else
 
	AddStimToMovie($result, $stimulus, x1,y1,size, result)
 
 endif


End

////////////////////////////////////////////////

Function SmoothPoP(PoP, value)
wave pop
variable value

variable ii

duplicate Pop, smth_calc, line, des
redimension/n=(-1) line, des

for(ii=0;ii<dimsize(pop,1);ii+=1)

	line[]=pop[p][ii]
	//Loess /dest=des /r=1 /smth=(value) srcWave= line
	 
	smth_calc[][ii]=des[p]

endfor



string name=nameofwave(pop)+"_smth"
duplicate /o smth_calc, $name
killwaves /z smth_calc, line, des

end
 