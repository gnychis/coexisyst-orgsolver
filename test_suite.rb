#!/usr/bin/ruby
require 'rubygems'
require 'trollop'
require 'hypergraph'
require 'optimization'
require 'colorize'

$test_num=0

def new_test(header)
  print "[#{$test_num}]".green + " #{header} ".yellow
  $test_num+=1
end

def test_result(result)
  if(result)
    puts "OK".light_blue
    return
  end
  puts "FAIL".red
end

###########################################################################
## Basic Airtime Split
## ---------------------
## Basic split airtime test.  Put all on same frequency, they should end
## up on different frequencies
begin
  new_test("Ensuring basic channel avoidance to meet airtime... ")
  hgraph=Hypergraph.new

  # Create 6 radios that have independent links
  (1..6).each {|rid| hgraph.newRadio( Radio.new("#{rid}", "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2436,2462])) }

  # Create links between the pairs of radios
  hgraph.newLinkEdge( LinkEdge.new( "1","2", 2436, 20, 0.4, 0.75, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "3","4", 2436, 20, 0.4, 0.75, 2750, "802.11agn") )
  hgraph.newLinkEdge( LinkEdge.new( "5","6", 2436, 20, 0.4, 0.75, 2750, "802.11agn") )

  # The transmitters are all within range of each other
  hgraph.getLinkEdges.each { |le1|
    hgraph.getLinkEdges.each { |le2|
      next if(le1==le2)
      hgraph.newSpatialEdge( SpatialEdge.new(le1.srcID,le2.srcID,-40,1) ) } }

  opt = Optimization.new(hgraph)
  results = opt.run   # .each {|i| puts "#{i[0].radioID} #{i[0].networkID} #{i[1]}"  }

  # The result is OK if all the frequencies are different
  freqs = Array.new; results.each {|r| freqs.push(r.activeFreq)}
  (freqs.uniq.size==3) ? test_result(true) : test_result(false)
end

begin
  
end
