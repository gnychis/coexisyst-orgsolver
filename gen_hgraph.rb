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

phone_freqs=[2470,2475,2480,2483]
wifi_freqs=[2412,2417,2422,2427,2432,2437,2442,2447,2452,2457,2462]
wifi_freqs_basic=[2412,2437,2462]
zigbee_freqs=[2405,2410,2415,2420,2425,2430,2435,2440,2445,2450,2455,2460,2465,2470,2476]

npairs=1
total_radios=0

begin
  
  a="Estimated Airtime"
  b="Estimated Loss Rate ({/Symbol s}_r)"
  c="Estimated Usable Airtime"

  hgraph=Hypergraph.new

  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.510, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.320, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.70, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.60, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.30, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.25, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.25, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.30, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil)
  hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.25, nil, [-40,0], nil)
  hgraph.newNetwork("Analog", [2480], 0.999, nil, [-40,0], nil)
  hgraph.newNetwork("ZigBee", [2476], 0.25, nil, [-40,0], nil)
  hgraph.newNetwork("ZigBee", [2476], 0.15, nil, [-40,0], nil)

  # Connect all transmitters!!
  transmitters=Array.new
  hgraph.getLinkEdges.each {|le| transmitters.push(le.srcID)}
  transmitters.each do |tx1|
    transmitters.each do |tx2|
      next if(tx1==tx2)
      hgraph.newSpatialEdge(SpatialEdge.new(tx1, tx2, -20, 1))
      hgraph.newSpatialEdge(SpatialEdge.new(tx2, tx1, -20, 1))
    end
  end

 f=File.open(opts[:ofile],"w")
 f.write(hgraph.to_json)

end
