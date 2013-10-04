############################################
## Wrappers around different objective functions

include "spectrum_optimization.zpl";

var fprod_vals[R];
var fprod_vars[R];
var fprod;

subto fprod_eq:
  fprod == fprod_vars[card(R)];

subto fprod_vals_eq1:
  forall <r> in R with RDATA[r,"dAirtime"]>0 : fprod_vals[r] == airtimeFracs[r];

subto fprod_vals_eq2:
  forall <r> in R with RDATA[r,"dAirtime"]==0 : fprod_vals[r] == 1;

subto fprod_vars_init:
  fprod_vars[1] == fprod_vals[1];

subto fprod_vars_eq:
  forall <r> in R with r!=1 : fprod_vars[r] == fprod_vars[r-1] * fprod_vals[r];

maximize fracProducts:
  fprod;
