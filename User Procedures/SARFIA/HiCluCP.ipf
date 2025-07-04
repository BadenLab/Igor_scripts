#pragma rtGlobals=1		// Use modern global access method.
#include "Z-Project"
#include "CenterOfMass_custom"

Function/Wave NormalizeTraces(PopWave, options)
	Wave PopWave
	Variable Options //bit0 - normalise 0 to 1, bit1 - divide by SD
	
	Variable YDim, ii

	YDim=DimSize(PopWave,1)

	Duplicate/o/Free PopWave, trace, PopNorm
	Redimension /n=(-1) trace
	
	For(ii=0;ii<YDim;ii+=1)
		trace=PopWave[p][ii]
		
		if(options & 1)	//morm 0-1
			WaveStats/Q/m=2 trace
			trace-=v_min
			trace/=(v_max-v_min)
		endif
		
		if(options & 2)		//div SD?
			WaveStats/Q/m=2 trace
			trace /= v_Sdev
		endif
		
		
		PopNorm[][ii]=trace[p]
	EndFor

	String ResultName=NameOfWave(PopWave)+"_NT"
	Duplicate/o PopNorm $Resultname
	Return $ResultName
End

////////////////////////////////////////////////
Function/Wave BinPop(popWave,resultname,nBins, [smth])	
	Wave popWave
	string resultname
	Variable nBins, smth
	
	
	variable npts = dimsize(popWave,0), ntraces = dimsize(popWave,1), ii, bl, jj, binSize, wmin, wmax
	
		
	if(ntraces < 1)
		ntraces = 1
	endif
	
	Duplicate /o/free PopWave, pop, trace, NorPop
	redimension /n=(-1) trace
	Make/free/o Histo
	Make/o/n=(ntraces)/free w_BL
	
	if(!paramisdefault(smth))
		Smooth smth,  PopWave
	endif
	
	
	for(ii=0;ii<ntraces;ii+=1)
		trace = pop[p][ii]
		wmin=wavemin(trace)
		wmax=wavemax(trace)
		
		BinSize=(wmax-wmin)/nBins
		
		for(jj=0;jj<nBins;jj+=1)
			
			NorPop[][ii]=SelectNumber(trace[p]>=WMin+jj*BinSize && trace[p]<=wmin+(jj+1)*BinSize, NorPop[p][ii] ,jj)
		
			
		endfor
	endfor
	
	Duplicate /o NorPop, $resultname
	
	Wave w=$ResultName
	Return w
End


////////////////////////////////////////////////



Function/Wave PopDistances(PopWave,options)
	Wave PopWave
	Variable Options //0=Euclidean, 1=Chebyshev, 2=Hamming/Bin, 3=Binning, 4=normalised Euclidean, 5=Pearson
					//6=Manhattan

	Variable YDim, ii, XDim, jj

	YDim=DimSize(PopWave,1)
	XDim=DimSize(PopWave,0)

	Make/o/Free/n=(YDim,YDim,XDim) DistanceMatrix3D
	Make/o/Free/n=(YDim,YDim) DistanceMatrix
	Duplicate/o/Free PopWave, trace, trace2
	redimension /n=(-1) trace,trace2
	
	
	Switch(options)
		Case 0:	//Euclidean	
			MultiThread DistanceMatrix3D = (PopWave[r][p]-PopWave[r][q])^2
			MatrixOP/o/free DistanceMatrixSq = sumbeams(DistanceMatrix3D)
			MatrixOP/o/free DistanceMatrix=Sqrt(DistanceMatrixSq)		
		Break
		
		Case 1:	//Chebyshev
			MultiThread DistanceMatrix3D = Abs(PopWave[r][p]-PopWave[r][q])
			Wave MaximumWv=MaxZ(DistanceMatrix3D,"MaxWv")
			Duplicate/o MaximumWv, DistanceMatrix
			KillWaves /z MaximumWv
		Break
		
		
		Case 2:	//Hamming
			Wave BinnedPop=PopWave
			MultiThread DistanceMatrix3D = Abs(BinnedPop[r][p]-BinnedPop[r][q])
			DistanceMatrix3D=SelectNumber(DistanceMatrix3D>=1,0,1)				//Not weighed by the degree of difference
						
			MatrixOP/o/free DistanceMatrix = sumbeams(DistanceMatrix3D)
					
			Duplicate/o Distancematrix3d dm3d
			KillWaves/z BinnedPop, M_AveImage, M_StdvImage
		Break
		
		Case 3:	//Binning
			Wave BinnedPop=BinPop(PopWave,"Binned",5,smth=5)
			MultiThread DistanceMatrix3D = Abs(BinnedPop[r][p]-BinnedPop[r][q])
			MatrixOP/o/free DistanceMatrixSq = sumbeams(DistanceMatrix3D)
			MatrixOP/o/free DistanceMatrix=Sqrt(DistanceMatrixSq)		
		
			Duplicate/o Distancematrix3d dm3d
			KillWaves/z BinnedPop, M_AveImage, M_StdvImage
		Break
		
		Case 4:	//normalised Euclidean	
			MultiThread DistanceMatrix3D = (PopWave[r][p]-PopWave[r][q])^2			
			ImageTransform averageImage DistanceMatrix3D
			Wave/z M_AveImage, M_StdvImage
			DistanceMatrix=Sqrt(M_AveImage*XDim/M_StdvImage)		//Sum = Average * n
			KillWaves/z M_AveImage, M_StdvImage
		Break
		
		Case 5://Pearson R
			For(ii=0;ii<YDim;ii+=1)
				For(jj=0;jj<YDim;jj+=1)
					trace=PopWave[p][jj]
					trace2=PopWave[p][ii]
					
					 DistanceMatrix[ii][jj]=1-(StatsCorrelation(trace,trace2))		//1-... so that biggest similarity equals 0 (i.e. least distance)
				
				EndFor
			EndFor	
		Break
		
		Case 6:	//Manhattan	
			MultiThread DistanceMatrix3D = abs(PopWave[r][p]-PopWave[r][q])
			MatrixOP/o/free DistanceMatrix = sumbeams(DistanceMatrix3D)
		Break
		
		
	EndSwitch
	

	String ResultName=NameOfWave(PopWave)+"_DM"
	Duplicate/o DistanceMatrix $ResultName
	Return $ResultName
