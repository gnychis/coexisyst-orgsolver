#!/usr/bin/ruby
require './trollop.rb'
require 'rubygems'
require 'json'
require './hypergraph'
require './optimization'
require './plot.rb'
class Array; def sum; inject( nil ) { |sum,x| sum ? sum+x : x }; end; end
class Array; def mean; sum / size; end; end

objectives=["prodPropAirtime","sumAirtime","propAirtime","jainFairness","FCFS","LF"]

opts = Trollop::options do
  opt :file, "The input filename", :type => :string
  opt :objective, "The objective function to use: #{objectives.inspect}", :type => :string
end
Trollop::die :file, "must exist" if(opts[:file].nil? || File.exist?(opts[:file])==false)
Trollop::die :objective, "Must pick a valid objective function"if(not objectives.include?(opts[:objective]))

prefix=opts[:file].split(".")[0]

data=File.read(opts[:file])
hgraph_json = JSON.parse(data)

puts hgraph_json.inspect
