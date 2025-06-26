#pragma rtGlobals=1		// Use modern global access method.

Static StrConstant k_Chars="0;1;2;3;4;5;6;7;8;9;_;a;b;c;d;e;f;g;h;i;j;k;l;m;n;o;p;q;r;s;t;u;v;w;x;y;z;*;"

Function Name2Num(Name,[nChar])
	String Name
	Variable nChar
	
	variable LastChar, ii, N2N=0, base=itemsinlist(k_chars), NameNum
	
	if(ParamIsDefault(nChar))
		LastChar=StrLen(Name)-1
	else
		LastChar=min(StrLen(Name)-1,nChar-1)
	endif
	
	For(ii=0;ii<=LastChar;ii+=1)
	
		NameNum=WhichListItem(Name[ii],k_CHars,";",0,0)
			if(NameNum==-1)					//Character not in list?
				NameNum=base-1				//output="*"
			endif
		N2N+=base^(LastChar-ii)*(NameNum)
	
	EndFor
	
	return N2N
end

////////////////////////////////

Function/t Num2Name(Num)
	Variable Num

	String Name="", buffer
	Variable LastChar, ii, base=itemsinlist(k_chars), num2=num, charnum
	
	LastChar=trunc(log(Num)/(log(base)))

	For(ii=0;ii<=LastChar;ii+=1)

		CharNum=mod(num2,base)
			if(CharNum==base-1)
				buffer="X"
			else
				buffer=StringFromList(CharNum,k_Chars)
			endif
		Name=buffer+Name
		num2=(num2-CharNum)/base


	EndFor

	return name
End