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

set Protocols := { "802.11g", "802.11n", "ZigBee", "AnalogPhone" };
#param ProtocolIds[Protocols] := <"802.11g"> 1, <"802.11n"> 2, <"ZigBee"> 3, <"AnalogPhone"> 4;

# In KHz, the bandwidth of networks that use the following protocols
param B[Protocols] := <"802.11g"> 20000, <"802.11n"> 20000, <"ZigBee"> 5000, <"AnalogPhone"> 1000;

# The possible set of center frequencies (KHz) for each network by protocol (i.e., 'F' in formalization)
set F[Protocols] := <"802.11g"> {2412,2437,2462},
                    <"802.11n"> {2412,2437,2462},
                    <"ZigBee"> {2405,2410,2415,2420,2425,2430,2435,2440,2445,2450,2455,2460,2465,2470,2475,2480},
                    <"AnalogPhone"> {2412,2437,2462,2476};

# In microseconds, the avg. TX length for each of the protocols (i.e., 'T' in formalization)
param T[Protocols] := <"802.11g"> 2000, <"802.11n"> 2000, <"ZigBee"> 2000, <"AnalogPhone"> 2000;


