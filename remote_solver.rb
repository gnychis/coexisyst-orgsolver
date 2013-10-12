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
phosts=(10..15).to_a

# For each objective function, launch a new process
threads=Array.new
objectives.each do |obj|

  host=phosts[rand(phosts.length)]
  phosts.delete(host)
  puts "Running #{obj} on ece0#{host}"

  x = Thread.new { 
    Thread.current[:host]=host
    exec = "ssh -o 'StrictHostKeyChecking no' ece0#{host} 2>/dev/null << EOF\n"
    exec += "export PATH=$PATH:/afs/ece.cmu.edu/usr/gnychis/bin\n"
    exec += "export PATH=/afs/ece.cmu.edu/usr/gnychis/usr/bin:$PATH\n"
    exec += "cd #{curr_dir}\n"
    exec += "ruby solve_hypergraph.rb -f #{opts[:file]} -o #{obj}\n"
    exec += "EOF\n"
    `#{exec}`
    puts "Done with objective #{obj}"
    phosts.push(host)
  }

  threads.push(x)
end

threads.each {|t| t.join}
