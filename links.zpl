############################################################
## Information related to links

  set LIDs       := { 1, 2, 3, 4, 5, 6, 7 };
  set LinkAttr   := { "srcID", "dstID", "freq", "bandwidth", "airtime", "txLen" };

  param links[LIDs * LinkAttr] :=
     |"srcID", "dstID", "freq", "bandwidth", "airtime", "txLen"|
  |1|	1,	2,	2412,	      20,	0.3,    2000 |
  |2|	2,	1,	2412,	      20,	0.3,    2000 |
  |3|	3,	4,	2412,	      20,	0.6,    2000 |
  |4|	2,	4,	2412,	      20,	0.6,    2000 |
  |5|	5,	1,	2412,	      20,	0.6,    2000 |
  |6|	5,	6,	2412,	      20,	0.6,    2000 |
  |7|	3,	1,	2412,	      20,	0.6,    2000 |;
