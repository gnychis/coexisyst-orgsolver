############################################################################################################################################
# INPUTS
##############
#

  include "data.zpl";

############################################################################################################################################
# CONSTANTS
##############
#
  
  # The total set of frequencies.  This is not in the formalization, but a requirement to fit the language and solvers.  This is a union
  #   of all possible frequencies which are then used to construct a table for each radio about which frequency is usable given the protocol.
  set F  := union <i> in R : FB[i];
  set TF := R*F;   # Creating a set of all possible radios and frequencies
  set QD := R*R*F*F;


############################################################################################################################################
# FUNCTIONS
##############
#

  # Defining low and high frequencies of a center frequency with a given bandwidth
  defnumb LF(f,b) := f-(b/2.0);   # Given a center frequency 'c' and bandwidth 'b', gives the lower frequency bound
  defnumb HF(f,b) := f+(b/2.0);   # Given a center frequency 'c' and bandwidth 'b', gives the upper frequency bound

  # A basic function to test if a number is in the range of two numbers (a low and high)
  defbool INRANGE(num,low,high) := num >= low and num <= high;

  # A function to determine whether two operational bands overlap with each other, given a pair of center
  #   frequencies and bandwidths.
  defnumb O(f1,b1,f2,b2) := 
      if INRANGE( LF(f1,b1), LF(f2,b2), HF(f2,b2) )   # The lower frequency of band1 is in band2
              or  
          INRANGE( LF(f2,b2), LF(f1,b1), HF(f1,b1) )  # The lower frequency of band2 is in band1
      then 
        1   # They overlap with each other
      else 
        0   # They do not overlap with each other
      end;

  defnumb IS_AVAIL_FREQ(i, freq) := 
      if( card( { freq } inter FB[i] ) == 1)
        then
          1
        else
          0
        end;
