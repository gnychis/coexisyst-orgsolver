############################################################
## Information related to radios

  # The set of radios in the optimization
  set R  := { 1, 2, 3, 4, 5 };

  set RadioAttr  := { "numLinks", "dAirtime", "bandwidth" };

  # The frequencies available for each radio
  set FR[R]  := 
    <1> { 2412 },
    <2> { 2412 },
    <3> { 2412 },
    <4> { 2412 },
    <5> { 2412 };

  # For each radio, the links that belong to the radio
  set RL[R]  := 
    <1> { 2 },
    <2> {  },
    <3> {  },
    <4> { 1, 3 },
    <5> {  };


  # For each radio, the attributes
  param RDATA[R * RadioAttr] :=
      | "numLinks", "dAirtime", "bandwidth" |
     |1| 	1, 	0.78, 		20 |
     |2| 	0, 	0, 		20 |
     |3| 	0, 	0, 		20 |
     |4| 	2, 	0.91, 		20 |
     |5| 	0, 	0, 		20 |;

  # For each radio, the set of radios that are within spatial range (i.e., r senses them)
  set S[R]  := 
    <1> { 4 },
    <2> { 1, 4 },
    <3> { 4 },
    <4> {  },
    <5> {  };

  # For each radio, the set of radios that are within spatial range (i.e., r senses them) and it coordinates with them (uni-directional)
  set C[R]  := 
    <1> { 4 },
    <2> { 1 },
    <3> { 4 },
    <4> {  },
    <5> {  };

  # For each radio, give one link that the radio participates in, TX or RX
  set ROL[R]  := 
    <1> { 2 },
    <2> { 2 },
    <3> { 1 },
    <4> { 1 },
    <5> { 3 };

  # The set of hyperedges
  set H  := { 1, 2, 3 };

  # For each hyperedge, the set of networks that belong to it
  set HE[H]  := 
    <1> { 1 },
    <2> { 3 },
    <3> { 2 };



############################################################
## Information related to links

  # The set of links in the optimization
  set L  := { 1, 2, 3 };

  # The set of attributes for each link
  set LinkAttr  := { "srcID", "dstID", "freq", "bandwidth", "airtime", "dAirtime", "txLen" };

  # The frequencies available for each link
  set FL[L]  := 
    <1> { 2412 },
    <2> { 2412 },
    <3> { 2412 };

  # The data for each link
  param LDATA[L * LinkAttr] :=
      |"srcID", "dstID", "freq", "bandwidth", "airtime", "dAirtime", "txLen" |
   |1|	    4,	      3,  2412,		  20,	  0.6, 	      0.78,   0.002  |
   |2|	    1,	      2,  2412,		  20,	  0.6, 	      0.78,   0.002  |
   |3|	    4,	      5,  2412,		  20,	  0.1, 	      0.13,   0.002  |;


############################################################
## Information related to coordination between links

  # For all links, all other links that will contribute to it in a negative scenario
  set U[L]  := 
    <1> {  },
    <2> { 1, 3 },
    <3> {  };

  # For all links, the set of links that the radio is in a completely blind situation
  set LU[L]  := 
    <1> {  },
    <2> {  },
    <3> {  };

  # For all radios, the set of links that are asymmetric, where the opposing link does not coordinate
  set LUO[L]  := 
    <1> {  },
    <2> { 1, 3 },
    <3> {  };

  # For all radios, the set of links that are asymmetric, where the baseline link does not coordinate
  set LUB[L]  := 
    <1> {  },
    <2> {  },
    <3> {  };

  # For all conflicting link pairs, the loss rate on the link
  set OL  := { <2,1,1>, <2,3,1> };

