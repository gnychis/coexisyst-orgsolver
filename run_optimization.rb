#!/usr/bin/ruby
require 'trollop'

opts = Trollop::options do
  opt :directory, "The directory containing the data", :type => :string
end

# A couple tests to make sure we are OK to run
Trollop::die :directory, "must exist" if(opts[:directory].nil? || File.directory?(opts[:directory])==false)
Trollop::die :directory, "must include map.txt" if(File.exist?("#{opts[:directory]}/map.txt")==false)
Trollop::die :directory, "must include data in files labaled capture<#>.dat" if(Dir.glob("#{opts[:directory]}/capture*.dat").size<1)

MapItem = Struct.new(:radioID, :protoID, :radioName, :netID, :bandwidth, :dAirtime, :frequencies)

def error(err)
  puts err
  exit
end

begin
  
  map = Hash.new          # For keeping track of the device map, indexed by radioID
  mapByName = Hash.new    # Indexing it by radioName

  # Read in the map.txt file in to a data structure
  File.readlines("#{opts[:directory]}/map.txt").each do |line|
    ls = line.split
    f = line[line.index("{")+1,line.index("}")-line.index("{")-1].split(",").map{|i| i.to_i}
    mi = MapItem.new(ls[0], ls[1].to_i, ls[2], ls[3], ls[4].to_i, ls[5].to_f, f)
    error("map radioID collision -- #{mi.inspect}") if(map.has_key?(mi[:radioID]))
    error("map radioName collision -- #{mi.inspect}") if(mapByName.has_key?(mi[:radioName]))
    map[mi[:radioID]]=mi
    mapByName[mi[:radioName]]=mi
  end

  # Now, go through each of the data files
  Dir.glob("#{opts[:directory]}/capture*.dat").each do |capfile|
    File.readlines(capfile).each do |line|

      

    end
  end
end