End

////////////////////////////////////////////////

Function/Wave HiClu(Sorted,cutoff)
	Wave Sorted
	Variable CutOff
	
	
	Variable nItems, ii, Distance, nClusters=0
	Variable Val1,Val2, Index1,Index2, nPairs
	Variable CurrentClu, nClu, MaxVal, MinVal
	
	nPairs=DimSize(Sorted,0)
	
	ImageStats /m=1/g={0,nPairs-1,1,2} Sorted
	nItems=v_Max+1
	
	Make/o/n=(nItems) Clusters=p
	
	
	ii=0
	Do
		Distance=Sorted[ii][0]
		
		Val1=Sorted[ii][1]
		Val2=Sorted[ii][2]
		
		Index1=Clusters[Val1]
		Index2=Clusters[Val2]
		
		MaxVal=Max(Val1,Val2)
		MinVal=Min(Index1,Index2)
		

		MultiThread Clusters=SelectNumber(Clusters==MaxVal,Clusters[p],MinVal)		//nearest neighbor

	
		ii+=1
	While(Distance<Cutoff)
	

	
	Renumber1D(Clusters)		//remove empty clusters
	

	Return Clusters
End
	
/////////////////////////////////////////
Function/Wave HiClu2D(Sorted)
	Wave Sorted

	
	Variable nItems, ii, Distance, nClusters=0
	Variable Val1,Val2, Index1,Index2, nPairs
	Variable CurrentClu, nClu=0, MaxVal, MinVal
	
	Variable jj, Cutoff
	
	nPairs=DimSize(Sorted,0)
	
	ImageStats /m=1/g={0,nPairs-1,1,2} Sorted
	if(v_Flag==-1)
		Abort "ImageStats wrong in HiClu2D"
	endif
	
	nItems=v_Max+1
	
	Make/o/n=(nItems)/free Clusters=p
	Make/o/n=(nItems,nPairs) Clusters2D=NaN, TestWv
	Make /o Cluster_Dist
	
	For(jj=0;jj<nPairs;jj+=1)
		CutOff=Sorted[jj][0]
		ii=0
		
		Do
			Distance=Sorted[ii][0]
			
			Val1=Sorted[ii][1]
			Val2=Sorted[ii][2]
			
			Index1=Clusters[Val1]
			Index2=Clusters[Val2]
			
			MaxVal=Max(Val1,Val2)
			MinVal=Min(Index1,Index2)
			
		
			MultiThread Clusters=SelectNumber(Clusters==MaxVal,Clusters[p],MinVal)		//nearest neighbor
			
		
			
		
			ii+=1
		While(Distance<Cutoff)
	
	
	Renumber1D(Clusters)		//remove empty clusters
	
