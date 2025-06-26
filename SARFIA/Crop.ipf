#pragma rtGlobals=1		// Use modern global access method.

//CropXYFromWindow () 
//For this function to work, a marquee must be drawn on the top window. 
//When this function is called, the top image or image stack will be cropped 
//along the borders delimited by the marquee. For added educational value, the 
//function also prints the appropriate Duplicate command in the command line. 
//The cropped image will be saved as w_Cropped.
//
//CropZFromWindow () 
//When this function is called, a popup menu appears for the user to specify the
//first and last frame, either in frame numbers or scaled variables. The top image
//stack will be cropped accordingly. For added educational value, the function also
//prints the appropriate Duplicate command in the command line. The cropped image
//will be saved as w_Cropped.


Function CropXYFromWindow()

	string Twname=WinName(0,1,1)	
	string topwave
	
	if(stringmatch(TWname,""))
		return -1
	endif
	
	GetWindow $TWname, wavelist
		wave /t w_wavelist
	
		topwave = w_wavelist[0][0]
		
		Wave im = $topwave
	
	GetMarquee /w=$TWname left, bottom
	
	if(v_flag==0)
		DoAlert 0, "No Marquee found"
		return -1
	endif
	
	variable x1, x2, y1, y2
	variable xx1, xx2, yy1, yy2
	
	xx1= (v_left - DimOffset(im,0)) / DimDelta(im,0)
	xx2=(v_right - DimOffset(im,0)) / DimDelta(im,0)
	yy1= (v_bottom - DimOffset(im,1)) / DimDelta(im,1)
	yy2= (v_top - DimOffset(im,1)) / DimDelta(im,1)

	x1=Round(Min(xx1,xx2))
	x2=Round(Max(xx1,xx2))
	y1=Round(Min(yy1,yy2))
	y2=Round(Max(yy1,yy2))

	Duplicate/o/r=[x1,x2][y1,y2][0,*] im w_Cropped
	
	Printf "Duplicate/O/R=[%g,%g][%g,%g] %s w_Cropped\r", x1,x2,y1,y2,topwave

End

/////////////////////////////////////////////////

Function CropZFromWindow()

	string Twname=WinName(0,1,1)
	string topwave
	
	
	if(stringmatch(TWname,""))
		return -1
	endif
	
	GetWindow $TWname, wavelist
		wave /t w_wavelist
	
		topwave = w_wavelist[0][0]
		
		Wave im = $topwave
	
	
	variable zdim=DimSize(im,2)
	
	if(zdim<2)
		DoAlert 0, "No more cropping possible"
		return -1
	endif
		
	
	variable z1, z2, scaled = 0
	
	Prompt z1, "First frame"
	Prompt z2, "Last frame"
	Prompt scaled, "Are frames scaled (i.e. seconds, meters, etc.)? (0/1)"
	
	DoPrompt "Enter variables", z1, z2, scaled
	
	if(v_flag)
		return -1
	endif
	
	if(scaled)
	
		z1= (z1 - DimOffset(im,2)) / DimDelta(im,2)
		z2=(z2 - DimOffset(im,2)) / DimDelta(im,2)
	endif

	Duplicate/o/r=[0,*][0,*][z1,z2] im w_Cropped
	
	Printf "Duplicate/O/R=[0,*][0,*][%g,%g] %s w_Cropped\r",round( z1),round(z2),topwave

End