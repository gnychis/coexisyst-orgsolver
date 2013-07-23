set I := {1,2,3};
param v[I] := <1> -3, <2> -2.8, <3> -0.1;
var y[I] binary;
var s;
var expVal;
param N := 5;

param x := 0;

param delta := 0.001;

subto toggle_ind1:
  forall <i> in I : y[i] >= ((x-v[i]) / N) + (delta / (2*N));

subto toggle_ind2:
  forall <i> in I : y[i] <= 1 + ((x-v[i])/N);

subto exp_low: 
  0 == (y[1]-y[2])*(exp(v[1]) + exp(v[1])*x - exp(v[1])*v[1] - expVal);

subto exp_mid: 
  0 == (y[2]-y[3])*(exp(v[2]) + exp(v[2])*x - exp(v[2])*v[2] - expVal);

subto exp_high: 
  0 == (y[3])*((exp(v[3]) + exp(v[3])*x - exp(v[3])*v[3]) - expVal);
