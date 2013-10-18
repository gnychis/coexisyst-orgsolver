#!/usr/bin/ruby
require 'rubygems'
require './trollop'
require './hypergraph'
require './optimization'
require 'colorize'

$test_num=0

def intermed_test(header)
  print "    ...".green + " #{header}: ".yellow
end

def new_test(header)
  print "\n[#{$test_num}]".green + " #{header}... ".yellow
  $test_num+=1
end

def new_intermed_test(header)
  puts "\n[#{$test_num}]".green + " #{header}... ".yellow
  $test_num+=1
end

def test_result(result)
  if(result)
    puts "OK".light_blue
    return
  end
  puts "FAIL".red
  raise RuntimeError, 'Test failed'
end

#begin
#
#  new_intermed_test("Testing alignment...")
#
#  intermed_test("basic 20MHz should align")
#  hgraph=Hypergraph.new
#  hgraph.newNetwork("802.11n", [2412], 0.06825, nil, [-40,0], nil)
#  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
#  Optimization.new(hgraph)
#  (`scip -f obj_prodPropAirtime.zpl | grep "al#1#3"`.length > 0) ? test_result(true) : test_result(false);
#  
#  intermed_test("basic 20MHz should not align")
#  hgraph=Hypergraph.new
#  hgraph.newNetwork("802.11n", [2413], 0.06825, nil, [-40,0], nil)
#  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
#  Optimization.new(hgraph)
#  (`scip -f obj_prodPropAirtime.zpl | grep "al#1#3"`.length > 0) ? test_result(false) : test_result(true);
#
#  intermed_test("basic 40MHz and 20MHz should align")
#  hgraph=Hypergraph.new
#  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
#  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
#  Optimization.new(hgraph)
#  (`scip -f obj_prodPropAirtime.zpl | grep "al#1#3"`.length > 0) ? test_result(true) : test_result(false);
#
#  intermed_test("basic 40MHz and 20MHz should not align")
#  hgraph=Hypergraph.new
#  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
#  hgraph.newNetwork("802.11n", [2437], 0.26675, nil, [-40,0], nil)
#  Optimization.new(hgraph)
#  (`scip -f obj_prodPropAirtime.zpl | grep "al#1#3"`.length > 0) ? test_result(false) : test_result(true);
#end

PARALLEL=true

begin
  
  new_intermed_test("Testing digital coordination")
  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", [2437], 0.26675, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2437], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("5", "1", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("1", "5", -20, 1))

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)

  intermed_test("no digital coordination between legacy and 11n")
  (hgraph.getSpatialEdge("1","3").digitally==true) ? test_result(false) : test_result(true);

  intermed_test("digital coordination between HT 802.11n")
  (hgraph.getSpatialEdge("1","5").digitally==true) ? test_result(true) : test_result(false);
  
end

begin
  
  new_intermed_test("Testing digital conflicts and backoff")

  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2437], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("unaligned, it should be a digital conflict")
  (results.include?("digitalConflict#1#3")) ? test_result(true) : test_result(false);
  
  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2447], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2462], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("unaligned, it should be a digital conflict")
  (results.include?("digitalConflict#1#3")) ? test_result(true) : test_result(false);

  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("aligned, it should NOT be a digital conflict")
  (results.include?("digitalConflict#1#3")) ? test_result(false) : test_result(true);
end

begin
  
  new_intermed_test("Testing sharing between non-digitally coordinated")

  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("they should be digitally sharing")
  (results.include?("nsharing")) ? test_result(true) : test_result(false);
  
  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2437], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("they should not be digitally sharing")
  (results.include?("nsharing")) ? test_result(false) : test_result(true);
  
  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 0))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 0))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("they should not be digitally sharing")
  (results.include?("nsharing")) ? test_result(false) : test_result(true);
end

