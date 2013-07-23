set I := {1,2,3};
param v[I] := <1> -3, <2> -2.8, <3> -1;
var y[I] binary;
var p;

param x := -2.5;
param N := 5;

param delta := 0.001;

subto first:
  forall <i> in I : y[i] >= ((x-v[i]) / N) + (delta / (2*N));

subto second:
  forall <i> in I : y[i] <= 1 + ((x-v[i])/N);

subto third:
  p <= 8;

maximize blah: p;
