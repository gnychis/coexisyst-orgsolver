############################################################################################################################################
# INPUTS
##############
#

  include "data.zpl";             # Load in the specific data to the environment, see sample_data.zpl for a post-processed example

  param USE_LINEAR_APPROX := 0;   # Avoid the use of an exponential function in computing overlap by using a
                                  # linear approximation we introduced

############################################################################################################################################
# CONSTANTS
##############
#
  
  # The total set of frequencies.  This is not in the formalization, but a requirement to fit the language and solvers.  This is a union
  #   of all possible frequencies which are then used to construct a table for each radio about which frequency is usable given the protocol.
  set F  := union <r> in R : FR[r];
  set TF := R*F;   # Creating a set of all possible radios and frequencies
  set QD := R*R*F*F;


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
      if( card( { freq } inter FR[i] ) == 1)
        then
          1
        else
          0
        end;

############################################################################################################################################
# VARIABLES
##############
#

  var af[TF] binary;          # A binary representation of which radios picks which frequency
  var o[R*R] binary;          # Do the radios, given their center frequencies, overlap?  Specifying binary means it will be 0 or 1...
  var q[QD] binary;           # The linear representation of ___ ^ ____ ^ ____
  var GoodAirtime[R] real;    # Airtime is a real number for each radios between 0 and 1.
  var Residual[R] real;       # The residual airtime sensed for each radio.
  var LinkAirtime[L] real;    # The airtime for each link given the radio's airtime
  var LinkAirtimeFrac[L] real;
  var LinkDecrease[R] real;
 
  # ***************************************************************************************************
  # Variables related to finding the min between rfs (the max between residual and fairshare) and
  # the desired airtime, because you can't get more than what you ask for!
  var RadioAirtime[R];
  var airtime_min_y[R] binary;
  param airtime_min_M := 100;
  
  # ***************************************************************************************************
  # Variables that are related to calculating the airtime sensed by each radio.
  # There are two main variables here:
  #   * ats:       the sum of the airtime sensed by all radios
  #   * ats_act:   min(sum,1) so that it doesn't exceed 1
  var ats[R];
  var ats_act[R];
  var ats_min_lhv[R];
  param ats_min_rhv := 1;
  var ats_min_y[R] binary;
  param ats_min_M := 100;
  
  # ***************************************************************************************************
  # Variables that are related to calculating the loss rate for each network which is a product.
  # This computes the product in the most linear-way possible.
  var RadioLossRate[R] real >= 0 <= 1; 
  var LinkLossRate[L] real >= 0 <= 1;
  var sr_vals[L*L] real;    # For each radio, calculate loss rate due to each radio
  var sr_vars[L*L] real;    # For the calculation of loss rate using a product
  var vulnWin[L*L];

  # ***************************************************************************************************
  # For calculating the rough estimated of an expected "fair share" (fs) of airtime due to radios that
  # the radio coordinates with.
  var FairShare[R];
  var nsharing[R];
  
  # ***************************************************************************************************
  # Calculation of the max(residual,fairshare)
  var rfs_max[R];
  var rfs_max_y[R] binary;
  param rfs_max_M := 100;

  # ***************************************************************************************************
  # Related to the linear approximation of the exponential function for estimating the overlap
  # and loss rate between two links.
  set FPS := {1,2,3};
  param expFPS[FPS] := <1> -3, <2> -1.5, <3> -0.4;
  param expOffsets[FPS] := <1> 0.01, <2> 0.02, <3> 0.04;
  var expIND[L*L*FPS] binary;
  param EXP_MAX := 10;
  var expComp[L*L] >= -10;    # Make sure this is -EXP_MAX
  var probZeroTX[L*L];
  param EXP_DELTA := 0.001;
  var expFPSvals[FPS];
  subto expFPSvals_eq:
    forall <i> in FPS : expFPSvals[i] == exp(expFPS[i]);


