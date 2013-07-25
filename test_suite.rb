#!/usr/bin/ruby
require 'rubygems'
require 'trollop'
require 'hypergraph'
require 'optimization'
require 'colorize'

###########################################################################
## Basic Airtime Split
## ---------------------
## Basic split airtime test.  Put all on same frequency, they should end
## up on different frequencies
begin
  print "[0]".green + " Ensuring basic channel avoidance to meet airtime... ".yellow
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
  puts (freqs.uniq.size==3) ? "OK".red : "FAIL".red

end

#opt = Optimization.new(hgraph)

#puts opt.run.inspect
