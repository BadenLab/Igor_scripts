#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "OS_BasicAveraging"



function chroma_average(Averages0Wave, split_int)
	wave Averages0Wave
	variable split_int

	wave Averages0
	// Check if Averages0 exist, if not, generate it
	if (waveexists(Averages0) == 0)
		print("Could not find Averages0, attempting to create it")
		OS_BasicAveraging() // if Averages0 does not exist, attempt to create it
	else
		print("Averages0 found, creating Averages0_chroma, with colour represented along layers")
	endif
	// Get the Averages0 wave and copy it 
	wave Averages0_chroma
	duplicate /o Averages0, Averages0_chroma
	// Get the shape of Averages0
	variable n_points, n_rois
	n_points = dimsize(Averages0, 0)
	n_rois = dimsize(Averages0, 1)
	// Reshape Averages0_chroma such that colours are represented along split_int dimension
	redimension /n = (n_points/split_int, n_rois, split_int) /e=1 Averages0_chroma//rows, columns, layers, chunks
end 