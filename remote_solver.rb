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
end
Trollop::die :file, "must exist" if(opts[:file].nil? || File.exist?(opts[:file])==false)

# The current directory to know where to run from
curr_dir=Dir.pwd

# The potential hosts to run the process on
phosts=(10..31).to_a

# For each objective function, launch a new process
objectives.each do |obj|

  host=phosts[rand(phosts.length)]
  phosts.delete(host)

  x = Thread.new { 
    exec = "ssh -o 'StrictHostKeyChecking no' ece0#{host} << EOF\n"
    exec += "cd #{curr_dir}\n"
    exec += "./solve_hypergraph.rb -f #{opts[:file]} -o #{obj}\n"
    exec += "EOF\n"
    `#{exec}`
    puts "Done with objective #{obj}"
  }

  x.join
end
