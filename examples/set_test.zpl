set A := { "a", "b", "c" };
set B := { 1, 2, 3};
set V := { <a,2> in A*B with a == "a" or a == "b" };
do print V;
# will give: { <"a",2>, <"b",2> }
set W := argmin(3) <i,j> in B*B : i+j;
# will give: { <1,1>, <1,2>, <2,1> }