//	Clusters2D[][nClu]=Clusters[p]
//	nClu+=1
	
		if(jj>0)
			TestWv=Clusters2D[p][nClu-1]-Clusters[p]
			
			if(WaveMax(TestWv)!=0)
				Clusters2D[][nClu]=Clusters[p]
				Cluster_Dist[nClu]={cutoff}
				nClu+=1
				
			endif
			
		else	//jj==0
			Clusters2D[][nClu]=Clusters[p]
			Cluster_Dist[nClu]={cutoff}
			nClu+=1
			
		Endif

	
	
		if(WaveMax(Clusters)==0)
			break
		endif

	EndFor
		
		DeletePoints /m=1 nClu,nPairs-nClu, clusters2D
		
		
	
	Return Clusters2D
End



/////////////////////////////////////////

Function/Wave SortByFirst(DM2C,rev)
	Wave DM2C
	Variable rev
	
	Duplicate/o/Free DM2C wv1,wv2,wv3, Sorted
	redimension/n=(-1) wv1,wv2,wv3
	
	wv1=DM2C[p][0]
	wv2=DM2C[p][1]
	wv3=DM2C[p][2]
	
	Variable nPts=WaveMax(wv2)+1, nPairs=DimSize(DM2C,0)

	
	if(rev)
		sort/r wv1,wv1,wv2,wv3
		DeletePoints 0,nPts, Sorted, wv1,wv2,wv3
	else
		sort wv1,wv1,wv2,wv3
		DeletePoints nPairs-nPts,nPts, Sorted, wv1,wv2,wv3
	endif
	
	
	Sorted[][0]=wv1[p]
	Sorted[][1]=wv2[p]
	Sorted[][2]=wv3[p]
	
	String newname=NameofWave(DM2C)+"_s"
	Duplicate/o Sorted, $newname
	Wave w=$newname
	Return w
End


/////////////////////////////////////////

//Static
// Function FirstEmptyInCol(wv,Col)
//	Wave wv
//	Variable Col
//
//	Variable nRows=DimSize(wv,1), ii, val
//	
//	For(ii=0;ii<nRows;ii+=1)
//	
//		val=wv[ii][Col]
//		if(numType(val)==2)
//			return ii
//		endif
//	
//	EndFor
//
//
//	Return -1	//row full
//End

/////////////////////////////////////////

//Function Renumber1D(wv)			//slightly slower than histogram approach
//	wave wv
//	
//	Variable Wmax, ii, wMin
//	
//	Wmax=WaveMax(wv)
//	WMin=WaveMin(wv)
//	
//	
//	For(ii=Wmax;ii>=Wmin;ii-=1)
//	
//		FindValue /v=(ii) wv
//		if(v_value==-1)		//value not found
//			MultiThread wv=SelectNumber(wv[p]>ii,wv[p],wv[p]-1)
//		
//		endif
//	EndFor
//	
//End

/////////////////////////////////////////

Function Renumber1D(wv)
	wave wv
	
	Variable Wmax, ii, wMin, npts, value, num=0, val=0	
		
	Wmax=waveMax(wv)
	WMin=WaveMin(wv)
	npts=WMax-WMin
	
	if(npts < 2)	//no sorting needed
		return -1
	endif
	
	make/n=(npts)/o/free Histo
	
	Histogram /b={WMin, 1, WMax} wv, Histo
	
	WaveStats/m=1/q wv
	
	if(v_npnts >= 1e3)		//empirically determined value on my 2GHz Core 2 Duo Mini Mac
	
		For(ii=npts-1;ii>=0;ii-=1)
		
			
			num=Histo[ii]
			val=ii*DimDelta(Histo,0)+DimOffset(Histo,0)
		
			if(num<1)		//value not found
				MultiThread wv=SelectNumber(wv[p]>=val,wv[p],wv[p]-1)
			
			endif
		EndFor
		
	else
	
		For(ii=npts-1;ii>=0;ii-=1)
		
			
			num=Histo[ii]
			val=ii*DimDelta(Histo,0)+DimOffset(Histo,0)
		
			if(num<1)		//value not found
				wv=SelectNumber(wv[p]>=val,wv[p],wv[p]-1)
			
			endif
		EndFor
	
	
	endif
	
End



/////////////////////////////////////////

Function ClusterDisplay2D(Clusters2D, Dist)
	Wave Clusters2D, Dist
	
	Variable ii, nNodes
	
	nNodes=DimSize(Clusters2D,0)
	
	Display/k=1
	For(ii=0;ii<nNodes;ii+=1)
		AppendTograph Clusters2D[ii][] vs dist
	
	
	EndFor

	ModifyGraph swapXY=1
	Label Bottom, "Trace Number"
	Label Left, "Distance"

End