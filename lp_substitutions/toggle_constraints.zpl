set I := {1,2,3};
param v[I] := <1> -3, <2> -2.8, <3> -1;
var y[I] binary;
param N := 5;

param x := -2.5;

param delta := 0.001;

subto toggle_ind1:
  forall <i> in I : y[i] >= ((x-v[i]) / N) + (delta / (2*N));

subto toggle_ind2:
  forall <i> in I : y[i] <= 1 + ((x-v[i])/N);

#subto lower:  # if x < -2
#  expVal == exp(v[1]) + exp(v[1])*x - exp(v[1])*v[1];
#
#subto mid:    # if x >= -2 and x < -1
#  expVal == exp(v[2]) + exp(v[2])*x - exp(v[2])*v[2];
#
#subto high:   # if x >= -1
#  expVal == exp(v[3]) + exp(v[3])*x - exp(v[3])*v[3];
