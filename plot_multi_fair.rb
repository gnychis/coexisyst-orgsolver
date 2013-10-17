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

objectives=["prodPropAirtime","jainFairness"]

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

allRadios=Hash.new

options=nil
data=nil
objectives.each do |obj|

  opt = Optimization.new(hgraph)
  opt.reload_data(Objective::FCFS,"#{prefix}_#{obj}.sol")

  data, options, locations, values = opt.getFairnessBarPlot()
  allRadios[obj] = [locations, values]

end
data=Hash.new
options = Optimization.getMultiFairnessBarPlot(allRadios,options)

plot("#{prefix}_airtime_multi",data,options)
