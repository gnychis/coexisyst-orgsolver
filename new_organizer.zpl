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

############################################################################################################################################
# VARIABLES
##############
#

  var af[TF] binary;          # A binary representation of which radios picks which frequency
  var o[R*R] binary;          # Do the radios, given their center frequencies, overlap?  Specifying binary means it will be 0 or 1...
  var q[QD] binary;           # The linear representation of ___ ^ ____ ^ ____
  var a[R] real;              # Airtime is a real number for each radios between 0 and 1.
  var residual[R] real;       # The residual airtime sensed for each radio.
 
  # ***************************************************************************************************
  # Variables related to finding the min between rfs (the max between residual and fairshare) and
  # the desired airtime, because you can't get more than what you ask for!
  # ... I call this 'eat' : expected airtime
  var eat[R];
  var eat_min_y[R] binary;
  param eat_min_M := 100;
  
  # ***************************************************************************************************
  # Variables that are related to calculating the airtime sensed by each radio.
  # There are two main variables here:
  #   * ats:       the sum of the airtime sensed by all radios
  #   * ats_act:   min(sum,1) so that it doesn't exceed 1
  var ats[R];
  var ats_act[R];
  var ats_min_lhv[R];
  param ats_min_rhv := 1;
  var ats_min_y[R] binary;
  param ats_min_M := 100;
  
  # ***************************************************************************************************
  # Variables that are related to calculating the loss rate for each network which is a product.
  # This computes the product in the most linear-way possible.
  var lossrate[R] real >= 0 <= 1; 
  var sr_vals[R*R] real;    # For each radio, calculate loss rate due to each radio
  var sr_vars[R*R] real;    # For the calculation of loss rate using a product

  # ***************************************************************************************************
  # For calculating the rough estimated of an expected "fair share" (fs) of airtime due to radios that
  # the radio coordinates with.
  var fs[R];
  var nsharing[R];
  
  # ***************************************************************************************************
  # Calculation of the max(residual,fairshare)
  var rfs_max[R];
  var rfs_max_y[R] binary;
  param rfs_max_M := 100;


############################################################################################################################################
# CONSTRAINTS
################
#
  subto valid_freq:                     # The frequency selected by each network must be one in its list
    forall <i,f> in TF with IS_AVAIL_FREQ(i,f)==0 : af[i,f] == 0;
  
  subto active_freq:                    # Every network must have one center frequency considered active.
    forall <i> in R : sum <f> in F : af[i,f] == 1; 
  
  subto airtime_is_positive:            # Ensure that the airtime of all networks is positive, it cannot be a negative value.
    forall <i> in R : a[i] >= 0;
