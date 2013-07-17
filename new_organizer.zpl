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
  set F  := union <r> in R : FR[r];
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
      if( card( { freq } inter FL[i] ) == 1)
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
  var GoodAirtime[R] real;              # Airtime is a real number for each radios between 0 and 1.
  var Residual[R] real;       # The residual airtime sensed for each radio.
 
  # ***************************************************************************************************
  # Variables related to finding the min between rfs (the max between residual and fairshare) and
  # the desired airtime, because you can't get more than what you ask for!
  var Airtime[R];
  var airtime_min_y[R] binary;
  param airtime_min_M := 100;
  
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
  var FairShare[R];
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
    forall <r> in R : sum <f> in F : af[r,f] == 1; 
  
  subto airtime_is_positive:            # Ensure that the airtime of all networks is positive, it cannot be a negative value.
    forall <r> in R : GoodAirtime[r] >= 0;
  
  subto airtime_lte_desired:            # The actual airtime for each network cannot exceed the desired airtime of the network.
    forall <r> in R : GoodAirtime[r] <= RDATA[r,"dAirtime"];

  subto airtime_eq_residual:            # The airtime is equal to the max of residual and fairshare, minus loss
    forall <r> in R : GoodAirtime[r] == Airtime[r]; #* (1 - lossrate[i]);

  # ***************************************************************************************************
  # The top most function is that you get the max of residual and airtime, but then you must take the
  # min of the desired airtime with the result of that function.  That way you never have more than
  # you ask for.
  subto airtime_lte_rfs:                    # airtime has to be less than max(residual,fairshare)
    forall <r> in R : Airtime[r] <= rfs_max[r];

  subto airtime_lte_D:                      # airtime has to be less than your desired airtime
    forall <r> in R : Airtime[r] <= RDATA[r,"dAirtime"];

  subto airtime_c1:                         # A possible constraint given the min substitution
    forall <r> in R : -Airtime[r] <= -rfs_max[r] + airtime_min_M*airtime_min_y[r];

  subto airtime_c2:                         # A possible constraint ...
    forall <r> in R : -Airtime[r] <= -RDATA[r,"dAirtime"] + airtime_min_M*(1-airtime_min_y[r]);

  # ***************************************************************************************************
  # Related to calculating the fairshare of airtime for each network
  subto nsharing_eq:                    # The number of networks sharing a frequency with each other
    forall <r> in R : nsharing[r] == sum <l> in ROL[r] : o[r,l];

  subto fs_eq:                          # Expected FairShare[i] equal to 1/nsharing, just written without division
    forall <r> in R : FairShare[r] * (nsharing[r]+1) == 1;

  # ***************************************************************************************************
  # Calculating the max of residual airtime and the fairshare, giving the maximum of them
  subto rfs_max_gt_residual:            # rfs_max has to be greater than the residual
    forall <r> in R : rfs_max[r] >= Residual[r];

  subto rfs_max_gt_fs:                  # rfs_max has to be greater than the fair share
    forall <r> in R : rfs_max[r] >= FairShare[r];

  subto rfs_max_c1:                     # A possible constraint given the max LP sub
    forall <r> in R : -rfs_max[r] + rfs_max_M*rfs_max_y[r] >= -Residual[r];

  subto rfs_max_c2:                     # A possible constraint...
    forall <r> in R : -rfs_max[r] + rfs_max_M*(1-rfs_max_y[r]) >= -FairShare[r];

  # ***************************************************************************************************
  # Related to calculating the lossrate variable
