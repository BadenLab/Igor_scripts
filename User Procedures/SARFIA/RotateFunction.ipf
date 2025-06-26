#pragma rtGlobals=1		// Use modern global access method.

//shift to origin - rotate - shift back

Function RotateFunction1(func, angle,CenterX,CenterY)		//x values are taken from wave scaling)

wave func
variable angle, CenterX, CenterY

angle*=pi/180

duplicate /o func, rot_X, rot_Y, calc_x, calc_y
calc_X=dimoffset(func,0)+p*dimdelta(func,0)

calc_x-=centerx
calc_y-=centery

variable counter

for (counter=0;counter<numpnts(func); counter+=1)

	MultiThread rot_x[counter]=calc_x[counter]*cos(angle)-calc_y[counter]*sin(angle)
	MultiThread rot_y[counter]=-calc_x[counter]*sin(angle)+calc_y[counter]*cos(angle)

endfor

rot_x+=centerx
rot_y+=centery

killwaves /z calc_x, calc_y

end


//////////////////////////

Function RotateFunction2(Xfunc,Yfunc,angle,CenterX,CenterY)
wave xfunc,yfunc
variable angle, CenterX, CenterY

angle*=pi/180

if(numpnts(xfunc)!=numpnts(yfunc))
	doalert 1, "X and Y functions have different number of points! Continue?"
	if(v_flag==2)
		return -1
	endif
endif

variable counter
duplicate /o Xfunc, rot_X, calc_x
duplicate /o Yfunc, rot_Y, calc_y

calc_x-=centerx
calc_y-=centery



for (counter=0;counter<numpnts(xfunc); counter+=1)
	
	MultiThread rot_x[counter]=calc_x[counter]*cos(angle)-calc_y[counter]*sin(angle)
	MultiThread rot_y[counter]=-calc_x[counter]*sin(angle)+calc_y[counter]*cos(angle)

endfor

rot_x+=centerx
rot_y+=centery

killwaves /z calc_x, calc_y
end


//////////////////////////

Function RotateImage(image,angle)
	wave image
	variable angle
	
	angle=mod(angle,360)
	if(angle < 0)
		angle = 360 + angle
	endif
	
	angle*=pi/180
	
	variable xDim, yDim, NewXDim,NewYDim,zDim, ii, angle2
	variable XSF, YSF, xOff, yOff
	xDim=Dimsize(image,0)
	yDim=DimSize(image,1)
	zDim=DimSize(image,2)
	
	angle2=mod(angle,pi/2)
	
	NewXDim=ceil(xDim*abs(cos(angle))+yDim*abs(sin(angle)))			//calculate size of rotated image in x
	NewYDim=ceil(xDim*abs(sin(angle))+yDim*abs(cos(angle)))			//calculate size of rotated image in y
	
	
	Make /o/free/n=(NewxDim,NewYDim,2) c_RotationMatrix = NaN
	
	MultiThread c_RotationMatrix[][][0]=round((p-Newxdim/2)*cos(angle)-(q-Newydim/2)*sin(angle))+xDIm/2		//calculate new x location of pixels
	MultiThread c_RotationMatrix[][][1]=round((q-Newydim/2)*cos(angle)+(p-Newxdim/2)*sin(angle))+YDim/2		//calculate new y location of pixels
	
	
	make /o/n=(NewXDim,NewYDim,ZDim) W_RotatedImage = NaN
	
	MultiThread W_RotatedImage = Image[C_RotationMatrix[p][q][0]][C_RotationMatrix[p][q][1]][r]		//assign pixel values to their new location
	
	MultiThread W_RotatedImage = Selectnumber((C_RotationMatrix[p][q][0]<0 || C_RotationMatrix[p][q][0] >XDim)|(C_RotationMatrix[p][q][1]<0 || C_RotationMatrix[p][q][1] >YDim), W_RotatedImage[p][q][r],NaN)	//Removing Pixels outside original image
	
	XSF=abs(cos(angle))*dimdelta(image,0)*dimsize(image,0)+abs(sin(angle))*dimdelta(image,1)*dimsize(image,1)		//calculate scale factors
	YSF=abs(sin(angle))*dimdelta(image,0)*dimsize(image,0)+abs(cos(angle))*dimdelta(image,1)*dimsize(image,1)
	
	
	xOff=DimOffset(image,0)*abs(cos(angle))+DimOffset(image,1)*abs(sin(angle))		//calculate offsets
	yOff=DimOffset(image,1)*abs(cos(angle))+DimOffset(image,0)*abs(sin(angle))
	
	
	
	setscale /i x,xOff,XSF,WaveUnits(Image,0) W_RotatedImage		//apply new scaling
	setscale /i y,yOff,YSF,WaveUnits(Image,1) W_RotatedImage


End


//////////////////////////

Function RotateCoM(CoM,image,angle)
Wave CoM, Image
Variable angle

angle*=-pi/180

variable xdim, ydim, NewXDim, NewYDim
xdim=DimSize(image,0)*dimdelta(image,0)
ydim=DimSize(image,1)*dimdelta(image,1)


NewXDim=(xDim*abs(cos(angle))+yDim*abs(sin(angle)))
NewYDim=(xDim*abs(sin(angle))+yDim*abs(cos(angle)))

Duplicate /o CoM, CoM_rot

MultiThread CoM_rot[][0]=((CoM[p][0]-xdim/2)*cos(angle)-(CoM[p][1]-ydim/2)*sin(angle))+newxDIm/2
MultiThread CoM_rot[][1]=((CoM[p][1]-ydim/2)*cos(angle)+(CoM[p][0]-xdim/2)*sin(angle))+newYDim/2

print xdim, newxdim

End