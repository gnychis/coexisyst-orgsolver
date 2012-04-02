param x := 9;
param y := 6;
var m;
var z1;
var z2;

maximize goal: m;

subto min_m:
  m == 0.5 * (x + y - z1 - z2);

subto min_z1:
  z1 >= 0;

subto min_z2:
  z2 >= 0;

subto min_z1z2:
  z1 - z2 == x - y;
