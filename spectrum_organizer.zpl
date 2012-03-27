# Spectrum Organization solver
#
# High Level notes:
#   - Parameters are used to define constants within ZIMPL
#
# Input:
#   <int: network_id> <int: network_type> <float: desired_airtime> <int: avg_tx_length_in_us>
#
# Network Types: 
#   1: Wifi (802.11g: standard preamble)
#   2: Wifi (802.11n: greenfield preamble)
#   3: ZigBee
#   4: Analog Phone
#
# Implement types as a tuple, index value at, like: <"bandwidth", 3>

include "functions.zpl";   # A set of helper functions to create constants

############################################################################################################################################
# INPUTS
##############
#
set   W       := { read "networks.dat" as "<1n>" };      # unique set of network IDs
param type[W] := read "networks.dat" as "<1n> 2s";       # the network types for each network
param D[W]    := read "networks.dat" as "<1n> 3n";       # the desired airtime for each network

include "unified_coordination.zpl";   # imports a variable Q := <1,1> 0, <1,2> 0, <1,3> 1 ...

############################################################################################################################################
# CONSTANTS
##############
#
set Protocols := { "802.11g", "802.11n", "ZigBee", "AnalogPhone" };
#param ProtocolIds[Protocols] := <"802.11g"> 1, <"802.11n"> 2, <"ZigBee"> 3, <"AnalogPhone"> 4;

# In KHz, the bandwidth of networks that use the following protocols
param B[Protocols] := <"802.11g"> 20000, <"802.11n"> 20000, <"ZigBee"> 5000, <"AnalogPhone"> 1000;

# The possible set of center frequencies (KHz) for each network by protocol (i.e., 'F' in formalization)
set F[Protocols] := <"802.11g"> {2412e3,2437e3,2462e3},
                    <"802.11n"> {2412e3,2437e3,2462e3},
                    <"ZigBee"> {2405e3,2410e3,2415e3,2420e3,2425e3,2430e3,2435e3,2440e3,2445e3,2450e3,2455e3,2460e3,2465e3,2470e3,2475e3,2480e3},
                    <"AnalogPhone"> {2412e3,2437e3,2462e3,2476e3};

# In microseconds, the avg. TX length for each of the protocols (i.e., 'T' in formalization)
param T[Protocols] := <"802.11g"> 2000, <"802.11n"> 2000, <"ZigBee"> 2000, <"AnalogPhone"> 2000;

############################################################################################################################################
# VARIABLES
##############
#
var f[W] integer;         # The center frequency for each network, specified as integer because default is 'real'
var o[W*W] binary;        # Do the networks, given their center frequencies, overlap?  Specifying binary means it will be 0 or 1...
var s[W] real >= 0 <= 1;  # The sustained interference on each network is a real number between 0 and 1 (loss rate due to uncoordination)
var Airtime[W]
    real >= 0 <= 1;       # Airtime is a real number for each network between 0 and 1.

############################################################################################################################################
# CONSTRAINTS
################

#subto valid_freq:
#  forall <i> in W : f[i] 

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
do forall <i> in W do check card( { type[i] } inter Protocols ) == 1;
