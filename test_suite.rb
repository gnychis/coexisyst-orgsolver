#!/usr/bin/ruby
require 'trollop'
require 'hypergraph'
require 'optimization'

###########################################################################
## Basic Airtime Split
## ---------------------
## Basic split airtime test.  Put all on same frequency, they should end
## up on different frequencies
begin
  hgraph=Hypergraph.new

  # Create 6 radios that have independent links
  (1..6).each {|rid| hgraph.newRadio( Radio.new(rid, "802.11agn", "wifi#{rid}", "network#{(rid-1)/2}", [2412,2436,2462])) }
  
  # Create links between the pairs of radios
  hgraph.newLinkEdge(  )

end

#opt = Optimization.new(hgraph)

#puts opt.run.inspect
