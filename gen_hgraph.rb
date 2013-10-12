#!/usr/bin/ruby
require './trollop.rb'
require 'rubygems'
require 'json'
require './hypergraph'
require './optimization'
require './plot.rb'
class Array; def sum; inject( nil ) { |sum,x| sum ? sum+x : x }; end; end
class Array; def mean; sum / size; end; end

opts = Trollop::options do
  opt :ofile, "The output filename", :type => :string
end
Trollop::die :ofile, "must specify an output file name" if(opts[:ofile].nil?)

phone_freqs=[2460,2470,2475,2481]
wifi_freqs=[2412,2417,2422,2427,2432,2437,2442,2447,2452,2457,2462]
wifi_freqs_basic=[2412,2437,2462]
zigbee_freqs=[2405,2410,2415,2420,2425,2430,2435,2440,2445,2450,2455,2460,2465,2470,2476]
zigbee_basic=[2405,2440,2465,2470,2476]
wifi40_freqs=[2422,2432,2437,2447]

begin
  
  hgraph=Hypergraph.new

  (1..rand(8)).each {|i| hgraph.newNetwork("802.11agn", wifi_freqs_basic, rand, nil, [-40,0], nil) } 
  (1..rand(8)).each {|i| hgraph.newNetwork("802.11n", wifi_freqs_basic, rand, nil, [-40,0], nil) } 
  (1..rand(8)).each {|i| hgraph.newNetwork("802.11n", wifi_freqs_basic, rand, nil, [-40,0], nil) } 
  (1..rand(3)).each {|i| hgraph.newNetwork("802.11n-40MHz", wifi40_freqs, rand, nil, [-40,0], nil) } 
  (1..rand(3)).each {|i| hgraph.newNetwork("ZigBee", zigbee_basic, rand*0.30, nil, [-40,0], nil) }
  (1..rand(3)).each {|i| hgraph.newNetwork("Analog", phone_freqs, 0.999, nil, [-40,0], nil) }

  # Now, for each pair of links, throw in some probability that the transmitters are within range and that the
  # receive is within range (i.e., a conflict)
  hgraph.getLinkEdges.each do |baseEdge|
    hgraph.getLinkEdges.each do |oppEdge|
      next if(baseEdge==oppEdge)
      rnd = rand
      if(rand < 0.01)  # A conflict scenario
        hgraph.newSpatialEdge(SpatialEdge.new(oppEdge.srcID, baseEdge.srcID, -20, 0))
        hgraph.newSpatialEdge(SpatialEdge.new(oppEdge.srcID, baseEdge.dstID, -20, 0))
      elsif(rand < 0.05) # A spatial edge to, but not coordinating
        hgraph.newSpatialEdge(SpatialEdge.new(oppEdge.srcID, baseEdge.srcID, -20, 0))
        hgraph.newSpatialEdge(SpatialEdge.new(oppEdge.srcID, baseEdge.dstID, -70, 0))
      elsif(rand < 0.4) # A spatial edge to, and coordinating
        break if(oppEdge.srcID == baseEdge.dstID)
        hgraph.newSpatialEdge(SpatialEdge.new(oppEdge.srcID, baseEdge.dstID, -20, 1))
      else # no edge, no change.  just out of range, let it be
      end
    end
  end

 f=File.open(opts[:ofile],"w")
 f.write(hgraph.to_json)

end
