# Defining low and high frequencies of a center frequency with a given bandwidth
defnumb LF(f,b) := f-(b/2.0);
defnumb HF(f,b) := f+(b/2.0);

# A basic function to test if a number is in the range of two numbers (a low and high)
defbool INRANGE(num,low,high) := num >= low and num <= high;

# A function to determine whether two frequencies overlap with each other
defnumb O(f1,b1,f2,b2) := 
    if INRANGE( LF(f1,b1), LF(f2,b2), HF(f2,b2) )  or  INRANGE( LF(f2,b2), LF(f1,b1), HF(f1,b1) ) then 
      1
    else 
      0 
    end;

defnumb sigma(Au, Tu, Ti) :=
  1 - exp( (-Au / (Tu + Ti)));
