#!/usr/bin/ruby
require 'rubygems'
require 'trollop'
require 'hypergraph'
require 'optimization'
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

begin
  new_intermed_test("Testing asymmetric weights")
  hgraph=nil
  hgraph=Hypergraph.new

  # Create 4 radios that have independent links
  (1..2).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412])) }
  (3..4).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2437])) }
  (5..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2437])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2437, 20, 0.6, 0.7, 4750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2437, 20, 0.2, 0.3, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2437, 20, 0.2, 0.3, 4750, "802.11agn") )
  hgraph.newSpatialEdge( SpatialEdge.new("5","6",-40,0) )

  # First, the two transmitters are within range of the receiver
  hgraph.newSpatialEdge( SpatialEdge.new("1","6",-20,0) )
  hgraph.newSpatialEdge( SpatialEdge.new("3","6",-20,0) )

  # Now, create the spatial edges so that it is completely hidden from 1
  hgraph.newSpatialEdge( SpatialEdge.new("5","1",-20,1) )
  hgraph.newSpatialEdge( SpatialEdge.new("5","3",-20,1) )

  Optimization.new(hgraph).run_debug
  intermed_test("should avoid channel 2412")
  (hgraph.getRadio("5").activeFreq==2412) ? test_result(false) : test_result(true)
end
