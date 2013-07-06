## Overview

The coexisyst-orgsolver is meant to take a series of data from heterogeneous monitors and be able to output better spectrum
organizations for reduced heterogeneous interference and better performance.  This is done by modeling the problem as a MIP
optimization, which uses the SCIP optimization suite.

**SCIP Optimization Suite**:  ZIMPL, SoPlex, & SCIP packaged together

* **ZIMPL**:  Markup language for LP problem  
* **SoPlex**: LP solver 
* **SCIP**: MIP solver 

----------

## Install 

On Ubuntu, make sure to:

    sudo apt-get install libgmp-dev

Then, you should be able to run the following script which will build, test the suite, and install it in to /usr/local/bin.

    sudo ./install.sh

To test the install, you can run:

    ./scripts/benchmark_performance.rb

----------

## Data Format

To run the optimization, there needs to be several key files in place.

The basic structure is the following:

    monitor_data/capture1.dat
             .../capture2.dat
             .../capture3.dat
             .../map.txt

The _**map.dat**_ file specifies all of the meta-data known about radios.  For example, the possible set of frequencies for each local radio.
The data format for the file is multi-line, where each line defines a radio:

    <radioID> <protoID> <radioName> <netID> <bandwidth> {<frequencies>}

  * **radioID**: An ID for the radio, e.g., a MAC address
  * **protoID**: The wireless protocol the radio uses
  * **radioName**: A human readable name if desired, e.g., ZigBeeRX1
  * **netID**: An ID for a network that it might belong to, e.g., a MAC address or name
  * **bandwidth**: The bandwidth of the radio (MHz)
  * **frequencies**:  The list of frequencies supported, like: {2462,2435}

The **_capture.dat_** data file specifies the sensed radios from a capture.  Not all radios from this file need to have an entry in map.dat.  The only
radio that must have an entry in map.dat is the "baseline radio."  We consider this radio to be the radio nearby the monitor when this data was
captured.  So, if the monitor captured this data near the Xbox, the Xbox is the baseline radio.

    <baselineRadio>
    <radioID> <protoID> <freq> <rssi> <bandwidth> <airtime> <txLen> <backoff>
    <radioID> <protoID> <freq> <rssi> <bandwidth> <airtime> <txLen> <backoff>
    ...

  * **baselineRadio**: a radioID or radioName for the baseline radio of the capture
  * **radioID**: An ID for the radio, e.g., a MAC address
  * **protoID**: The wireless protocol the radio uses (1-6)
  * **freq**: the active frequency of the radio
  * **rssi**: the received signal strength of the radio at the monitor (dBm)
  * **bandwidth**: the observed bandwidth used by the radio
  * **airtime**: the estimated airtime use of the radio
  * **txLen**: the average TX time in microseconds of a packet from the radio
  * **backoff**: does baselineRadio backoff to this radio? (0: unknown, 1: yes, 2: no)

The **protoID** field is specified using some basic protocol types that the code supports.  These types are used for using the lookup tables and SINR data to determine if overlap
of the packets is harmful or not, in addition to whether the nodes sense each other.  These are numberic values, also used by _capture.dat_ and _map.dat_
as _<protoID\>_.

  * [1] **802.11b/g/n**: 802.11 devices that use the legacy preamble for carrier sense reasons
  * [2] **802.11n Greenfield**: newer 802.11 devices that use newer preambles that are not supported by legacy devices
  * [3] **ZigBee**: a standard 802.15.4 ZigBee radio
  * [4] **Analog**: an analog device such as a cordless phone
  * [5] **Bluetooth**: a standard Bluetooth radio
  * [6] **Microwave**: a microwave that emits interference in 2.4GHz