#  subto lossrate_eq:                    # Lossrate is the last variable in the series of multiplications (variables)
#    forall <i> in L : lossrate[i] == 1 - sr_vars[i,card(L)];
#  
#  subto sr_vars_eq_inC:                 # Success rate for every network in C is considered to be 1
#    forall <i> in L : forall <c> in LC[i]  : sr_vals[i,c] == 1;
#
#  subto lossrate_prod_vals_eq:          # Loss rate on network i due to network u
#    forall <i> in L : forall <u> in LU[i] : sr_vals[i,u] == (1 - exp(- (LDATA[u,"dAirtime"] / LDATA[u,"txLen"]) * (LDATA[i,"txLen"] + LDATA[u,"txLen"]))  * o[i,u]);
#
#  subto lossrate_prod_vars_eq_init:     # Initialize the first multiplication in the chain
#    forall <i> in L : sr_vars[i,1] == sr_vals[i,1];
#
#  subto lossrate_prod_vars_eq:          # Loss rate variables which is a chain of multiplications
#    forall <i> in L : forall <j> in L with j!=1 : sr_vars[i,j] == sr_vars[i,j-1] * sr_vals[i,j];

  # ***************************************************************************************************
  # Related to substitution for the min() in the airtime sensed so that the "actual" sensed is <= 1.
  # The residual airtime ends up being 1 minus this value
  subto ats_eq:                         # The airtime each network senses is equal to...
    forall <r> in R : ats[r] == sum <c> in C[r] : (RDATA[c,"dAirtime"] * o[r,c]);

  subto ats_min_lhv_eq:                 # The left hand value of the min for airtime sensed is airtime sensed
    forall <i> in L : ats_min_lhv[i] == ats[i];

  subto ats_min1:                       # The value (ats_act)  must be less than the lhv
    forall <i> in L : ats_act[i] <= ats_min_lhv[i];

  subto ats_min2:                       # The value (ats_act) must be less than the rhv (fixed to 1)
    forall <i> in L : ats_act[i] <= ats_min_rhv;

  subto ats_min_c1:                     # A possible constraint given the min LP sub (see example in 'lp_substitutions/')
    forall <i> in L : -ats_act[i] <= -ats_min_lhv[i] + ats_min_M*ats_min_y[i];

  subto ats_min_c2:                     # A possible constraint...
    forall <i> in L : -ats_act[i] <= -ats_min_rhv + ats_min_M*(1-ats_min_y[i]);
  
  subto residual_eq:                    # The residual is equal to 1 minus the airtime sensed
    forall <i> in L : Residual[i] == 1 - ats_act[i];
  
  # ***************************************************************************************************
  # Related to substitution for  O_ifrf ^ f_i ^ f_r
  subto af_overlap:                     # Whether the active frequencies for two networks overlap
    forall <i> in R : forall <r> in R with i != r : o[i,r] == sum <i,fi> in TF : sum <r,fr> in TF : q[i,r,fi,fr];
  
  subto q_c1:                           # Must be less than whether or not the frequencies overlap
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= O(fi,RDATA[i,"bandwidth"],fr,RDATA[r,"bandwidth"]);

  subto q_c2:                           # Must be less than whether or not i is using frequency fi
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[i,fi];

  subto q_c3:                           # Must be less than whether or not r is using frequency fr
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[r,fr];

  subto q_c4:                           # Must be greater than the sum of the them
    forall <i,r,fi,fr> in QD: q[i,r,fi,fr] >= O(fi,RDATA[i,"bandwidth"],fr,RDATA[r,"bandwidth"]) + af[i,fi] + af[r,fr] - 2;

############################################################################################################################################
# INPUT CHECK
################
# The following checks below are checks for valid input.  For these we do not need constraints since they do
#   not change with execution.  We just need to make sure they are valid inputs.

  # This is a check to make sure that the specified desired airtimes are legit.
  do forall <i> in L do check LDATA[i,"dAirtime"] >= 0 and LDATA[i,"dAirtime"] <= 1;
  do forall <i> in R do check RDATA[i,"dAirtime"] >= 0 and RDATA[i,"dAirtime"] <= 1;

  # Ensure that bandwidth is positive
  do forall <i> in L do check RDATA[i,"bandwidth"] > 0;
  do forall <i> in R do check RDATA[i,"bandwidth"] > 0;

############################################################################################################################################
# OBJECTIVE FUNCTION
################
#
  maximize min_prop_airtime: 
    sum <r> in R : GoodAirtime[r] / RDATA[r,"dAirtime"]; 
