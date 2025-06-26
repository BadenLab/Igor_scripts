#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1	//Runs only with version 6.1(B05) or later

//update 2013/08/01: renamed DeleteNaNs to DeleteNaNPoints to avoid a naming conflict with NeuroMatic

Function NaNBust(wv, [newnum])

	wave wv
	variable newnum
	variable dims
	
	if(paramisdefault(newnum))
		newnum = 0
	endif
	
	
	dims = wavedims(wv)
	
	if (dims > 0)
		MatrixOP/o/free NaN_Busted = ReplaceNaNs(wv, newnum)
	else
		DoAlert 0, "NaNBust: Wave seems to have no data."
	endif
	
	FastOP wv = NaN_Busted
end

/////////////////////////////////////////////////////

Function Replace(wv,  findVal, replacementVal)
	wave wv
	variable  findVal, replacementVal
	variable dims
	
	
	
	dims = wavedims(wv)
	
	if (dims > 0)
		MatrixOP/o/free w_Replaced = Replace(wv, findVal, replacementVal)
	else
		DoAlert 0, "Replace: Wave seems to have no data."
	endif
	
	fastOP wv = w_Replaced
end

////////////////////////////////////////////////

Function DeleteNaNpoints(Wv,[wv2])	//Deletes points with NaN in a (or 2)1D wave
	wave wv, wv2
	variable ex2
	
	if(ParamisDefault(wv2))
		wave w2 = wv
		ex2=0
	else
		wave w2 = wv2
		ex2=1
	endif
	
	Variable np, ii
	
	np=numpnts(wv)
	
	for(ii=np-1;ii>=0;ii-=1)
	if((numtype(wv[ii])==2 ) || (numtype(w2[ii])==2 )) 
			deletepoints ii,1,wv
			if(ex2==1)
				deletepoints ii,1,w2
			endif
		endif
	
	endfor
	
	return 0
end
	