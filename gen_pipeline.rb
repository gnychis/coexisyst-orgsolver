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

phone_freqs=[2475,2481]
wifi_freqs=[2412,2417,2422,2427,2432,2437,2442,2447,2452,2457,2462]
wifi_freqs_basic=[2412,2437,2462]
zigbee_freqs=[2405,2410,2415,2420,2425,2430,2435,2440,2445,2450,2455,2460,2465,2470,2476]
zigbee_basic=[2405,2440,2465,2470,2476]
wifi40_freqs=[2422,2432,2437,2447]

begin
  
  hgraph=Hypergraph.new
  networks=Array.new
  
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.510, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.320, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.70, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.60, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.30, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.25, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.25, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.30, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.10, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("802.11agn", wifi_freqs_basic, 0.25, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("Analog", [2480], 0.999, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("ZigBee", zigbee_basic, 0.25, nil, [-40,0], nil))
  networks.push(hgraph.newNetwork("ZigBee", zigbee_basic, 0.15, nil, [-40,0], nil))

  opt = Optimization.new(hgraph)
  splot,options = opt.getPipelinePlot(networks.shuffle)

  prefix=opts[:ofile].split(".")[0]

#  options["additional"]+="set label \"Scenario: Basic 3\" at #{options["xrange"][1]-0.6},1.29 font \"Times-Roman,80\"\n"
  plot("#{prefix}_pipeline",splot,options)

end
