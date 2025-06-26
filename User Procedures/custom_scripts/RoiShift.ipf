#pragma rtGlobals=3		// Use modern global access method and strict wave access.
// Author: Simen Bruoygard 
function ROIShift(xshift,yshift)
variable xshift,yshift


wave ROIs
variable nX = Dimsize(ROIs,0)
variable nY = Dimsize(ROIs,1)

duplicate /o ROIs ROIs_old
ROIs=1
ROIs[][]=ROIs_old[p-xshift][q-yshift]
end
// duplicate /o ROIs_old ROIs
