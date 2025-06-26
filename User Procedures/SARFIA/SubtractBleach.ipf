#pragma rtGlobals=1		// Use modern global access method.

//Update 09062011: Repaired wave declaration for w_coef, w_fitconstants

// SubtractBleach(pop, reject, [targetname]) fits a monoexponential decay
// with X offset to each X trace in the populationwave pop and substracts it.
// Scaled X coordinates specified in reject are ignored for the fit. 
// I.e. reject = {10,20,45,50} will reject all points from 10 to 20 and
// 45 to 50 *Units*.  
// The result is stored in $targetname (default:wavename+"_blC").

Function SubtractBleach(pop, reject, [targetname])

	wave pop, reject
	string targetname
	
	if(paramisdefault(targetname))
		targetname=nameofwave(pop) + "_blC"
	endif
	
	variable v_FitOptions=4	//suppress Curve Fit Window
	
	duplicate /o pop, calc_sbpop, calc_fits
	make /o /n=(dimsize(pop,0)) fit_result
	setscale /p x,dimoffset(pop,0),dimdelta(pop,0),waveunits(pop,0) fit_result
	setscale /p y,0,1,waveunits(pop,-1) fit_result
	duplicate/o fit_result, ToBeFitted
	
	variable ii,jj
	
	For(ii=0;ii<numpnts(reject);ii+=2)
			calc_sbpop[x2pnt(calc_sbpop,reject[ii]),x2pnt(calc_sbpop,reject[ii+1])][]=NaN
	endfor
	
	For(jj=0;jj<dimsize(pop,1);jj+=1)
		
		ToBeFitted[]=calc_sbpop[p][jj]
		
		
		CurveFit/NTHR=0 /m=0 /n=1 /q exp_XOffset ToBeFitted  /D=fit_result			//fit_result is specified only to generate the right number of points and x-scaling
		wave w_coef, w_fitconstants
		//y = K0+K1*exp(-(x-x0)/K2)
		fit_result=w_coef[0]+w_coef[1]*exp(-(x-w_fitconstants[0])/w_coef[2])	//the destination is overwritten with the fit function, because it contains regions that have not been fitted
		calc_fits[][jj]=pop[p][jj]-fit_result[p]
		
	endfor
	
	duplicate/o calc_fits, $targetname
killwaves/z calc_sbpop, calc_fits, fit_result, ToBeFitted, w_coef, w_fitconstants,w_sigma
end

/////////////////////////////////////

Function SubtractBleach_Auto()

string popname, times, targetname="_default_"
string help="It is really crucial that the times are separated by commas and have no other characters. Otherwise the program will be horribly confused. Something like 10,20,45,50 should do."

Prompt popname, "Populationwave", popup, wavelist("*",";","DIMS:2")
Prompt targetname, "Do you want to give your result a special name? Otherwise leave it as it is."
Prompt times, "Timepoints rejected - separated by commas AND NOTHING ELSE."

DoPrompt /help=help "Bleach subtraction", popname, times, targetname

if(v_flag)
	return -1
endif

variable ii, n

make /o/n=1 reject

for(ii=0;ii<itemsinlist(times,","); ii+=1)
	n=str2num(StringFromList(ii,times,","))
	reject[ii]={n}
endfor

if(stringmatch(targetname, "_default_"))
	SubtractBleach($popname, reject)
else
	SubtractBleach($popname, reject, targetname=targetname)
endif

end

