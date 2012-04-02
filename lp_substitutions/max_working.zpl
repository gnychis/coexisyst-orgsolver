param a := 3;
param b := 4;
param M := 100;
var z;
var y binary;

maximize goal: z;

subto min_za:
  z >= a;

subto min_zb:
  z >= b;

subto c1:
  -z + M*y >= -a;

subto c2:
  -z + M*(1-y) >= -b;