begin
  
  new_intermed_test("Testing interference with digital coordination")

  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2437], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "2", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("1", "4", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("there should be intereference")
  (hgraph.getRadios[0].lossRate > 0) ? test_result(true) : test_result(false);


  hgraph=Hypergraph.new
  hgraph.newNetwork("802.11n-40MHz", [2422], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11n", [2412], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("1", "3", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "2", -20, 1))
  hgraph.newSpatialEdge(SpatialEdge.new("1", "4", -20, 1))
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("there should not be intereference")
  (hgraph.getRadios[0].lossRate == 0) ? test_result(true) : test_result(false);
end

begin

  new_test("Testing loss rates")
  hgraph=Hypergraph.new

  hgraph.newNetwork("ZigBee", [2437], 0.06825, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", [2437], 0.26675, nil, [-40,0], nil)
  hgraph.newSpatialEdge(SpatialEdge.new("3", "2", -20, 0))
  hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
  
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)

  radios = hgraph.getRadios

  ((radios[0].lossRate-0.206660144620774).abs<0.001) ? test_result(true) : test_result(false);
end

begin
  new_test("Testing asymmetric sensing properly degrades expected airtime")
  phone_freqs=[2460,2465,2470]
  wifi_freqs=[2462]
  
  wifi_freqs.each do |curr_freq|

    hgraph=Hypergraph.new

    hgraph.newNetwork("802.11agn", [curr_freq], 0.510, nil, [-40,0], nil)
    hgraph.newNetwork("Analog", [phone_freqs[0]], 0.999, nil, [-40,0], nil)

    # The main culprit
    hgraph.newSpatialEdge(SpatialEdge.new("3", "1", -20, 1))
    
    # Additional networks that the baseline network senses
    hgraph.newNetwork("802.11agn", [2412], 0.75, nil, [-40,0], nil)
    hgraph.newNetwork("802.11agn", [2437], 0.51, nil, [-40,0], nil)
    hgraph.newNetwork("802.11agn", [2437], 0.51, nil, [-40,0], nil)
    hgraph.newNetwork("802.11agn", [2462], 0.75, nil, [-40,0], nil)
    hgraph.newSpatialEdge(SpatialEdge.new("5", "1", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("7", "1", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("9", "1", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("11", "1", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("1", "5", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("1", "7", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("1", "9", -20, 1))
    hgraph.newSpatialEdge(SpatialEdge.new("1", "11", -20, 1))

    # Networks that create a little additional loss
    hgraph.newNetwork("802.11agn", [2412], 0.02, nil, [-40,0], nil)
    hgraph.newNetwork("802.11agn", [2437], 0.01, nil, [-40,0], nil)
    hgraph.newNetwork("802.11agn", [2437], 0.02, nil, [-40,0], nil)
    hgraph.newNetwork("802.11agn", [2462], 0.04, nil, [-40,0], nil)
    hgraph.newSpatialEdge(SpatialEdge.new("13", "2", -20, 0))
    hgraph.newSpatialEdge(SpatialEdge.new("15", "2", -20, 0))
    hgraph.newSpatialEdge(SpatialEdge.new("17", "2", -20, 0))
    hgraph.newSpatialEdge(SpatialEdge.new("19", "2", -20, 0))

    opt = Optimization.new(hgraph)
    opt.run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)

    radios=hgraph.getRadios
    (radios[0].airtime/radios[0].dAirtime<0.1) ? test_result(true) : test_result(false)

  end
end

###########################################################################
## Basic Airtime Split
## ---------------------
## Basic split airtime test.  Put all on same frequency, they should end
## up on different frequencies
begin
  new_test("Ensuring basic channel avoidance to meet airtime")
  hgraph=Hypergraph.new

  # Create 6 radios that have independent links
  (1..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2437,2462])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 250, 300, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 250, 300, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 250, 300, 2750, "802.11agn") )

  # The transmitters are all within range of each other
  hgraph.getLinkEdges.each { |le1|
    hgraph.getLinkEdges.each { |le2|
      next if(le1==le2)
      hgraph.newSpatialEdge( SpatialEdge.new(le1.srcID,le2.srcID,-40,1) ) } }

  Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  results = hgraph.getRadios

  # The result is OK if all the frequencies are different
  freqs = Array.new; results.each {|r| freqs.push(r.activeFreq)}
  (freqs.uniq.size==3) ? test_result(true) : test_result(false)
end

begin
  new_test("Testing that hypergraph forces all radios to same channel")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 6 radios that have independent links
  (1..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network1", [2412,2437,2462])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 250, 300, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 250, 300, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 250, 300, 2750, "802.11agn") )

  # The transmitters are all within range of each other
  hgraph.getLinkEdges.each { |le1|
    hgraph.getLinkEdges.each { |le2|
      next if(le1==le2)
      hgraph.newSpatialEdge( SpatialEdge.new(le1.srcID,le2.srcID,-40,1) ) } }

  Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  results = hgraph.getRadios

  # The result is OK if all the frequencies are different
  freqs = Array.new; results.each {|r| freqs.push(r.activeFreq)}
  (freqs.uniq.size==1) ? test_result(true) : test_result(false)
end

begin
  new_intermed_test("Testing that heterogeneous uncoordination will cause radio to avoid channel")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "ZigBee", "zigbee#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 250, 300, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 250, 300, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 250, 300, 2750, "ZigBee") )

  # Nothing from the first two links are within range, but the two transmitters are within range of the 3rd and
  # do not coordinate
  hgraph.newSpatialEdge( SpatialEdge.new("1","5",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("3","5",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,1) ) 

  # The one ZigBee receiver is within range of the 802.11 transmitter (where interference is strong)
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2437")
  (hgraph.getRadio("5").activeFreq==2437) ? test_result(false) : test_result(true)

  # Now, change the interference scenario and it should pick the other channel
  hgraph.deleteSpatialEdge(hgraph.getSpatialEdge("3","6"))
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)
end

begin
  new_intermed_test("Testing that it chooses the channel with the least interference")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "ZigBee", "zigbee#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 250, 250, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 200, 200, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 250, 275, 2750, "ZigBee") )

  # Nothing from the first two links are within range, but the two transmitters are within range of the 3rd and
  # do not coordinate
  hgraph.newSpatialEdge( SpatialEdge.new("1","5",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("3","5",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,1) ) 

  # Both transmitters affect the 3rd link's receiver
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)

  # Increase the interference on the second 802.11 link
  hgraph.getLinkEdge("3","4").pps=300;
  hgraph.getLinkEdge("3","4").ppsMax=300;

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2437")
  (hgraph.getRadio("5").activeFreq==2437) ? test_result(false) : test_result(true)
end

begin
  new_test("Testing multilink interference")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (5..8).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (9..10).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "ZigBee", "zigbee#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 150, 175, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 110, 125, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "7","8", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "9","10", 2437, 20, 75, 90, 2750, "ZigBee") )

  # Nothing from the first two links are within range, but the two transmitters are within range of the 3rd and
  # do not coordinate
  hgraph.newSpatialEdge( SpatialEdge.new("1","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("3","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("5","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("7","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("9","10",-40,1) ) 

  # Both transmitters affect the 3rd link's receiver
  hgraph.newSpatialEdge( SpatialEdge.new("1","10",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","10",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("5","10",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("7","10",-20,0) )

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  (hgraph.getRadio("9").activeFreq==2412) ? test_result(false) : test_result(true)
end

begin
  new_intermed_test("Should choose channel where loss rate during collision is 0")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "ZigBee", "zigbee#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 75, 90, 2750, "ZigBee") )

  # Nothing from the first two links are within range, but the two transmitters are within range of the 3rd and
  # do not coordinate
  hgraph.newSpatialEdge( SpatialEdge.new("1","5",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("3","5",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,1) ) 

  # The one ZigBee receiver is within range of the 802.11 transmitter (where interference is strong)
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-50,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2437")
  (hgraph.getRadio("5").activeFreq==2437) ? test_result(false) : test_result(true)

  # Switch the interference
  hgraph.deleteSpatialEdge(hgraph.getSpatialEdge("1","6"))
  hgraph.deleteSpatialEdge(hgraph.getSpatialEdge("3","6"))
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-50,0) )

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)
end

begin
  new_intermed_test("Testing multilink interference with one loss rate being 0")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (5..8).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (9..10).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "ZigBee", "zigbee#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 150, 175, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 150, 175, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "7","8", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "9","10", 2437, 20, 75, 90, 2750, "ZigBee") )

  # Nothing from the first two links are within range, but the two transmitters are within range of the 3rd and
  # do not coordinate
  hgraph.newSpatialEdge( SpatialEdge.new("1","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("3","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("5","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("7","9",-40,0) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("9","10",-40,1) ) 

  # Both transmitters affect the 3rd link's receiver
  hgraph.newSpatialEdge( SpatialEdge.new("1","10",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","10",-50,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("5","10",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("7","10",-20,0) )

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should go to channel 2412")
  (hgraph.getRadio("9").activeFreq!=2412) ? test_result(false) : test_result(true)

  # Change the loss rates around
  hgraph.getSpatialEdge("3","10").rssi=-20
  hgraph.getSpatialEdge("5","10").rssi=-50
  intermed_test("should go to channel 2437")
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  (hgraph.getRadio("9").activeFreq!=2437) ? test_result(false) : test_result(true)
end

begin
  new_intermed_test("Testing the avoidance of hidden terminals")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 75, 90, 2750, "802.11agn") )

  # Nothing from the first two links are within range, but the two transmitters are within range of the 3rd and
  # do not coordinate
  hgraph.newSpatialEdge( SpatialEdge.new("1","5",-40,1) ) 
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,1) ) 

  # The one ZigBee receiver is within range of the 802.11 transmitter (where interference is strong)
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2437")
  (hgraph.getRadio("5").activeFreq==2437) ? test_result(false) : test_result(true)

  # Now, change the interference scenario and it should pick the other channel
  hgraph.deleteSpatialEdge(hgraph.getSpatialEdge("3","6"))
  hgraph.deleteSpatialEdge(hgraph.getSpatialEdge("1","5"))
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)
end

begin
  new_intermed_test("Testing the impact of asymmetric scenarios")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 75, 90, 2750, "802.11agn") )

  # First, the two transmitters are within range of the receiver
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )

  # Now, create the spatial edges so that it is completely hidden from 1
  hgraph.newSpatialEdge( SpatialEdge.new("3","5",-20,1) )
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)

  # Reverse the scenario
  hgraph.deleteSpatialEdge(hgraph.getSpatialEdge("3","5"))
  hgraph.newSpatialEdge( SpatialEdge.new("1","5",-20,1) )
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2437")
  (hgraph.getRadio("5").activeFreq==2437) ? test_result(false) : test_result(true)
end

begin
  new_intermed_test("Testing asymmetric weights")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 75, 90, 5750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 75, 90, 2750, "802.11agn") )
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,0) )

  # First, the two transmitters are within range of the receiver
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )

  # Now, create the spatial edges so that it is completely hidden from 1
  hgraph.newSpatialEdge( SpatialEdge.new("5","1",-20,1) )
  hgraph.newSpatialEdge( SpatialEdge.new("5","3",-20,1) )

  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)

  hgraph.getLinkEdge("1","2").txLen=2750
  hgraph.getLinkEdge("3","4").txLen=5750
  results = Optimization.new(hgraph).run(PARALLEL, Objective::PROD_PROP_AIRTIME,nil)
  intermed_test("should avoid channel 2437")
  (hgraph.getRadio("5").activeFreq==2437) ? test_result(false) : test_result(true)
end
