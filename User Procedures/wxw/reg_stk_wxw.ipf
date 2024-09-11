#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later



//update 16/11/10: added flag /pstk to RegisterStack registration

Function Reg_stk_wxw(picwave, [target,ref_st,ref_end])
	
	variable ref_st, ref_end
	wave picwave
	string target
	variable dims, type
	string info, name
	
	info = waveinfo(picwave,0)
	type = NumberByKey("NUMTYPE", info)
	//	NUMTYPE	A number denoting the numerical type of the wave:
	//		1:	Complex, added to one of the following:
	//		2:	32-bit (single precision) floating point
	//		4:	64-bit (double precision) floating point
	//		8:	8-bit signed integer
	//		16:	16-bit signed integer
	//		32:	32-bit signed integer
	//		64:	Unsigned, added to 8, 16 or 32 if wave is unsigned
	dims = wavedims(picwave)
	name = Nameofwave(picwave)
	
	if(paramisdefault(target))
		target = name+"_reg"
		ref_st = 60
		ref_end = 65
	endif
	
	
	if (dims != 3)
		DoAlert 0, "<"+name+"> ins not a stack. Aborting RegisterStack." 
		return -1
	endif
	
	duplicate /o picwave, regcalcwave
	
	redimension /s regcalcwave		//redimension to single precision float, as ImageRegistration allows only that
	
	// duplicate /o regcalcwave, ref
	// redimension /N=(-1,-1) ref
	
	imagetransform averageimage regcalcwave
	wave M_aveimage
	wave ave_image_stck = M_aveimage
	
	duplicate /o/R=[][][ref_st,ref_end] regcalcwave, ref1		// modified by jamie 10/11/14 to take an averag of the 1st 50 frames
	imagetransform averageimage ref1		// modified by jamie 10/11/14 to take an averag of the 1st 50 frames
	wave M_aveimage									// modified by jamie 10/11/14 to take an averag of the 1st 50 frames
	wave ref=M_aveimage					// modified by jamie 10/11/14 to take an averag of the 1st 50 frames
	redimension/S /N=(-1,-1) ref
	
	imageregistration /q /stck /csnr=1 /refm=2 /tstm=2 /pstk testwave=regcalcwave, refwave=ref1
	wave m_regout
	wavestats ref1
	MatrixOP/o/free w_NaNBusted = ReplaceNaNs(m_regout, V_avg)	//replace NaN's with 0

	copyscaling(regcalcwave, w_NaNBusted)
	duplicate /o w_NaNBusted, $target
	
	killwaves /z  ref, regcalcwave, M_Regout, M_Regmaskout, M_RegParams, W_RegParams  
end


