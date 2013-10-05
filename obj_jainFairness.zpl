############################################
## Wrappers around different objective functions

include "spectrum_optimization.zpl";

var jainTopSum real;
var jainTop real;
var jainBottom real;
var jainBottomSum real;
var jainN integer;
var jainFairness real;

subto jainN:
  jainN == sum <r> in R with RDATA[r,"dAirtime"]>0 : 1;

subto jainTopSum_eq:
  jainTopSum == sum <r> in R with RDATA[r,"dAirtime"]>0 : airtimeFracs[r];

subto jainTop_eq:
  jainTop == jainTopSum * jainTopSum;

subto jainBottomSum_eq:
  jainBottomSum == sum <r> in R with RDATA[r,"dAirtime"]>0 : airtimeFracs[r] * airtimeFracs[r];

subto jainBottom_eq:
  jainBottom == jainBottomSum * jainN;

subto jainFairness_eq:
  jainBottom * jainFairness == jainTop;
  
maximize jainFair:
  jainFairness;
