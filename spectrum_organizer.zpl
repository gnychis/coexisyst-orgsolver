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
set F[Protocols] := <"802.11g"> {2412e3,2437e3,2462e3},
                    <"802.11n"> {2412e3,2437e3,2462e3},
                    <"ZigBee"> {2405e3,2410e3,2415e3,2420e3,2425e3,2430e3,2435e3,2440e3,2445e3,2450e3,2455e3,2460e3,2465e3,2470e3,2475e3,2480e3},
                    <"AnalogPhone"> {2412e3,2437e3,2462e3,2476e3};

# In microseconds, the avg. TX length for each of the protocols (i.e., 'T' in formalization)
param T[Protocols] := <"802.11g"> 2000, <"802.11n"> 2000, <"ZigBee"> 2000, <"AnalogPhone"> 2000;

# Defining low and high frequencies of a center frequency with a given bandwidth
defnumb LF(f,b) := f-(b/2.0);
defnumb HF(f,b) := f+(b/2.0);

# A basic function to test if a number is in the range of two numbers (a low and high)
defbool INRANGE(num,low,high) := num >= low and num <= high;
defnumb INRANGEI(num,low,high) := if num >= low and num <= high then 1 else 0 end;

# A function to determine whether two frequencies overlap with each other
defnumb O(f1,b1,f2,b2) := 
    if INRANGEI( LF(f1,b1), LF(f2,b2), HF(f2,b2) )==1  or  INRANGEI( LF(f2,b2), LF(f1,b1), HF(f1,b1) )==1 then 
      1
    else 
      0 
    end;

do print "Bandwidths:";
do print B["802.11g"];
do print B["ZigBee"];
do print "";
do print "802.11:  LF: ",  LF(2412e3,B["802.11g"]), " - HF: ", HF(2412e3,B["802.11g"]);
do print "ZigBee:  LF: ",  LF(2480e3,B["ZigBee"]), " - HF: ", HF(2480e3,B["ZigBee"]);
do print "In range: ", INRANGEI(LF(2412e3,B["802.11g"]),LF(2480e3,B["ZigBee"]),HF(2480e3,B["ZigBee"]));
do print "In range: ", INRANGEI(LF(2480e3,B["ZigBee"]),LF(2412e3,B["802.11g"]),HF(2412e3,B["802.11g"]));

do print O(2412,B["802.11g"], 2415,B["ZigBee"]);
do print O(2412,B["802.11g"], 2480,B["ZigBee"]);
