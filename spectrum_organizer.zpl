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

param Protocols := { "802.11g", "802.11n", "ZigBee", "Bluetooth", "AnalogPhone" };


