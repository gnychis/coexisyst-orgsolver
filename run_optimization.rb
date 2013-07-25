#!/usr/bin/ruby
require 'trollop'
require 'hypergraph'
require 'optimization'

opts = Trollop::options do
  opt :directory, "The directory containing the data", :type => :string
end

# A couple tests to make sure we are OK to run
Trollop::die :directory, "must exist" if(opts[:directory].nil? || File.directory?(opts[:directory])==false)
Trollop::die :directory, "must include map.txt" if(File.exist?("#{opts[:directory]}/map.txt")==false)
Trollop::die :directory, "must include data in files labaled capture<#>.dat" if(Dir.glob("#{opts[:directory]}/capture*.dat").size<1)

hgraph=Hypergraph.new
hgraph.loadData(opts[:directory])

opt = Optimization.new(hgraph)

puts opt.run.inspect
