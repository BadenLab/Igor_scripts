#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Author: Simen Bruoygard 
function ROI_overlay([alpha])
variable alpha
if (paramIsDefault(alpha))
	alpha = 1
endif
wave Stack_SD
wave ROIs
wave Correlation_projection

wavestats/Q ROIs
variable nROIs = -V_Min


display /k=1
if (waveexists(Stack_SD))
	Appendimage /l=ROIsY Stack_SD
//	ModifyGraph fSize(ROIsY)=8,axisEnab(ROIsY)={0.55,1},axisEnab(bottom)={0.05,1};DelayUpdate
	ModifyGraph freePos(ROIsY)={0,kwFraction}
endif
Appendimage /l=ROIsY ROIs
if (waveexists(correlation_projection))
	Appendimage /l=CorrY Correlation_projection
//	ModifyGraph fSize=8,lblPos(ROIsY)=47,lblPos(CorrY)=47,axisEnab(CorrY)={0.05,0.5};DelayUpdate
	ModifyGraph freePos(CorrY)={0,kwFraction}
endif
make /o/n=(1) M_Colors
ColorTab2Wave Rainbow256
variable nColours = Dimsize(M_Colors,0)

variable rr
for (rr=0;rr<nROIs;rr+=1)
	variable CurrentCOlour = (rr/nROIs)*nCOlours

	ModifyImage ROIs explicit=1,eval={-rr,M_Colors[CurrentCOlour][0],M_Colors[CurrentCOlour][1],M_Colors[CurrentCOlour][2], M_Colors[0] * alpha}	


endfor

variable x_dim = dimsize(stack_sd, 0)
variable y_dim = dimsize(stack_sd, 1)
ModifyGraph width=x_dim*2,height=y_dim*2
ModifyGraph width=0,height=0
end