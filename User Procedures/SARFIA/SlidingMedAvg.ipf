#pragma rtGlobals=1		// Use modern global access method.


function/wave mirror1D(tr)		//mirrors the wave outwards
	wave tr
	
	variable xdim, ydim, ii
	
	xdim=dimsize(tr,0)
	
	duplicate/o tr tr_d
	redimension /n=(xdim*2,ydim*2) tr_d
	tr_d=0
	tr_d[xdim/2,xdim*1.5]=tr[p-xdim/2]		//centre
	tr_d[0,xdim/2]=tr[xdim/2-p]			//left
	tr_d[xdim*1.5,xdim*2]=tr[xdim-(p-xdim*1.5)]//right

	setscale /p x, -(xdim/2*dimdelta(tr,0)-dimoffset(tr,0)),dimdelta(tr,0),waveunits(tr,0),tr_d
	
	return tr_d
end

///////////////////////////////////////////////////////////////////

Function/wave slidingMed(trace, n)		//calculates a sliding median over 2*n+1 points
	wave trace
	variable n
	
	if(n<1)
		duplicate/o trace trace_sm
		return trace_sm
	endif
	
	variable np = numpnts(trace), ii, firstp, lastp, pdif
	
	firstp=dimoffset(trace,0)
	lastp=dimdelta(trace,0)*np-firstp
	
	wave mirrored=mirror1d(trace)
	
	pdif=abs(x2pnt(trace,firstp)-x2pnt(mirrored, firstp))
	
	if(n>pdif)
		killwaves/z mirrored
		Abort "n too big."
	endif
	
	duplicate/o trace trace_sm
	trace_sm=nan
	
	for(ii=0;ii<np;ii+=1)
	
		duplicate/o/free/r=[ii+pdif-n,ii+pdif+n] mirrored, locTr
		trace_sm[ii]=statsMedian(locTr)
	
	
	endfor
	
	killwaves/z mirrored
	return trace_sm
end

///////////////////////////////////////////////////////////////////

Function/wave slidingAvg(trace, n,[free])		//calculates a sliding average over 2*n+1 points
	wave trace
	variable n, free
	
	if(ParamIsDefault(free))
		free=0
	endif
	
	if(n<1)
		if(free)
			duplicate/o/free trace trace_sd
			return trace_sd
		else
			duplicate/o trace trace_sd
			return trace_sd
		endif
	endif
	
	variable np = numpnts(trace), ii, firstp, lastp, pdif
	
	firstp=dimoffset(trace,0)
	lastp=dimdelta(trace,0)*np-firstp
	
	wave mirrored=mirror1d(trace)
	
	pdif=abs(x2pnt(trace,firstp)-x2pnt(mirrored, firstp))
	
	if(n>pdif)
		killwaves/z mirrored
		Abort "n too big."
	endif
	
	if(free)
		duplicate/o trace trace_sa
		trace_sa=nan
	else
		duplicate/o trace trace_sa
		trace_sa=nan
	endif
	
	
	for(ii=0;ii<np;ii+=1)
	
		duplicate/o/free/r=[ii+pdif-n,ii+pdif+n] mirrored, locTr
		wavestats/q/m=1 locTr
		trace_sa[ii]=v_avg
	
	endfor
	
	killwaves/z mirrored
	return trace_sa
end
	
	
///////////////////////////////////////////////////////////////////

Function/wave slidingSD(trace, n,[free])		//calculates a sliding standard deviation over 2*n+1 points
	wave trace
	variable n, free
	
	if(ParamIsDefault(free))
		free=0
	endif
	
	if(n<1)
		if(free)
			duplicate/o/free trace trace_sd
			return trace_sd
		else
			duplicate/o trace trace_sd
			return trace_sd
		endif
	endif
	
	variable np = numpnts(trace), ii, firstp, lastp, pdif
	
	firstp=dimoffset(trace,0)
	lastp=dimdelta(trace,0)*np-firstp
	
	wave mirrored=mirror1d(trace)
	
	pdif=abs(x2pnt(trace,firstp)-x2pnt(mirrored, firstp))
	
	if(n>pdif)
		killwaves/z mirrored
		Abort "n too big."
	endif
	
	if(free)
		duplicate/o/free trace trace_sd
	else
		duplicate/o trace trace_sd
	endif
	
	trace_sd=nan
	
	for(ii=0;ii<np;ii+=1)
	
		duplicate/o/free/r=[ii+pdif-n,ii+pdif+n] mirrored, locTr
		wavestats/q/m=2 locTr
		trace_sd[ii]=v_sdev
	
	endfor
	
	killwaves/z mirrored
	return trace_sd
end
	
	


