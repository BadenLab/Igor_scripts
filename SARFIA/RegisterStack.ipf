#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 6.1

//update 16/11/10: added flag /pstk to RegisterStack registration
//update 04/05/15: added function CoRegisterStack
//CoRegisterStack(StackList, [suffix]): Performs image registration
//on a stack of images and applies the same registration parameters
//to all subsequent stacks in a list. StackList is a text wave containing 
//the names of all waves to be registered. The 1st wave in StackList is 
//the template for all subsequent ones. The optional string suffix
//will be appended to the name of all resultant waves (default: "_reg").


Function RegisterStack(picwave, [target])

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
	endif
	
	
	if (dims != 3)
		DoAlert 0, "<"+name+"> ins not a stack. Aborting RegisterStack." 
		return -1
	endif
	
	duplicate /o picwave, regcalcwave
	
	redimension /s regcalcwave		//redimension to single precision float, as ImageRegistration allows only that
	
	duplicate /o regcalcwave, ref
	redimension /N=(-1,-1) ref
	
	
	imageregistration /q /stck /pstk /csnr=0 /refm=0 /tstm=0 testwave=regcalcwave, refwave=ref
	wave m_regout
	
	MatrixOP/o/free w_NaNBusted = ReplaceNaNs(m_regout, 0)	//replace NaN's with 0

	copyscaling(regcalcwave, w_NaNBusted)
	duplicate /o w_NaNBusted, $target
	
	killwaves /z  ref, regcalcwave, M_Regout, M_Regmaskout, M_RegParams, W_RegParams  
end


////////////////////////////////////////////////

Function Reg2(picwave)
wave picwave

string result = nameofwave(picwave)

RegisterStack(picwave, target=result)

print "Completed registration of <"+result+">"

end

////////////////////////////////////////////////

Function QuickReg()

string topwave

GetWindow kwTopWIn, wavelist
wave /t w_wavelist

topwave = w_wavelist[0][0]

Reg2($topwave)

killwaves /z w_wavelist
end

////////////////////////////////////////////////

Function CoRegisterStack(StackList, [suffix])
	Wave/t StackList				//Contains names of waves to be registered. 1st is reference for all subsequent ones.
	String suffix
	
	Variable nStacks, xRef, yRef, zRef, xTest, yTest, zTest, ii
	Variable CheckVal
	String wName, resultName, RPName
	
		
	if(ParamIsDefault(suffix))
		suffix="_reg"
	endif
	
	nStacks=DimSize(StackList,0)
	
	For(ii=0;ii<nStacks;ii+=1)
	
		wName=StackList[ii]
		resultName=wName+suffix
		RPName=wName+"_RegParams"
		
	//checking if specified wave exists and is valid
		if(strlen(wName)<1 && ii==0)
			Print "No reference wave specified. Aborting."
			Return -1
		elseif (strlen(wName)<1) 
			Printf "No wave specified at position %g. Skipping.\r", ii
			Continue
		endif
	
		Wave/z regWave = $wName
		If (WaveExists(regWave) == 0 && ii==0)
			Printf "Reference wave %s not found. Aborting.\r", wName
			Return -1
		Elseif((WaveExists(regWave) == 0))
			Printf "Wave %s not found. Skipping.\r", wName
			Continue
		Endif
		
	//check if wave dimensions match
		if(ii==0)
			xRef=DimSize(regWave, 0)
			yRef=DimSize(regWave, 1)
			zRef=DimSize(regWave, 2)
			
		else
			xTest=DimSize(regWave, 0)
			yTest=DimSize(regWave, 1)
			zTest=DimSize(regWave, 2)
			
			CheckVal=ABS(xRef-xTest)+ABS(yRef-yTest)+ABS(zRef-zTest)
			if(CheckVal>0)
				Printf "Dimension mismatch of wave %s. Skipping.\r", wName
			endif		
		endif
		
	//register
		if(ii==00)
			
			Duplicate/o/free/r=[][] regWave, refMask		//generate refMask from 1st layer of reference image
			Redimension/n=(-1,-1) refMask				//make refMask 2D
	
			ImageRegistration /q /stck /pstk /csnr=0 /refm=0 /tstm=0 testwave=regwave, refwave=refMask
			wave M_regout, M_RegParams
	
			MatrixOP/o/free w_NaNBusted = ReplaceNaNs(M_regout, 0)	//replace NaN's with 0


			copyscales regWave, w_NaNBusted
			duplicate/o M_RegParams, $RPName		//make copy of M_RegParams
			duplicate /o w_NaNBusted, $resultName	//make copy of result
			wave RegParams = $RPName
	
		else
			ImageRegistration /q /stck /pstk /csnr=0 /refm=0 /tstm=0 /user=RegParams testwave=regwave
			wave M_regout
			
			MatrixOP/o/free w_NaNBusted = ReplaceNaNs(M_regout, 0)	//replace NaN's with 0


			copyscales regWave, w_NaNBusted
			duplicate /o w_NaNBusted, $resultName	//make copy of result
		endif
	
	EndFor
	
	
	Killwaves /z  M_Regout, M_Regmaskout, M_RegParams, W_RegParams  
	return 1
End