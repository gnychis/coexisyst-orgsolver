set W := {1 .. 4 };   # The indexes in the set
param S[W] := <1> 3, <2> 4, <3> 5, <4> 6;   # Creates the set {3,4,5,6} with the proper indexes

var a;  # a non-sense variable

var p[W];             # The product requires W number of variables
var prod_answer;      # Just something to store the answer

maximize goal: 1 + 0*a;  # a bogus goal

subto lprod_1st:      # Initial the product "chain" by setting first value
  p[1] == S[1];

subto lprod:          # Every value after the first is multiplied by answer stored in previous variable
  forall <i> in W with i!=1 : p[i]==p[i-1]*S[i];

subto lprod_ans:      # Our answer is the last variable
  prod_answer == p[card(W)];
