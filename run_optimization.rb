#!/usr/bin/ruby
require 'trollop'
require 'hgraph'

opts = Trollop::options do
  opt :directory, "The directory containing the data", :type => :string
end

# A couple tests to make sure we are OK to run
Trollop::die :directory, "must exist" if(opts[:directory].nil? || File.directory?(opts[:directory])==false)
Trollop::die :directory, "must include map.txt" if(File.exist?("#{opts[:directory]}/map.txt")==false)
Trollop::die :directory, "must include data in files labaled capture<#>.dat" if(Dir.glob("#{opts[:directory]}/capture*.dat").size<1)

Radio = Struct.new(:radioID, :protocol, :radioName, :networkID, :frequencies)
SpatialEdge = Struct.new(:from, :to, :rssi, :backoff)
LinkEdge = Struct.new(:srcID, :dstID, :freq, :bandwidth, :airtime, :dAirtime, :txLen, :protocol)
Hyperedge = Struct.new(:id, :radios)

hgraph=Hypergraph.new(opts[:directory])
opt = Optimization.new(hgraph)


