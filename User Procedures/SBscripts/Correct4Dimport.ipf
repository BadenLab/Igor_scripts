#pragma rtGlobals=3     // Use modern global access method and strict wave access.
//  TransposeLayersAndChunks(w4DIn)
//  Transposes the layer and chunk dimensions of a 4D wave.
//  NOTE: Overwrites output wave.
Function TransposeLayersAndChunks(w4DIn, nameOut)
    Wave w4DIn               // Name of input wave
    String nameOut          // Desired name for new wave
        
    // Get information about input wave
    Variable input_rows = DimSize(w4DIn, 0)
    Variable input_columns = DimSize(w4DIn, 1)
    Variable input_layers = DimSize(w4DIn, 2)
    Variable input_chunks = DimSize(w4DIn, 3)
    Variable type = WaveType(w4DIn)
   
    // Make output wave. Note that numLayers and numChunks are swapped
    Make/O/N=(input_layers, input_chunks, input_columns, input_rows)/Y=(type) $nameOut
    Wave w4DOut = $nameOut
       
    // Copy scaling and units
    CopyScales w4DIn, w4DOut
   
    // Swap layer and chunk scaling (also do some scaling for convenience, useful later)
    Variable v0, dv
    String units
    v0 = DimOffset(w4DIn, 0) // Row dimension
    dv = DimDelta(w4DIn, 0) 
    units = WaveUnits(w4DIn, 0)
    SetScale x, v0, dv, units,  w4DOut  // Copy row dimensions and units to layer dimension
    v0 = DimOffset(w4DIn, 1) // Column dimension
    dv = DimDelta(w4DIn, 1) 
    units = WaveUnits(w4DIn, 1)
    SetScale y, v0, dv, units,  w4DOut  // Copy column dimensions and units to layer dimension
    v0 = DimOffset(w4DIn, 2) //  Layer dimension
    dv = DimDelta(w4DIn, 2)
    units = WaveUnits(w4DIn, 2)
    SetScale z, v0, dv, units,  w4DOut  // Copy layer dimensions and units to chunk dimension
    v0 = DimOffset(w4DIn, 3) // Chunk dimension
    dv = DimDelta(w4DIn, 3)
    units = WaveUnits(w4DIn, 3)
    SetScale t, v0, dv, units,  w4DOut  // Copy chunk dimensions and units to layer dimension
    w4DOut = w4DIn[s][r][p][q]          // #s and r are reversed from normal       
   
   // Split the chunks
   // 
   Variable i
   String colour
   String name
   //create wave with "R", "G", "B", "UV" for looping through later and adding to wave names
   for(i=0; i<4; i+=1)
    if (i == 0)
        colour = "R"
    elseif (i == 1)
        colour = "G"
    elseif (i == 2)
        colour = "B"
    elseif (i == 3)
        colour = "UV"
    endif
    // Subsample chunks, put them in appropriately named waves
    duplicate /o/r = [][][][i]w4DOut, $nameOut + "_" + colour 
    if (dimsize( $nameOut + "_" + colour, 3) == 1)
        Redimension/N=(-1,-1,-1) $nameOut + "_" + colour // Drop 'chunk' axis (because should be 1), going from 4D to 3D
    endif
    Variable layer, num_layers = DimSize($nameOut + "_" + colour, 2)
    for(layer=0; layer<num_layers; layer+=1) // Flip each frame
        imagetransform /p = (layer) fliprows $nameOut + "_" + colour
    endfor
    //  Correct for tranposing and flipping
    Wave M_VolumeTranspose
    make /O M_VolumeTranspose
    imagetransform /g=5 transposevol $nameOut + "_" + colour
    duplicate /o M_VolumeTranspose,  $nameOut + "_" + colour //R, G, B, UV
    // Finally, adjust scales to make things nice and lovely 
    variable row_num, column_num
    column_num = DimSize( $nameOut + "_" + colour, 0)
    row_num = DimSize( $nameOut + "_" + colour, 1)
    SetScale y, 0, row_num, units, $nameOut + "_" + colour
    SetScale  x, 0, column_num, units, $nameOut + "_" + colour 
    
   endfor
killwaves /z M_VolumeTranspose // Delete temporary file 
End
