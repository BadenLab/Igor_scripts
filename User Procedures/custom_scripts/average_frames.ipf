#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
// Author: Simen Bruoygard 
Function/wave AverageStack(imStack, [n, zStart, zEnd])		
	wave imStack
	variable n, zStart, zEnd	// Optional parameters

	variable nFrames, ii, newn, start, stop
	string newname = NameOfWave(imStack) + "_av" + num2str(n)

	// Default to full Z-range if not specified
	if (ParamIsDefault(zStart) || ParamIsDefault(zEnd))
		zStart = 0
		zEnd = DimSize(imStack, 2) - 1
	endif

	// Compute number of frames to process
	nFrames = zEnd - zStart + 1

	// If n is not specified, average over the entire Z-range
	if (ParamIsDefault(n) || n <= 0)
		n = nFrames
	endif
	
	// Compute number of output frames
	newn = round(nFrames / n)

	// Subset Z-range and prepare storage
	duplicate/o/free /r=[0, *][0, *][zStart, zEnd] imStack, subStack
	duplicate/o/free subStack, av_stack
	redimension/n=(-1, -1, newn) av_stack

	// Compute averaged frames
	For(ii = 0; ii < newn; ii += 1)
		start = ii * n
		stop = min(start + n - 1, nFrames - 1)  // Ensure we don’t exceed available frames

		duplicate/o/free /r=[0, *][0, *][start, stop] subStack, tobeAv
		MatrixOP /o/free avImage = sumBeams(tobeAv) / (stop - start + 1)

		av_stack[][][ii] = avImage[p][q]
	EndFor

	// If n was not specified (full Z-range), output a single 2D wave
	if (n == nFrames)
		duplicate/o/free /r=[0, *][0, *][0] av_stack, finalImage
		duplicate/o finalImage, $newname
		Display
		AppendImage $newname
		return $newname
	endif

	// Save and return 3D stack if n was specified
	duplicate/o av_stack, $newname
	Display
	AppendImage $newname
	return $newname
End

