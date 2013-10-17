#!/usr/bin/ruby
require './trollop.rb'
require 'rubygems'
require 'json'
require './hypergraph'
require './optimization'
require './plot.rb'
require './cdf.rb'
class Array; def sum; inject( nil ) { |sum,x| sum ? sum+x : x }; end; end
class Array; def mean; sum / size; end; end

objectives=["prodPropAirtime","jainFairness","FCFS","LF"]

opts = Trollop::options do
  opt :file, "The input filename", :type => :string
end
Trollop::die :file, "must exist" if(opts[:file].nil? || File.exist?(opts[:file])==false)
prefix=opts[:file].split(".")[0]

# Read in the hypergraph specified
data=File.read(opts[:file])
hgraph_json = JSON.parse(data)

# Load in the original hypergraph
hgraph = Hypergraph.new
hgraph.init_json(hgraph_json)

data=Hash.new

objectives.each do |obj|

  opt = Optimization.new(hgraph)
  opt.reload_data(Objective::FCFS,"#{prefix}_#{obj}.sol")

  fbp_data, options = opt.getFairnessBarPlot()
  merged_data=Array.new
  fbp_data.each {|k,v| merged_data.concat(v)}

  obj="Optimization (Standard Objective)" if(obj=="prodPropAirtime")
  obj="Optimization (Jain's Fairness)" if(obj=="jainFairness")
  obj="Largest First (With Metric)" if(obj=="LF")

  data["x"] = cdf(merged_data,0,0.025,1).map {|i| i[0]}
  data[obj] = cdf(merged_data,0,0.025,1).map {|i| 1-i[1]}

end

plot("#{prefix}_airtime_cdf",data,Hash["lt",[5,7,3,1], "lc",[7,8,3,1], "yrange",[0,1], "style","lines", "grid",true, "usex",true, "linewidth",18, "ylabel","Fraction of Networks with an\\n Airtime Fraction of at least X", "xlabel","Airtime Fraction", "ytics",".2", "key", "invert at 0.73,0.4"])
