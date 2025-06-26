#pragma rtGlobals=1		// Use modern global access method.
#pragma version=2			//Makes a complicated 2D wave with a variable-length footer
#include "ExpDataBase2"


Function ExtractionTemplate(DataBase,[ResultName])
	Wave DataBase
	String ResultName
	
	if(Paramisdefault(resultname))					//check if ResultName has been specified
		ResultName="DB_Extract"						//give it a default name, if not
	endif
	
	Variable nTraces, ii, AllConditions, nResults=0		//declaring variables
	Make /o/free /n=1 w_Condition	=1					//Make a wave containing all the conditions			
	
	nTraces=DimSize(DataBase,1)						//number of traces in Database
	
	Duplicate/o/free DataBase w_Extract				//w_Extract holds the results for now
	w_extract=NaN
	
	
	For(ii=0;ii<nTraces;ii+=1)						//loop through all the traces in DataBase

/////////Edit Below///////////////////////////////////////////////////////////////////////////////////
//		           ||
//		           ||
//                \        /
//                  \    /
//                    \/


	
		w_Condition[0]={DataBase[%Age][ii]==8 ? 1 : 0}			//exact match
		w_Condition[1]={DataBase[%Position][ii]>20 ? 1: 0}		//range larger than
		w_Condition[2]={DataBase[%Position][ii]<50 ? 1: 0}		//range smaller than (--> interval in sum)
		
		//add more...
	
//	w_Condition[n] ={<expression> ? <TRUE> : <FALSE>} 	w_condition[n] will become TRUE, if condition is met, otherwise FALSE; curly brackets to add more points to wave, if needed



															
//                      /\
//                    /    \
//			  /        \
//				||		
//				||																				
/////////Edit Above///////////////////////////////////////////////////////////////////////////////////
	
		AllConditions=WaveMin(w_condition)						//AllConditions = 1 if all conditions have been met, otherwise 0
		
		//alternatively use the following type of code (make sure that parentheses are set correctly)
		//AllConditions=(w_condition[0] || w_condition[1]) && !w_condition[2] 	//condition 0 OR 1 AND NOT 2
		
		if(allConditions)											//check if all conditions have been met
			w_Extract[][nResults]=DataBase[p][ii]				//add trace to w_extract
			nresults+=1
		endif
	
	EndFor													//End of loop
	
	
	if(nResults)											//Any hits?	
		redimension /n=(-1,nResults)	w_Extract			//remove any empty fields
		Duplicate/o w_Extract, $ResultName				//Make the result with the right name
		
	else														//no hits?
		make/o/n=1 $ResultName = NaN					//make an empty wave
		DoAlert 0, "No matches"
		
	endif
	
	Return nResults											//returns the number of hits. Useful, if called from a function, to see wether the operation succeeded.

End


