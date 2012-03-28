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
set   W       := { read "networks.dat" as "<1n>" };      # unique set of network IDs
param TYPE[W] := read "networks.dat" as "<1n> 2s";       # the network TYPEs for each network
param D[W]    := read "networks.dat" as "<1n> 3n";       # the desired airtime for each network

include "unified_coordination.zpl";   # imports a variable Q := <1,1> 0, <1,2> 0, <1,3> 1 ...

############################################################################################################################################
# CONSTANTS
##############
#
set Protocols := { "802.11g", "802.11n", "ZigBee", "AnalogPhone" };

# In KHz, the bandwidth of networks that use the following protocols
param B[Protocols] := <"802.11g"> 20000, <"802.11n"> 20000, <"ZigBee"> 5000, <"AnalogPhone"> 1000;

# The possible set of center frequencies (KHz) broken down ('F'requency 'B'reakdown) for each network by protocol
set FB[Protocols] := <"802.11g"> {2412e3,2437e3,2462e3},
                    <"802.11n"> {2412e3,2437e3,2462e3},
                    <"ZigBee"> {2405e3,2410e3,2415e3,2420e3,2425e3,2430e3,2435e3,2440e3,2445e3,2450e3,2455e3,2460e3,2465e3,2470e3,2475e3,2480e3},
                    <"AnalogPhone"> {2412e3,2437e3,2462e3,2476e3};

# The total set of frequencies.  This is not in the formalization, but a requirement to fit the language and solvers.  This is a union
#   of all possible frequencies which are then used to construct a table for each network about which frequency is usable given the protocol.
set F := union <p> in Protocols : FB[p];

# In microseconds, the avg. TX length for each of the protocols (i.e., 'T' in formalization)
param T[Protocols] := <"802.11g"> 2000, <"802.11n"> 2000, <"ZigBee"> 2000, <"AnalogPhone"> 2000;


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
    if( card( { freq } inter F[TYPE[i]] ) == 1)
      then
        1
      else
        0
      end;

# This calculates the expected loss rate of two networks given the Airtime of U (Au), and the
#   two average transmission lengths of both networks Tu and Ti, assuming that they are independent
#   processes, modeled as Poisson.
defnumb sigma(Au, Tu, Ti) := 1 - exp( (-Au / (Tu + Ti)));


############################################################################################################################################
# VARIABLES
##############
#
var f[W*F] binary;        # A binary representation of which network picks which frequency
var o[W*W] binary;        # Do the networks, given their center frequencies, overlap?  Specifying binary means it will be 0 or 1...
var s[W] real >= 0 <= 1;  # The sustained interference on each network is a real number between 0 and 1 (loss rate due to uncoordination)
var Airtime[W]
    real >= 0 <= 1;       # Airtime is a real number for each network between 0 and 1.

############################################################################################################################################
# OBJECTIVE FUNCTION
################
#
# minimize cost: min ( forall <i> in W do                                     # min (
#                        min( D[i], 1 - sum <c> in C : D[c] * o(f,i,c) )      #  Residual          # \
#                        *                                                    #  *                 #  \
#                        (1 - (                                               #  (1 -              #   Airtime_i
#                               1 - prod <u> in U : 1 - s(i,u) * o(f,i,u) )   #       LossRate_i   #  /
#                                  )                                          #                 )  # /
#                     /                                                       #  ----------------- # -----------
#                       D[i]                                                  #         D_i
#                    )                                                        #  )

############################################################################################################################################
# CONSTRAINTS
################
#

#subto valid_freq:             # The frequency selected by each network must be valid for its TYPE

subto airtime_is_positive:    # Ensure that the airtime of all networks is positive, it cannot be a negative value.  Worst case is nothing.
  forall <i> in W : Airtime[i] >= 0;

subto airtime_lte_desired:    # The actual airtime for each network cannot exceed the desired airtime of the network.
  forall <i> in W : Airtime[i] <= D[i];

subto sustained_between_01:   # Sustained interference is a loss rate, which must be between 0 and 1.
  forall <i> in W : s[i] >= 0 and s[i] <= 1;

############################################################################################################################################
# INPUT CHECK
################
# The following checks below are checks for valid input.  For these we do not need constraints since they do
#   not change with execution.  We just need to make sure they are valid inputs.

# This is a check to make sure that the specified desired airtimes are legit.
do forall <i> in W do check D[i] >= 0 and D[i] <= 1;

# Make sure that the protocols for each network are ones that are valid and supported.
do forall <i> in W do check card( { TYPE[i] } inter Protocols ) == 1;

#do forall <i> in W do print card( { 2412e3 } inter F[TYPE[i]] );
#param a := sum <i> in W  do forall <j> in F[TYPE[i]] : if(i==1) then 1 else 0 end;
#param a := sum <j> in F[TYPE[1]] : j;
#do print a;
