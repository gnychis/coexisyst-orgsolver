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

var af[TF] binary;        # A binary representation of which network picks which frequency
var o[W*W] binary;        # Do the networks, given their center frequencies, overlap?  Specifying binary means it will be 0 or 1...
var q[W*W] binary;        # The linear representation of ___ ^ ____ ^ ____
#var s[W] real >= 0 <= 1;  # The sustained interference on each network is a real number between 0 and 1 (loss rate due to uncoordination)
var a[W]
    real >= 0 <= 1;       # Airtime is a real number for each network between 0 and 1.
var residual[W] real >= 0 <= 1;



############################################################################################################################################
# OBJECTIVE FUNCTION
################
#
#maximize min_prop_airtime: 
#    sum <i> in W :
#     residual[i] * (1 - 
#        (   1 - prod <u> in U[i] : (  1 - sigma(D[u],T[u],T[i]) * 
#                                            ( sum<i,fi> in TF : sum <u,fu> in TF : O(fi,B[i],fu,B[u]) ) 
#                                   )    
#        )  # LossRate
#     )  # Enf of residual * ()
#      / 
#         D[i];


############################################################################################################################################
# CONSTRAINTS
################
#

subto af_overlap:             # Whether the active frequencies for two networks overlap
  forall <i> in W : forall <r> in W : o[i,r] == sum <i,fi> in TF : sum <r,fr> in TF : q[i,r];

subto q1_cons:
  forall <i> in W : forall <r> in W : q[i,r] <= sum <i,fi> in TF : sum <r,fr> in TF : O(fi,B[i],fr,B[r]);

subto q2_cons:
  forall <i> in W : forall <r> in W : q[i,r] <= 

subto residual_lh:            # The lefthand side of our min() in the 'Residual' variable
  forall <i> in W : residual[i] <= D[i];

subto residual_rh:            # The righthand side of our min() in the 'Residual' variable
  forall <i> in W : residual[i] <= 1 - (sum <c> in C[i] : D[c] * (sum<i,fi> in TF : sum<c,fc> in TF : O(fi,B[i],fc,B[c])*af[i,fi]*af[c,fc]));
  
subto valid_freq:             # The frequency selected by each network must be one in its list, if not it cannot be used and must have a val of 0.
  forall <i,f> in TF with IS_AVAIL_FREQ(i,f)==0 : af[i,f] == 0;

subto active_freq:            # Every network must have one center frequency considered active.
  forall <i> in W : sum <f> in F : af[i,f] == 1; 

subto airtime_is_positive:    # Ensure that the airtime of all networks is positive, it cannot be a negative value.  Worst case is nothing.
  forall <i> in W : a[i] >= 0;

subto airtime_lte_desired:    # The actual airtime for each network cannot exceed the desired airtime of the network.
  forall <i> in W : a[i] <= D[i];

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

#do forall <i> in W do print card( { 2412e3 } inter F[TYPE[i]] );
#param a := sum <i> in W  do forall <j> in F[TYPE[i]] : if(i==1) then 1 else 0 end;
#param a := sum <j> in F[TYPE[1]] : j;
#do print a;

#set G := {1 .. 3};
#set Y := {"A","B","C"};
#set V := G*Y;
#param K[V] := <1,"A">1,<1,"B">1,<1,"C">1,<2,"A">2,<2,"B">2,<2,"C">2,<3,"A">3,<3,"B">3,<3,"C">7;
#param l := "A";
#do print max <k,l> in V : K[k,l];
