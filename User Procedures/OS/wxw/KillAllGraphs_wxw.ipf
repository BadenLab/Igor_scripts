#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function KillAllGraphs_wxw()
    string fulllist = WinList("*", ";","WIN:1")
    string name, cmd
    variable i
   
    for(i=0; i<itemsinlist(fulllist); i +=1)
        name= stringfromlist(i, fulllist)
        sprintf  cmd, "Dowindow/K %s", name
        execute cmd    
    endfor
end