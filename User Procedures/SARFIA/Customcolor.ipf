#pragma rtGlobals=1		// Use modern global access method.

// rainbowLUT(levels, outputwave) generates a lookup table with a number of
// different colours equal to levels. Outputwave will be the name of the so generated
// lookup table.

function rainbowLUT(levels, outputwave)
variable levels
String outputwave

if (levels < 6)
	levels = 6
endif

variable  counter = 0, white = 65535, steps = levels / 6, counter2=1
make /o/n=(levels+1,3) colorcalcwave = white

//red-yellow
for (counter=0;counter<steps;counter+=1)
	colorcalcwave[counter2][0] = white
	colorcalcwave[counter2][1] = white*counter/steps
	colorcalcwave[counter2][2] = 0
	counter2+=1
endfor

//yellow-green
for (counter=0;counter<steps;counter+=1)
	colorcalcwave[counter2][0] = white - white*counter/steps
	colorcalcwave[counter2][1] = white
	colorcalcwave[counter2][2] = 0
	counter2+=1
endfor

//green-cyan
for (counter=0;counter<steps;counter+=1)
	colorcalcwave[counter2][0] = 0
	colorcalcwave[counter2][1] = white
	colorcalcwave[counter2][2] = white*counter/steps
	counter2+=1
endfor

//cyan-blue
for (counter=0;counter<steps;counter+=1)
	colorcalcwave[counter2][0] = 0
	colorcalcwave[counter2][1] = white- white*counter/steps
	colorcalcwave[counter2][2] = white
	counter2+=1
endfor

//blue-magenta
for (counter=0;counter<steps;counter+=1)
	colorcalcwave[counter2][0] = white*counter/steps
	colorcalcwave[counter2][1] = 0
	colorcalcwave[counter2][2] = white
	counter2+=1
endfor

//magenta-red
for (counter=0;counter<steps;counter+=1)
	colorcalcwave[counter2][0] = white
	colorcalcwave[counter2][1] = 0
	colorcalcwave[counter2][2] = white - white*counter/steps
	counter2+=1
endfor



duplicate /o colorcalcwave, $outputwave
killwaves /z colorcalcwave

return counter2
end



