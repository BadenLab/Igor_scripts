#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function KillAllGraphs([num])
// Kill all the graphs with the initial name given
    variable num
    string fulllist, name
    variable i
    if (!paramIsDefault(num))
    	 fulllist = WinList("*", ";","WIN:1")
    	

    	for(i=0; i<num; i +=1)
        	name= stringfromlist(i, fulllist)
        	Dowindow/K $name
    	endfor
    else
    	fulllist = WinList("*", ";","WIN:1")
    	
    	for(i=0; i<itemsinlist(fulllist); i +=1)
        	name= stringfromlist(i, fulllist)
        	Dowindow/K $name
        endfor
    endif
    	
end