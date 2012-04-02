param a := 4;
param b := 9;
var z;
var y binary;

minimize goal: z;

subto min_za:
  z <= a;

subto min_zb:
  z <= b;

#subto min_c1:  # Active if b is elss than a
#  -z <= -b;

subto min_c2:  # Active if a is less than b
  -z <= -a;
