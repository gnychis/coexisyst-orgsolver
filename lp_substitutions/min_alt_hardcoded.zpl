param a := 8;
param b := 3;
param M := 100000000;
var z;
var y binary;

minimize goal: z;

subto min_za:
  z <= a;

subto min_zb:
  z <= b;

subto min_c1:
  -z <= -b;
