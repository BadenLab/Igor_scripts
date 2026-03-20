// Script to set all deltas to 1 for specified waves

Function SetAllDeltasToOne()
    // List of wave names
    String waveList = "rois;stack_ave;stack_sd;wdatach0;wdatach0_detrended;wdatach2;Averages0;snippetstimes0;snippets0"
    String waveName
    Variable i
    
    // Loop through each wave name
    for(i = 0; i < ItemsInList(waveList); i += 1)
        waveName = StringFromList(i, waveList)
        
        // Check if wave exists
        if(WaveExists($waveName))
            // Set all dimension scales with delta = 1, starting at 0
            SetScale/P x, 0, 1, "", $waveName
            SetScale/P y, 0, 1, "", $waveName
            SetScale/P z, 0, 1, "", $waveName
            SetScale/P t, 0, 1, "", $waveName
            Printf "Set all deltas to 1 for %s\r", waveName
        else
            Printf "Warning: Wave %s does not exist\r", waveName
        endif
    endfor
End