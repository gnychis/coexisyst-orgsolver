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

  set Protocols := { "802.11g", "802.11n", "ZigBee", "AnalogPhone" };

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
  #var s[W] real >= 0 <= 1;   # The sustained interference on each network is a real number between 0 and 1 (loss rate due to uncoordination)

  # ***************************************************************************************************
  # Variables related to calculating the residual airtime for each network.  The additional variables
  # are related to accounting for the min(Desired,Residual).  This uses an LP substitution for min().
  var residual[W] real;
  var residual_min_lhv[W];
  var residual_min_rhv[W];
  var residual_min[W];
  var residual_min_y[W] binary;
  param residual_min_M := 100;
  # ***************************************************************************************************

  # ***************************************************************************************************
  # Variables that are related to calculating the airtime sensed by each network.
  # There are two main variables here:
  #   * airtime_sensed:       the sum of the airtime sensed by all networks
  #   * airtime_sensed_act:   min(sum,1) so that it doesn't exceed 1
  var airtime_sensed[W];
  var airtime_sensed_act[W];
  var airtime_sensed_min_lhv[W];
  param airtime_sensed_min_rhv := 1;
  var airtime_sensed_min_y[W] binary;
  param airtime_sensed_min_M := 100;
  # ***************************************************************************************************
  
  # ***************************************************************************************************
  # Variables that are related to calculating the loss rate for each network which is a product.
  # This computes the product in the most linear-way possible.
  var lossrate[W] real >= 0 <= 1; 
  var sr_vals[W*W] real;    # For each network, calculate loss rate due to each network
  var sr_vars[W*W] real;    # For the calculation of loss rate using a product
  # ***************************************************************************************************


############################################################################################################################################
# OBJECTIVE FUNCTION
################
#
  maximize min_prop_airtime: 
    sum <i> in W : a[i]; 


