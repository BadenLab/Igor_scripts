#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

// dif_image(image, [targetname]) calculates the Laplace operator (2nd derivative of image in the x and y
// axis and adds them). The optional parameter targetname is the name of the so calculated
// image. If left out, the name will be nameofwave(image)+"_dif".
//
// mod_img(image, i_limit, [targetname]) performs (negative) thresholding on image:
// First, pixels with a value larger than -i_limit will be set 1 (outside ROI), then those with
// a value <= 0 will be set 0 (inside ROI.)
// The optional parameter targetname is the name of the so calculated
// image. If left out, the name will be nameofwave(image)+"_mod".
//
//dif_image3D (image, [targetname]) calculates the 2nd derivative of the voluma data image in the x, y and z axis
//and sums them. The optional parameter targetname is the name of the so calculated image. If left out, the name 
//will be nameofwave(image)+"_dif".
//
//difloop (imagestack, [targetname]) calculates the 2nd derivative of imagestack in the x and y axis and sums them
// for each frame. The optional parameter targetname is the name of the so calculated image. If left out, the name will 
//be nameofwave(image)+"_dif".
//
//  xydif_image(image, [targetname]) calculates the 1st derivative of image in the x and y
// axis, and thus returns two images. The optional parameter targetname is the name of the so calculated
// images which "_x" and "_y" appended to their names. If left out, the names will be nameofwave(image)+"_difx"
// and nameofwave(image)+"_dify".


function/wave dif_image(image, [targetname, free])

	wave image
	string targetname
	variable free
	
	if(paramisdefault(targetname))
		targetname = nameofwave(image)+"_dif"
	endif
	
	if(paramisdefault(free))
		free=0
	endif
	
	
		differentiate /dim=0 image /d=dif_x
		differentiate /dim=0 dif_x
		differentiate /dim=1 image /d=dif_y
		differentiate /dim=1 dif_y
		
		duplicate /o dif_x, dif_xy
		fastop dif_xy = dif_x + dif_y
	
	if(free>0)
		duplicate /o/free dif_xy, w_del2
		killwaves /z dif_x,dif_y,dif_xy
		return w_del2
	else
		duplicate /o dif_xy, $targetname
		killwaves /z dif_x,dif_y,dif_xy
		return $targetname
	endif
	
	
end

/////////////////////////////////////////

function xydif_image(image, [targetname])


wave image
string targetname

string yname

if(paramisdefault(targetname))
	targetname = nameofwave(image)+"_difx"
	yname = nameofwave(image)+"_dify"
	
else
	yname = targetname+"_y"
	targetname = targetname+"_x"
	
endif


	differentiate /dim=0 image /d=dif_x
	differentiate /dim=1 image /d=dif_y
	
	
duplicate /o dif_x, $targetname
duplicate /o dif_y, $yname

killwaves /z dif_x,dif_y,dif_xy
end

///////////////////////////////////////////////////////////////

function/wave dif_image3D(image, [targetname])		//Calculates Laplace operator on volume data

	wave image
	string targetname
	
	if(paramisdefault(targetname))
		targetname = nameofwave(image)+"_dif"
	endif
	
	
		differentiate /dim=0 image /d=dif_x
		differentiate /dim=0 dif_x
		differentiate /dim=1 image /d=dif_y
		differentiate /dim=1 dif_y
		differentiate /dim=2 image /d=dif_z
		differentiate /dim=2 dif_z
		
		duplicate /o dif_x, dif_xyz
		fastop dif_xyz = dif_x + dif_y + dif_z
	
	
	duplicate /o dif_xyz, $targetname
	
	killwaves /z dif_x,dif_y,dif_xyz, dif_z
	return $Targetname
end


///////////////////////////////////////////////////////////////

function/wave difloop(imagestack,[targetname])				//calculates Laplace operator frame by frame
	wave imagestack
	string targetname
	
	variable zdim = dimsize(imagestack,2), ii
	string outname
	
	if(ParamIsDefault(targetname))
		outname = nameofwave(imagestack)+"_dif"
	else
		outname = targetname
	endif
	
	if (zdim<1)
		zdim = 1
	endif
	
	duplicate/o/free imagestack, difimagestack, image
	redimension/n=(-2,-2) image
	
	for(ii=0;ii<zdim;ii+=1)
	
		duplicate/o/r=[0,*][0,*][ii]/free imagestack image
		
		differentiate /dim=0 image /d=dif_x
		differentiate /dim=0 dif_x
		differentiate /dim=1 image /d=dif_y
		differentiate /dim=1 dif_y
		
		if(ii==0)
			duplicate /o dif_x, dif_xy
		endif
		fastop dif_xy = dif_x + dif_y
		
		difimagestack[][][ii] = dif_xy[p][q]
	
	endfor
	
	duplicate/o difimagestack $outname
	
	
	killwaves/z dif_x, dif_y, dif_xy, difimagestack
	return $outname
end

/////////////////////////////////////////

function/wave mod_img(image, i_limit, [targetname, free])
	wave image
	variable i_limit, free
	string targetname
	
	
	if(paramisdefault(targetname))
		targetname = nameofwave(image)+"_mod"
	endif
	
	if(paramisdefault(free))
		free=0
	endif
	
	MatrixOP/o/free calcwave= greater(image, -i_limit)
	
	if(free>0)
		duplicate /o/free calcwave, w_mod
		return w_mod
	else
		duplicate /o calcwave, $targetname
		return $targetname
	endif

end