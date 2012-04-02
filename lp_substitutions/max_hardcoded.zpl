param a := 1.2;
param b := 1.1;
param M := 100;
var z;
var y binary;

maximize goal: z;

subto min_za:
  z >= a;

subto min_zb:
  z >= b;

subto c1:
  -z >= -a;

#subto c2:
#  -z >= -b;