############################################################################################################################################
# CONSTRAINTS
################
#

  subto valid_freq:             # The frequency selected by each network must be one in its list, if not it cannot be used and must have a val of 0.
    forall <i,f> in TF with IS_AVAIL_FREQ(i,f)==0 : af[i,f] == 0;

  subto active_freq:            # Every network must have one center frequency considered active.
    forall <i> in W : sum <f> in F : af[i,f] == 1; 

  subto airtime_is_positive:    # Ensure that the airtime of all networks is positive, it cannot be a negative value.  Worst case is nothing.
    forall <i> in W : a[i] >= 0;

  subto airtime_lte_desired:    # The actual airtime for each network cannot exceed the desired airtime of the network.
    forall <i> in W : a[i] <= D[i];

  subto airtime_eq_residual:    # The airtime is equal to the residual minus the loss rate...
    forall <i> in W : a[i] == residual[i]  * (1 - lossrate[i]);

  # ***************************************************************************************************
  # Related to calculating the lossrate variable
  subto lossrate_eq:    # Lossrate is the last variable in the series of multiplications (variables)
    forall <i> in W : lossrate[i] == sr_vars[i,card(W)];
  
  subto sr_vars_eq_inC:   # Success rate for every network in C is considered to be 1
    forall <i> in W : forall <c> in C[i]  : sr_vals[i,c] == 1;

  subto lossrate_prod_vals_eq:          # Loss rate on network i due to network u
    forall <i> in W : forall <u> in U[i] : sr_vals[i,u] == (1 - exp(- (D[u] / T[u]) * (T[i] + T[u]))  * o[i,u]);

  subto lossrate_prod_vars_eq_init:     # Initialize the first multiplication in the chain
    forall <i> in W : sr_vars[i,1] == sr_vals[i,1];

  subto lossrate_prod_vars_eq:          # Loss rate variables which is a chain of multiplications
    forall <i> in W : forall <j> in W with j!=1 : sr_vars[i,j] == sr_vars[i,j-1] * sr_vals[i,j];
  # ***************************************************************************************************

  # ***************************************************************************************************
  # Related to substitution for the min() in the airtime sensed so that the "actual" sensed is <= 1
  subto airtime_sensed_eq:      # The airtime each network senses is equal to...
    forall <i> in W : airtime_sensed[i] == sum <c> in C[i] with (c!=i) : (D[c] * o[i,c]);

  subto airtime_sensed_min_lhv_eq:  # The left hand value of the min for airtime sensed is airtime sensed
    forall <i> in W : airtime_sensed_min_lhv[i] == airtime_sensed[i];

  subto airtime_sensed_min1:        # The value (airtime_sensed_act)  must be less than the lhv
    forall <i> in W : airtime_sensed_act[i] <= airtime_sensed_min_lhv[i];

  subto airtime_sensed_min2:        # The value (airtime_sensed_act) must be less than the rhv (fixed to 1)
    forall <i> in W : airtime_sensed_act[i] <= airtime_sensed_min_rhv;

  subto airtime_sensed_min_c1:      # A possible constraint given the min LP sub (see example in 'lp_substitutions/')
    forall <i> in W : -airtime_sensed_act[i] <= -airtime_sensed_min_lhv[i] + airtime_sensed_min_M*airtime_sensed_min_y[i];

  subto airtime_sensed_min_c2:      # A possible constraint...
    forall <i> in W : -airtime_sensed_act[i] <= -airtime_sensed_min_rhv + airtime_sensed_min_M*(1-airtime_sensed_min_y[i]);
  
  # ***************************************************************************************************
  # Related to substitution for the min() in the residual
  subto residual_min:     # The residual is equal to our subsitution for the min, 'z'
    forall <i> in W : residual[i] == residual_min[i];

  subto residual_min_lhv_eq:  # The left hand value in the min function: min(lhv,rhv)
    forall <i> in W : residual_min_lhv[i] == D[i];

  subto residual_min_rhv_eq:  # The right hand value in the min function: min(lhv,rhv)
    forall <i> in W : residual_min_rhv[i] == 1 - airtime_sensed_act[i];

  subto residual_min1:      # The subsitution variable 'z' must be less than LHV
    forall <i> in W : residual_min[i] <= residual_min_lhv[i];

  subto residual_min2:      # The subsitution variable 'z' must be less than RHV
    forall <i> in W : residual_min[i] <= residual_min_rhv[i];

  subto residual_min_c1:    # A possible constraint given the min LP sub (see example in 'lp_substitutions/') 
    forall <i> in W : -residual_min[i] <= -residual_min_lhv[i] + residual_min_M*residual_min_y[i];

  subto residual_min_c2:    # A possible constraint ...
    forall <i> in W : -residual_min[i] <= -residual_min_rhv[i] + residual_min_M*(1-residual_min_y[i]);
  # ***************************************************************************************************


  # ***************************************************************************************************
  # Related to substitution for  O_ifrf ^ f_i ^ f_r
  subto af_overlap:             # Whether the active frequencies for two networks overlap
    forall <i> in W : forall <r> in W with i != r : o[i,r] == sum <i,fi> in TF : sum <r,fr> in TF : q[i,r,fi,fr];
  
  subto q_c1:                   # Must be less than whether or not the frequencies overlap
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= O(fi,B[i],fr,B[r]);

  subto q_c2:                   # Must be less than whether or not i is using frequency fi
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[i,fi];

  subto q_c3:                   # Must be less than whether or not r is using frequency fr
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[r,fr];

  subto q_c4:                   # Must be greater than the sum of the them
    forall <i,r,fi,fr> in QD: q[i,r,fi,fr] >= O(fi,B[i],fr,B[r]) + af[i,fi] + af[r,fr] - 2;
  # ***************************************************************************************************

#subto sustained_between_01:   # Sustained interference is a loss rate, which must be between 0 and 1.
#  forall <i> in W : s[i] >= 0 and s[i] <= 1;


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
