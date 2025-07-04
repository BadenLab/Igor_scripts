#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
// Author: Simen Bruoygard 

function split_group3d(targetwave, num_sections, [orientation, plot])
// Purpose: Transform a 3D wave (x, y, z) into another 3D wave (x, y, z) 
//          by partially concatenating the z dimension into either the x or y 
//          dimensions. This is designed to visualize groups of responses 
//          within the same group (for example colour) along rows or columns while 
//			iterating through different groups along the z-axis.
//          For example, it can convert a wave of size 126 x 64 x 15 
//          into a wave of size 126 x 256 x 6.
// Parameters:
// targetwave - The original 3D wave to be processed (dimensions: x, y, z)
// num_sections - Number of sections to collapse along the z dimension (integer)
// plot (optional) - Set to 1 to plot the result, defaults to 0
// orientation (optional) - "v" for vertical concatenation (default), 
//                         "h" for horizontal concatenation
wave targetwave
variable num_sections, plot
string orientation

if (paramisDefault(orientation) == 0)
	variable logic_gate = CmpStr(orientation, "v") != 0 && CmpStr(orientation, "h") != 0
	if (logic_gate != 0)
		print "Orientation must be v or h, got", orientation
		print "Exiting"
		return 0
	endif
else
	orientation = "v"
endif
print "Printing in orientation", orientation

//wave QC_projection_pertrigger
if (waveexists(targetwave) == 0)
	print("QC_projection_pertrigger does not exist, compute that first")
	return 0
	endif

// Duplicate the original wave to work on a temporary copy
duplicate /o targetwave temp_split_wave

// Get dimensions of the wave
variable cdim = dimsize(targetwave, 3)  // Depth (3rd dimension)
variable zdim = dimsize(targetwave, 2)  // Depth (3rd dimension)
variable ydim = dimsize(targetwave, 1)  // Height (2nd dimension)
variable xdim = dimsize(targetwave, 0)  // Width (1st dimension)

// Calculate the number of slices (2D waves)
variable layers = zdim / num_sections
print "Split to " + num2str(layers) + " layers with " + num2str(num_sections) + " panels"

// Redimension wave to add chunks (stimulus interval n)
Redimension/E=1/N=(-1,-1,num_sections,layers) temp_split_wave

// Create the output wave with appropriate dimensions for concatenation
if (CmpStr(orientation, "h"))
	make /o /n=(xdim, ydim*num_sections, layers) output  // Preallocate space for the concatenated result
	endif
if (CmpStr(orientation, "v"))
	make /o /n=(xdim*num_sections, ydim, layers) output
	endif
	
// Loop through each chunk and horizontally concatenate
variable i, j
for (i = 0; i < layers; i += 1)
	for (j = 0; j < num_sections; j += 1)
		// Extract each 2D slice from temp_split_wav
		wave tempwave
		duplicate /o /RMD=[][][j][i] temp_split_wave tempwave
		redimension /e=0 /N=(xdim, ydim, 1) tempwave  // Ensure 2D shape of tempwave
		// Assign tempwave to the appropriate section in output
		// Ensure dimensions of tempwave (xdim, ydim) match the destination region in output
		if (CmpStr(orientation, "h"))
			variable deltav = ydim * j
			output[0, xdim-1][0+deltav, ydim-1+deltav][i] = tempwave[p][q-deltav][0]
			endif
		if (CmpStr(orientation, "v"))
			variable deltah = xdim * j
			output[0+deltah, xdim-1+deltah][0, ydim-1][i] = tempwave[p-deltah][q][0]
			endif
	endfor
endfor
//setscale /p x, 1, 10, output
//setscale /p y, 1, 10, output
if (paramisDefault(plot) == 0)
	newimage /F /G=1 /S=1 /k=1 output
	modifygraph expand = 3
	WMAppend3dImageSlider()
else
    print("Plot by passing 'plot=1'")
endif
end