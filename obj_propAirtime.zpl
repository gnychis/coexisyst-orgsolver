############################################
## Wrappers around different objective functions

include "spectrum_optimization.zpl";

maximize min_prop_airtime: 
  sum <r> in R with RDATA[r,"dAirtime"]>0 : GoodAirtime[r] / RDATA[r,"dAirtime"]; 
