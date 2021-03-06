# Spectrum Organization solver
#
# High Level notes:
#   - Parameters are used to define constants within ZIMPL
#
# Input:
#   <int: network_id> <int: network_TYPE> <float: desired_airtime> <int: avg_tx_length_in_us>
#
# Network Types: 
#   1: Wifi (802.11g: standard preamble)
#   2: Wifi (802.11n: greenfield preamble)
#   3: ZigBee
#   4: Analog Phone
#
# Implement TYPEs as a tuple, index value at, like: <"bandwidth", 3>

############################################################################################################################################
# INPUTS
##############
#

  set   W       := { read "networks.dat" as "<1n>" comment "#"};       # unique set of network IDs
  param TYPE[W] := read "networks.dat" as "<1n> 2s" comment "#";       # the network TYPEs for each network
  param D[W]    := read "networks.dat" as "<1n> 3n" comment "#";       # the desired airtime for each network
  param B[W]    := read "networks.dat" as "<1n> 4n" comment "#";       # the bandwidth in KHz for each network
  param T[W]    := read "networks.dat" as "<1n> 5n" comment "#";       # average TX time in us for each network

  include "unified_coordination.zpl";   # imports a variable Q := <1,1> 0, <1,2> 0, <1,3> 1 ...


############################################################################################################################################
# CONSTANTS
##############
#

  set Protocols := { "802.11agn", "802.11n", "ZigBee", "Analog"};

  include "network_frequencies.zpl";

  # The total set of frequencies.  This is not in the formalization, but a requirement to fit the language and solvers.  This is a union
  #   of all possible frequencies which are then used to construct a table for each network about which frequency is usable given the protocol.
  set F  := union <i> in W : FB[i];
  set TF := W*F;   # Creating a set of all possible networks and frequencies
  set QD := W*W*F*F;


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

  # This calculates the expected loss rate of two networks given the Airtime of U (Au), and the
  #   two average transmission lengths of both networks Tu and Ti, assuming that they are independent
  #   processes, modeled as Poisson.
  defnumb sigma(Au,Tu,Ti) := 1 - exp( (-Au / (Tu + Ti)));

############################################################################################################################################
# VARIABLES
##############
#

  var af[TF] binary;          # A binary representation of which network picks which frequency
  var o[W*W] binary;          # Do the networks, given their center frequencies, overlap?  Specifying binary means it will be 0 or 1...
  var q[QD] binary;           # The linear representation of ___ ^ ____ ^ ____
  var a[W] real;              # Airtime is a real number for each network between 0 and 1.
  var residual[W] real;       # The residual airtime sensed for each network.
  
  # ***************************************************************************************************
  # Variables related to finding the min between rfs (the max between residual and fairshare) and
  # the desired airtime, because you can't get more than what you ask for!
  # ... I call this 'eat' : expected airtime
  var eat[W];
  var eat_min_y[W] binary;
  param eat_min_M := 100;

  # ***************************************************************************************************
  # Variables that are related to calculating the airtime sensed by each network.
  # There are two main variables here:
  #   * ats:       the sum of the airtime sensed by all networks
  #   * ats_act:   min(sum,1) so that it doesn't exceed 1
  var ats[W];
  var ats_act[W];
  var ats_min_lhv[W];
  param ats_min_rhv := 1;
  var ats_min_y[W] binary;
  param ats_min_M := 100;
  
  # ***************************************************************************************************
  # Variables that are related to calculating the loss rate for each network which is a product.
  # This computes the product in the most linear-way possible.
  var lossrate[W] real >= 0 <= 1; 
  var sr_vals[W*W] real;    # For each network, calculate loss rate due to each network
  var sr_vars[W*W] real;    # For the calculation of loss rate using a product
  
  # ***************************************************************************************************
  # For calculating the rough estimated of an expected "fair share" (fs) of airtime due to networks that
  # the network coordinates with.
  var fs[W];
  var nsharing[W];

  # ***************************************************************************************************
  # Calculation of the max(residual,fairshare)
  var rfs_max[W];
  var rfs_max_y[W] binary;
  param rfs_max_M := 100;

############################################################################################################################################
# OBJECTIVE FUNCTION
################
#
  maximize min_prop_airtime: 
    sum <i> in W : a[i] / D[i]; 


