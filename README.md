coexisyst-orgsolver
===================
  
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


