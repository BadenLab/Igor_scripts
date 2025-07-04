#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
// Author: Tom Baden
function find_mergedRF_ranks()

wave STRF_corr0
wave positions

variable nROIs = Dimsize(positions,0)

make /o/n=(nROIs) rank = x
sort positions, rank

//make /o/n=(

duplicate /o STRF_corr0 STRFs_ranked
make /o/n=(nROIs) suspiciouspositions = NaN
variable rr
for (rr=0;rr<nROIs;rr+=1)
	STRFs_ranked[][][rr]=STRF_corr0[p][q][rank[rr]]

	if (rank[rr]>100 && rank[rr]<130)
		suspiciouspositions[rr]= positions[rr]
	endif


endfor
make /o/n=(nROIs) suspects = x
rank[]=(rank[p]>100 && rank[p] <130)?(1):(0)

sort rank, suspects

end