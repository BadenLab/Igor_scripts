#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function KillBrightPix()

variable killbelow = 40000
variable killabove = 65000

wave wDataCh0

variable nX = Dimsize(wDataCh0,0)
variable nY = Dimsize(wDataCh0,1)
variable nF = Dimsize(wDataCh0,2)

// compute mean brightness in 1st frame

make /o/n=(nX,nY) tempwave = wDataCh0[p][q]
WaveStats/Q tempwave
variable TargetBrightness = V_Avg
killwaves tempwave
// apply

Multithread wDataCh0[][][]=(wDataCh0[p][q][r]<killbelow || wDataCh0[p][q][r]>killabove || NumType(wDataCh0[p][q][r])==2)?(TargetBrightness):(wDataCh0[p][q][r])

 

end