############################################################################################################################################
# CONSTRAINTS
################
#
  subto valid_freq:                     # The frequency selected by each network must be one in its list
    forall <i,f> in TF with IS_AVAIL_FREQ(i,f)==0 : af[i,f] == 0;

  subto active_freq:                    # Every network must have one center frequency considered active.
    forall <i> in W : sum <f> in F : af[i,f] == 1; 

  subto airtime_is_positive:            # Ensure that the airtime of all networks is positive, it cannot be a negative value.
    forall <i> in W : a[i] >= 0;

  subto airtime_lte_desired:            # The actual airtime for each network cannot exceed the desired airtime of the network.
    forall <i> in W : a[i] <= D[i];

  subto airtime_eq_residual:            # The airtime is equal to the max of residual and fairshare, minus loss
    forall <i> in W : a[i] == eat[i] * (1 - lossrate[i]);

  # ***************************************************************************************************
  # The top most function is that you get the max of residual and airtime, but then you must take the
  # min of the desired airtime with the result of that function.  That way you never have more than
  # you ask for.
  subto eat_lte_rfs:                    # eat has to be less than max(residual,fairshare)
    forall <i> in W : eat[i] <= rfs_max[i];

  subto eat_lte_D:                      # eat has to be less than your desired airtime
    forall <i> in W : eat[i] <= D[i];

  subto eat_c1:                         # A possible constraint given the min substitution
    forall <i> in W : -eat[i] <= -rfs_max[i] + eat_min_M*eat_min_y[i];

  subto eat_c2:                         # A possible constraint ...
    forall <i> in W : -eat[i] <= -D[i] + eat_min_M*(1-eat_min_y[i]);
  
  # ***************************************************************************************************
  # Calculating the max of residual airtime and the fairshare, giving the maximum of them
  subto rfs_max_gt_residual:            # rfs_max has to be greater than the residual
    forall <i> in W : rfs_max[i] >= residual[i];

  subto rfs_max_gt_fs:                  # rfs_max has to be greater than the fair share
    forall <i> in W : rfs_max[i] >= fs[i];

  subto rfs_max_c1:                     # A possible constraint given the max LP sub
    forall <i> in W : -rfs_max[i] + rfs_max_M*rfs_max_y[i] >= -residual[i];

  subto rfs_max_c2:                     # A possible constraint...
    forall <i> in W : -rfs_max[i] + rfs_max_M*(1-rfs_max_y[i]) >= -fs[i];

  # ***************************************************************************************************
  # Related to calculating the fairshare of airtime for each network
  subto nsharing_eq:                    # The number of networks sharing a frequency with each other
    forall <i> in W : nsharing[i] == sum <c> in C[i] with c!=i : o[i,c];

  subto fs_eq:                          # Expected fs[i] equal to 1/nsharing, just written without division
    forall <i> in W : fs[i] * (nsharing[i]+1) == 1;
  
  # ***************************************************************************************************
  # Related to calculating the lossrate variable
  subto lossrate_eq:                    # Lossrate is the last variable in the series of multiplications (variables)
    forall <i> in W : lossrate[i] == 1 - sr_vars[i,card(W)];
  
  subto sr_vars_eq_inC:                 # Success rate for every network in C is considered to be 1
    forall <i> in W : forall <c> in C[i]  : sr_vals[i,c] == 1;

  subto lossrate_prod_vals_eq:          # Loss rate on network i due to network u
    forall <i> in W : forall <u> in U[i] : sr_vals[i,u] == (1 - exp(- (D[u] / T[u]) * (T[i] + T[u]))  * o[i,u]);

  subto lossrate_prod_vars_eq_init:     # Initialize the first multiplication in the chain
    forall <i> in W : sr_vars[i,1] == sr_vals[i,1];

  subto lossrate_prod_vars_eq:          # Loss rate variables which is a chain of multiplications
    forall <i> in W : forall <j> in W with j!=1 : sr_vars[i,j] == sr_vars[i,j-1] * sr_vals[i,j];

  # ***************************************************************************************************
  # Related to substitution for the min() in the airtime sensed so that the "actual" sensed is <= 1.
  # The residual airtime ends up being 1 minus this value
  subto ats_eq:                         # The airtime each network senses is equal to...
    forall <i> in W : ats[i] == sum <c> in C[i] with (c!=i) : (D[c] * o[i,c]);

  subto ats_min_lhv_eq:                 # The left hand value of the min for airtime sensed is airtime sensed
    forall <i> in W : ats_min_lhv[i] == ats[i];

  subto ats_min1:                       # The value (ats_act)  must be less than the lhv
    forall <i> in W : ats_act[i] <= ats_min_lhv[i];

  subto ats_min2:                       # The value (ats_act) must be less than the rhv (fixed to 1)
    forall <i> in W : ats_act[i] <= ats_min_rhv;

  subto ats_min_c1:                     # A possible constraint given the min LP sub (see example in 'lp_substitutions/')
    forall <i> in W : -ats_act[i] <= -ats_min_lhv[i] + ats_min_M*ats_min_y[i];

  subto ats_min_c2:                     # A possible constraint...
    forall <i> in W : -ats_act[i] <= -ats_min_rhv + ats_min_M*(1-ats_min_y[i]);
  
  subto residual_eq:                    # The residual is equal to 1 minus the airtime sensed
    forall <i> in W : residual[i] == 1 - ats_act[i];

  # ***************************************************************************************************
  # Related to substitution for  O_ifrf ^ f_i ^ f_r
  subto af_overlap:                     # Whether the active frequencies for two networks overlap
    forall <i> in W : forall <r> in W with i != r : o[i,r] == sum <i,fi> in TF : sum <r,fr> in TF : q[i,r,fi,fr];
  
  subto q_c1:                           # Must be less than whether or not the frequencies overlap
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= O(fi,B[i],fr,B[r]);

  subto q_c2:                           # Must be less than whether or not i is using frequency fi
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[i,fi];

  subto q_c3:                           # Must be less than whether or not r is using frequency fr
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[r,fr];

  subto q_c4:                           # Must be greater than the sum of the them
    forall <i,r,fi,fr> in QD: q[i,r,fi,fr] >= O(fi,B[i],fr,B[r]) + af[i,fi] + af[r,fr] - 2;


############################################################################################################################################
# INPUT CHECK
################
# The following checks below are checks for valid input.  For these we do not need constraints since they do
#   not change with execution.  We just need to make sure they are valid inputs.

  # This is a check to make sure that the specified desired airtimes are legit.
  do forall <i> in W do check D[i] >= 0 and D[i] <= 1;

  # Make sure that the protocols for each network are ones that are valid and supported.
  do forall <i> in W do check card( { TYPE[i] } inter Protocols ) == 1;

  # Ensure that bandwidth is positive
  do forall <i> in W do check B[i] > 0;
