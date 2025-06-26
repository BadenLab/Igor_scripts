#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

#include "NaNBust"
#include "MultiROI"

//edit 20150520: Cleaned up for new 3D support

// ROISize(ROIwave) generates a wave called Size that stores the size in pixels for each ROI
// RemoveROI(ROIwave,  threshold) Removes all ROIs smaller or equal to threshold, stores the result in a wave called ROI_edit
// RenumberROI(ROIwave) renumbers ROIs to account for deleted ones (runs automattically in RemoveROI)
// CAUTION: These functions run slow, especially when used on high resolution images!


Function/wave ROISize(ROIstack,[resultname])		//should work with 2D and 3D images
	wave ROIstack
	string resultname
	
	Variable  ROInumber
	
	duplicate/o/free ROIstack, ROIWave
	
	
	ROIWave=selectnumber(ROIwave[p][q][r]>=0,ROIwave[p][q][r],NaN)	//replace >0 with NaN	
	
		wavestats /q/m=1 ROIwave
		ROInumber =abs(v_min)-abs(v_max)+1
		
		make /o/n=(ROINumber)/free Histo
		
		Histogram/b={v_max,-1,ROINumber} ROIWave, Histo
		

		
	if(paramisdefault(resultname))
		resultname=nameofwave(ROIWave)+"_ROISize"
	endif
		
	
	
	
	duplicate/o Histo $ResultName
	wave w = $resultname
	return w
end


//////////////////////////////////////////////

function RemoveROI(ROIwave,  threshold)
	wave ROIwave
	variable threshold
	
	wave size=ROIsize(roiwave)
	
	variable ii, np, counter = 0
	
	np=numpnts(size)
	
	duplicate /o roiwave ROI_edit
	duplicate /o/free roiwave ROI_edit2
	
	for(ii=0;ii<np;ii+=1)
	
		if(size[ii] <= threshold)
			
			MatrixOP /o ROI_edit2 = Replace(ROI_edit,-ii-1,1)
			FastOP ROI_Edit = ROI_Edit2				//MatrixOP doesn't accept the same 3D wave left and right
		else
			counter +=1
		endif
		
	endfor
	
//	if((counter>0) && WaveDims(ROIWave) == 2)		//edit 20140520: no longer needed with new 3D support
		MultiROI(ROI_edit, "ROI_edit")
//	elseif((counter>0) && WaveDims(ROIWave) == 3)
//		MultiROIbyLayer(ROI_edit, "ROI_edit")
//	endif
	
	killwaves/z size
	return counter
end

//////////////////////////////////////


function/wave invRemoveROI(ROIwave,  threshold, [free])		//copies over ROIs bigger than threshold, rather than removing small ones
	wave ROIwave
	variable threshold, free
	
	if(ParamIsDefault(free))
		free=0
	endif
	
	wave size=ROIsize(roiwave)
	
	variable ii, np, counter
	
	np=numpnts(size)
	counter=np
	
	if(free>0)
		duplicate /o/free roiwave ROI_edit
	else
		duplicate /o roiwave ROI_edit
	endif
	
	FastOP ROI_edit=1
	duplicate /o/free roi_edit ROI_edit2

	
	for(ii=0;ii<np;ii+=1)
	
		if(size[ii] > threshold)
			
			MatrixOP /o ROI_edit2 = ROI_edit-equal(roiwave,-ii-1)
			FastOP ROI_Edit = ROI_Edit2				//MatrixOP doesn't accept the same 3D wave left and right
		else
			counter -=1
		endif
		
	endfor
	
	if((counter>0) && WaveDims(ROIWave) == 2)
		MultiROI(ROI_edit, "ROI_edit")
	elseif((counter>0) && WaveDims(ROIWave) == 3)
		MultiROIbyLayer(ROI_edit, "ROI_edit")
	endif
	
	killwaves/z size
	return ROI_edit
end



//////////////////////////////////////////////


Function ClearROIMarquee()

string Twname=WinName(0,1,1)
string topwave

if(stringmatch(TWname,""))
	return -1
endif

GetWindow $TWname, wavelist
	wave /t w_wavelist

	topwave = w_wavelist[0][1]		//update 20120319: full path to wave 

GetMarquee /w=$TWname left, bottom

if(v_flag==0)
	DoAlert 0, "No Marquee found"
	return -1
endif

variable y_bottom, y_top

y_bottom = (v_bottom-dimoffset($topwave,1))/DimDelta($topwave,1)
y_top = (v_top-dimoffset($topwave,1))/DimDelta($topwave,1)

SetToOne($topwave, x2pnt($topwave, v_left), x2pnt($topwave, v_right), y_bottom, y_top)

multiroi($topwave,topwave)		//renumbers and detects newly separated ROIs

End

/////////////////////////////////////

Static Function SetToOne(wv,x0,x1,y0,y1)

wave wv
variable x0,x1,y0,y1

wv[x0,x1][y0,y1]=1


end

//////////////////////////////////////////////