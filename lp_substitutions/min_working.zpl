param a := 0.8;
param b := 0.4;
param M := 100;
var z;
var y binary;

maximize goal: z;

subto min_za:
  z <= a;

subto min_zb:
  z <= b;

subto min_c1:
  -z <= -a + M*y;

subto min_c2:
  -z <= -b + M*(1-y);
