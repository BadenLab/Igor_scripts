#pragma rtGlobals=3

Function CorrectTTLSignal(inputWave)
    Wave inputWave
    
    // Check if wave exists
    if (!WaveExists(inputWave))
        Print "Error: Wave does not exist"
        return -1
    endif
    
    // Get wave dimensions
    Variable numLayers = DimSize(inputWave, 2)
    if (numLayers == 0)
        Print "Error: Wave appears to be less than 3D"
        return -1
    endif
    
    // Check if first frame is under 45000
    MatrixOp/O tempFrame = layer(inputWave, 0)
    Variable firstFrameAvg = mean(tempFrame)
    
    if (firstFrameAvg >= 45000)
        Print "First frame is already high (", firstFrameAvg, "). No correction needed."
        return 0
    endif
    
    Print "First frame is low (", firstFrameAvg, "). Searching for correction points..."
    
    // Find where the TTL pulses actually start (first significant change from baseline)
    Variable baselineEnd = -1
    Variable i
    Variable baseline = firstFrameAvg  // Use first frame as baseline reference
    
    // Look for the end of the flat baseline period
    for (i = 1; i < numLayers; i += 1)
        MatrixOp/O tempFrame = layer(inputWave, i)
        Variable frameAvg = mean(tempFrame)
        
        // If we see a big jump from baseline, this is where TTL pulses start
        if (abs(frameAvg - baseline) > 10000)  // Significant change from baseline
            baselineEnd = i - 1  // Last frame that was still baseline
            Print "Baseline period ends at frame ", baselineEnd
            Print "TTL pulses start at frame ", i, " (value change: ", baseline, " -> ", frameAvg, ")"
            break
        endif
    endfor
    
    if (baselineEnd == -1)
        Print "Error: Could not find where TTL pulses start"
        return -1
    endif
    
    // Only correct the baseline period (before TTL pulses start)
    Print "Setting baseline frames 0 to ", baselineEnd, " to value 58000"
    
    for (i = 0; i <= baselineEnd; i += 1)
        inputWave[][][i] = 58000
    endfor
    
    Print "TTL correction completed successfully!"
    Print "Corrected ", baselineEnd + 1, " baseline frames, preserved TTL pulses from frame ", baselineEnd + 1
    
    return baselineEnd + 1  // Return number of frames corrected
End

// Convenience function to run on wDataCh2
Function CorrectWDataCh2TTL()
    Wave wDataCh2
    
    if (!WaveExists(wDataCh2))
        Print "Error: wDataCh2 wave does not exist"
        return -1
    endif
    
    return CorrectTTLSignal(wDataCh2)
End