############################################################################################################################################
# CONSTRAINTS
################
#
  subto valid_freq:                     # The frequency selected by each network must be one in its list
    forall <i,f> in TF with IS_AVAIL_FREQ(i,f)==0 : af[i,f] == 0;
  
  subto active_freq:                    # Every network must have one center frequency considered active.
    forall <r> in R : sum <f> in F : af[r,f] == 1; 
  
  subto airtime_is_positive:            # Ensure that the airtime of all networks is positive, it cannot be a negative value.
    forall <r> in R : GoodAirtime[r] >= 0;
  
  subto airtime_lte_desired:            # The actual airtime for each network cannot exceed the desired airtime of the network.
    forall <r> in R : GoodAirtime[r] <= RDATA[r,"dAirtime"];

  subto airtime_eq_residual:            # The airtime is equal to the max of residual and fairshare, minus loss
    forall <r> in R : GoodAirtime[r] == RadioAirtime[r] * (1 - RadioLossRate[r]);

  subto samefreq_in_hyperedge:
    forall <h> in H : forall <r> in HE[h] : forall <j> in HE[h] : forall <f> in FR[r] : af[r,f] == af[j,f];

  # ***************************************************************************************************
  # The top most function is that you get the max of residual and airtime, but then you must take the
  # min of the desired airtime with the result of that function.  That way you never have more than
  # you ask for.
  subto airtime_lte_rfs:                    # airtime has to be less than max(residual,fairshare)
    forall <r> in R : RadioAirtime[r] <= rfs_max[r];

  subto airtime_lte_D:                      # airtime has to be less than your desired airtime
    forall <r> in R : RadioAirtime[r] <= RDATA[r,"dAirtime"];

  subto airtime_c1:                         # A possible constraint given the min substitution
    forall <r> in R : -RadioAirtime[r] <= -rfs_max[r] + airtime_min_M*airtime_min_y[r];

  subto airtime_c2:                         # A possible constraint ...
    forall <r> in R : -RadioAirtime[r] <= -RDATA[r,"dAirtime"] + airtime_min_M*(1-airtime_min_y[r]);
  
  # ***************************************************************************************************
  # Calculating the airtime for each link
  subto linkairtime_eq:
    forall <r> in R with RDATA[r,"dAirtime"]>0 do
      forall <l> in RL[r] : LinkAirtime[l] == LDATA[l,"dAirtime"] * ( 1 - ((RDATA[r,"dAirtime"] - RadioAirtime[r]) / RDATA[r,"dAirtime"]));

  # ***************************************************************************************************
  # Related to calculating the fairshare of airtime for each network
  subto nsharing_eq:                    # The number of networks sharing a frequency with each other
    forall <r> in R :  nsharing[r] == sum <c> in C[r] : o[r,c];

  subto fs_eq:                          # Expected FairShare[i] equal to 1/nsharing, just written without division
    forall <r> in R : FairShare[r] * (nsharing[r]+1) == 1;

  # ***************************************************************************************************
  # Calculating the max of residual airtime and the fairshare, giving the maximum of them
  subto rfs_max_gt_residual:            # rfs_max has to be greater than the residual
    forall <r> in R : rfs_max[r] >= Residual[r];

  subto rfs_max_gt_fs:                  # rfs_max has to be greater than the fair share
    forall <r> in R : rfs_max[r] >= FairShare[r];

  subto rfs_max_c1:                     # A possible constraint given the max LP sub
    forall <r> in R : -rfs_max[r] + rfs_max_M*rfs_max_y[r] >= -Residual[r];

  subto rfs_max_c2:                     # A possible constraint...
    forall <r> in R : -rfs_max[r] + rfs_max_M*(1-rfs_max_y[r]) >= -FairShare[r];
  
  # ***************************************************************************************************
  # Calculating the lossrate for each radio, which will be based on the performance and fraction of
  # airtime each of the links uses
  subto radiolossrate_eq:               # The total radio loss rate based on each of its link's loss rate
    forall <r> in R : RadioLossRate[r] == sum <l> in RL[r] : LinkLossRate[l] * LinkAirtimeFrac[l]; 

  subto linkairtimefrac_eq:             # The fraction of the radio's airtime that each link uses
    forall <r> in R : forall <l> in RL[r] : LinkAirtimeFrac[l] * RadioAirtime[r] == LinkAirtime[l];
  
  # ***************************************************************************************************
  # The vulnerability window is dependent on whether the set of links is in a symmetric or asymmetric
  # hidden/coordination scenario.
  subto vulnWin_eq:
    forall<l> in L : forall <j> in U[l] do
      if(1==card({j} inter LU[l])) then 
        vulnWin[l,j] == LDATA[l,"txLen"] + LDATA[j,"txLen"]
      else
        if(1==card({j} inter LUO[l])) then
          vulnWin[l,j] == LDATA[l,"txLen"]
        else
          if(1==card({j} inter LUB[l])) then
            vulnWin[l,j] == LDATA[j,"txLen"]
          end
        end
      end;
      
  
  # ***************************************************************************************************
  # Related to calculating the estimated overlap between two links which we do as a linear approximation
  # with 3 focus points.
  subto expComp_eq:     # The component in the exponential function is the packets/second * vulnerability win
      forall <l> in L : forall <j> in U[l] : expComp[l,j] == -((LinkAirtime[j]/LDATA[j,"txLen"]) * vulnWin[l,j]);

  subto probZeroTX_eq:  # If we are not using the approximation, then we compute it directly 
    if(USE_LINEAR_APPROX == 0) then
      forall <l> in L : forall <j> in U[l] : probZeroTX[l,j] == exp(expComp[l,j])
    end;

  subto toggleIND_1:    # The indicator to see if the value is above our approximation focus points
    if(USE_LINEAR_APPROX == 1) then
      forall <l> in L : forall <j> in U[l] : forall <i> in FPS do
        expIND[l,j,i] >= ((expComp[l,j]-expFPS[i]) / EXP_MAX) + (EXP_DELTA / (2*EXP_MAX))
      end;
  
  subto toggleIND_2:    # The second constraint to determine the binary indicator
    if(USE_LINEAR_APPROX == 1) then
      forall <l> in L : forall <j> in U[l] : forall <i> in FPS do
        expIND[l,j,i] <= 1 + ((expComp[l,j]-expFPS[i])/EXP_MAX)
    end;

  subto exp_low:    # If the value falls on to the lower approximation line
    if(USE_LINEAR_APPROX == 1) then
      forall <l> in L : forall <j> in U[l] do
        0 == (expIND[l,j,1]-expIND[l,j,2]) * (expFPSvals[1] + expFPSvals[1]*expComp[l,j] - expFPSvals[1]*expFPS[1] - probZeroTX[l,j])
    end;

  subto exp_mid:    # If it falls on to the mid approximation line
    if(USE_LINEAR_APPROX == 1) then
      forall <l> in L : forall <j> in U[l] do
        0 == (expIND[l,j,2]-expIND[l,j,3]) * (expFPSvals[2] + expFPSvals[2]*expComp[l,j] - expFPSvals[2]*expFPS[2] - probZeroTX[l,j])
    end;

  subto exp_high:   # And finally, the high line
    if(USE_LINEAR_APPROX == 1) then
      forall <l> in L : forall <j> in U[l] do
        0 == (expIND[l,j,3]) * (expFPSvals[3] + expFPSvals[3]*expComp[l,j] - expFPSvals[3]*expFPS[3] - probZeroTX[l,j])
    end;

  # ***************************************************************************************************
  # Related to calculating the lossrate variable for each of the links
  subto lossrate_eq:                    # Lossrate is the last variable in the series of multiplications (variables)
    forall <l> in L : LinkLossRate[l] == sr_vars[l,card(L)];
  
  subto lossrate_prod_valsBad_eq:       # Estimated overlap pumped in
    forall <l> in L : forall <j> in U[l] : forall <a,b,r> in OL with a==l and b==j : 
      forall <z,lR> in LR with l==z : forall <v,jR> in LR with v==j do 
        sr_vals[l,j] == (1 - probZeroTX[l,j]) * o[lR,jR] * r;
  
  subto lossrate_prod_valsGood_eq:      # Coordinating links introduce no loss, regardless of frequency
    forall <l> in L : forall <j> in {L-U[l]} : 
      sr_vals[l,j] == 0;

  subto lossrate_prod_vars_eq_init:     # Initialize the first multiplication in the chain
    forall <l> in L : sr_vars[l,1] == sr_vals[l,1];

  subto lossrate_prod_vars_eq:          # Loss rate variables which is a chain of multiplications
    forall <i> in L : forall <j> in L with j!=1 : sr_vars[i,j] == 1 - (1 - sr_vars[i,j-1]) * (1 - sr_vals[i,j]);

  # ***************************************************************************************************
  # Related to substitution for the min() in the airtime sensed so that the "actual" sensed is <= 1.
  # The residual airtime ends up being 1 minus this value
  subto ats_eq:                         # The airtime each network senses is equal to...
    forall <r> in R : ats[r] == sum <c> in C[r] : (RDATA[c,"dAirtime"] * o[r,c]);

  subto ats_min_lhv_eq:                 # The left hand value of the min for airtime sensed is airtime sensed
    forall <i> in L : ats_min_lhv[i] == ats[i];

  subto ats_min1:                       # The value (ats_act)  must be less than the lhv
    forall <i> in L : ats_act[i] <= ats_min_lhv[i];

  subto ats_min2:                       # The value (ats_act) must be less than the rhv (fixed to 1)
    forall <i> in L : ats_act[i] <= ats_min_rhv;

  subto ats_min_c1:                     # A possible constraint given the min LP sub (see example in 'lp_substitutions/')
    forall <i> in L : -ats_act[i] <= -ats_min_lhv[i] + ats_min_M*ats_min_y[i];

  subto ats_min_c2:                     # A possible constraint...
    forall <i> in L : -ats_act[i] <= -ats_min_rhv + ats_min_M*(1-ats_min_y[i]);
  
  subto residual_eq:                    # The residual is equal to 1 minus the airtime sensed
    forall <i> in L : Residual[i] == 1 - ats_act[i];
  
  # ***************************************************************************************************
  # Related to substitution for  O_ifrf ^ f_i ^ f_r
  subto af_overlap:                     # Whether the active frequencies for two networks overlap
    forall <i> in R : forall <r> in R with i != r : o[i,r] == sum <i,fi> in TF : sum <r,fr> in TF : q[i,r,fi,fr];
  
  subto q_c1:                           # Must be less than whether or not the frequencies overlap
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= O(fi,RDATA[i,"bandwidth"],fr,RDATA[r,"bandwidth"]);

  subto q_c2:                           # Must be less than whether or not i is using frequency fi
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[i,fi];

  subto q_c3:                           # Must be less than whether or not r is using frequency fr
    forall <i,r,fi,fr> in QD : q[i,r,fi,fr] <= af[r,fr];

  subto q_c4:                           # Must be greater than the sum of the them
    forall <i,r,fi,fr> in QD: q[i,r,fi,fr] >= O(fi,RDATA[i,"bandwidth"],fr,RDATA[r,"bandwidth"]) + af[i,fi] + af[r,fr] - 2;

############################################################################################################################################
# INPUT CHECK
################
# The following checks below are checks for valid input.  For these we do not need constraints since they do
#   not change with execution.  We just need to make sure they are valid inputs.

  # This is a check to make sure that the specified desired airtimes are legit.
  do forall <i> in L do check LDATA[i,"dAirtime"] >= 0 and LDATA[i,"dAirtime"] <= 1;
  do forall <i> in R do check RDATA[i,"dAirtime"] >= 0 and RDATA[i,"dAirtime"] <= 1;

  # Ensure that bandwidth is positive
  do forall <i> in L do check RDATA[i,"bandwidth"] > 0;
  do forall <i> in R do check RDATA[i,"bandwidth"] > 0;

############################################################################################################################################
# OBJECTIVE FUNCTION
################

  maximize min_prop_airtime: 
    sum <r> in R with RDATA[r,"dAirtime"]>0 : GoodAirtime[r] / RDATA[r,"dAirtime"]; 

#  minimize something:
#    sum <r> in R with RDATA[r,"dAirtime"]>0 : RadioLossRate[r];
