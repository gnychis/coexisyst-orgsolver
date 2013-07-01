## Overview

The coexisyst-orgsolver is meant to take a series of data from heterogeneous monitors and be able to output better spectrum
organizations for reduced heterogeneous interference and better performance.  This is done by modeling the problem as a MIP
optimization, which uses the SCIP optimization suite.

**SCIP Optimization Suite**:  ZIMPL, SoPlex, & SCIP packaged together

* **ZIMPL**:  Markup language for LP problem  
* **SoPlex**: LP solver 
* **SCIP**: MIP solver 

## Install 

On Ubuntu, make sure to:

    sudo apt-get install libgmp-dev

Then, you should be able to run the following script which will build, test the suite, and install it in to /usr/local/bin.

    sudo ./install.sh

## Data Format

To run the optimization, there needs to be several key files in place.

The basic structure is the following:

    monitor_data/capture1.dat
             .../capture2.dat
             .../capture3.dat
             .../map.txt

----------

The _**map.dat**_ file specifies all of the meta-data known about radios.  For example, the possible set of frequencies for each local radio.
The data format for the file is multi-line, where each line defines a radio:

    <radioID> <protoID> <radioName> <netID> <bandwidth> {<frequencies>}

  * **radioID**: An ID for the radio, e.g., a MAC address
  * **protoID**: The wireless protocol the radio uses
  * **radioName**: A human readable name if desired, e.g., ZigBeeRX1
  * **netID**: An ID for a network that it might belong to, e.g., a MAC address or name
  * **bandwidth**: The bandwidth of the radio (MHz)
  * **frequencies**:  The list of frequencies supported, like: {2462,2435}

----------

The **_capture.dat_** data file specifies the sensed radios from a capture.  Not all radios from this file need to have an entry in map.dat.  The only
radio that must have an entry in map.dat is the "baseline radio."  We consider this radio to be the radio nearby the monitor when this data was
captured.  So, if the monitor captured this data near the Xbox, the Xbox is the baseline radio.

    <baselineRadio>
    <radioID> <protoID> <freq> <rssi> <bandwidth> <airtime>
    <radioID> <protoID> <freq> <rssi> <bandwidth> <airtime>
    ...

  * **baselineRadio**: a radioID or radioName for the baseline radio of the capture
  * **radioID**: An ID for the radio, e.g., a MAC address
  * **protoID**: The wireless protocol the radio uses
  * **freq**: the active frequency of the radio
  * **rssi**: the received signal strength of the radio at the monitor (dBm)
  * **bandwidth**: the observed bandwidth used by the radio
  * **airtime**: the estimated airtime use of the radio
