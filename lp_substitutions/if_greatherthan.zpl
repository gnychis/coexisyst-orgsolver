set I := {1,2,3};
param v[I] := <1> -0.5, <2> -2.8, <3> -1;
var y[I] binary;
var p;

param x := -1;
param N := 5;

param delta := 0.001;

subto first:
  y[1] >= ((x-v[1]) / N) + (delta / (2*N));

subto second:
  y[1] <= 1 + ((x-v[1])/N);

subto third:
  p <= 8;

maximize blah: p;
