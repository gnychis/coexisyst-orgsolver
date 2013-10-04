############################################
## Wrappers around different objective functions

include "spectrum_optimization.zpl";

maximize sumAirtime:
  sum <r> in R with RDATA[r,"dAirtime"]>0 : GoodAirtime[r];
