#!/usr/bin/ruby
require 'trollop'

opts = Trollop::options do
  opt :directory, "The directory containing the data", :type => :string
end

# A couple tests to make sure we are OK to run
Trollop::die :directory, "must exist" if(opts[:directory].nil? || File.directory?(opts[:directory])==false)
Trollop::die :directory, "must include map.txt" if(File.exist?("#{opts[:directory]}/map.txt")==false)
Trollop::die :directory, "must include data in files labaled capture<#>.dat" if(Dir.glob("#{opts[:directory]}/capture*.dat").size<1)

MapItem = Struct.new(:radioID, :protoID, :radioName, :netID, :frequencies)
Link = Struct.new(:srcID, :dstID, :protoID, :freq, :rssi, :bandwidth, :airtime, :txLen, :backoff)

def error(err)
  puts err
  exit
end

begin
  
  #################################################################################################
  # A few variables to keep track of the data
  #######
  mapByID = Hash.new      # For keeping track of the device map, indexed by radioID
  mapByName = Hash.new    # Indexing it by radioName

  linksByID = Hash.new    # Keep track the links that belong to specific node
  linksByName = Hash.new  # Keep track of the links by name

  linksByBaseline = Hash.new    # Monitored at a baseline, all of the links

  uidToID = Array.new     # Keep track of unique ID (UID) for each ID
  idToUID = Hash.new      # Go from ID to a UID

  #################################################################################################
  # Read in the map.txt file in to a data structure
  #######
  File.readlines("#{opts[:directory]}/map.txt").each do |line|

    # Read in the map data
    ls = line.split
    f = line[line.index("{")+1,line.index("}")-line.index("{")-1].split(",").map{|i| i.to_i}
    mi = MapItem.new(ls[0],       # the radioID
                     ls[1].to_i,  # the protocol ID
                     ls[2],       # the radio name
                     ls[3], f)    # the set of frequencies
    
    # Make sure for some reason that two nodes in the map do not have the same ID or name.
    # These must both be unique for the code to work properly.
    error("map radioID collision -- #{mi.inspect}") if(mapByID.has_key?(mi[:radioID]))
    error("map radioName collision -- #{mi.inspect}") if(mapByName.has_key?(mi[:radioName]))
    
    # Map the data to the ID and name
    mapByID[mi[:radioID]]=mi
    mapByName[mi[:radioName]]=mi
  end

  #################################################################################################
  # Now, go through each of the data files and read the link data associated to the node
  #######
  Dir.glob("#{opts[:directory]}/capture*.dat").each do |capfile|
    
    baselineRadio=nil   # Store the baseline radio for the capture file

    File.readlines(capfile).each do |line|

      if(baselineRadio.nil?)
        baselineRadio = line.chomp       
        linksByBaseline[baselineRadio]=Array.new if(not linksByBaseline.has_key?(baselineRadio))
        puts mapByName.inspect
        linksByID[mapByName[baselineRadio].radioID]=Array.new
        next
      end

      # Read in the link data
      ls = line.split
      li = Link.new(ls[0],        # The source ID for the link
                    ls[1],        # The destination ID for the link
                    ls[2].to_i,   # the protocol ID used for the link
                    ls[3].to_i,   # The frequency used
                    ls[4].to_i,   # the RSSI from the transmitter to the baseline node
                    ls[5].to_i,   # The bandwidth used on the link
                    ls[6].to_f,   # The airtime observed on the link from the source to destination
                    ls[7].to_i,   # The average transmission length in microseconds
                    ls[8].to_i)   # Whether the baseline node backs off to this link

      # Keep track of all the links that were "seen" by the baseline node, this is its view
      linksByBaseline[baselineRadio].push( li )

      # Keep track of all links by their srcID, as we consider links belonging to the transmitter
      linksByID[li[:srcID]]=Array.new if(not linksByID.has_key?(li[:srcID]))
      linksByID[li[:srcID]].push( li )

      # Keep track of all links by their name also, if one exists.  This is for convenience.
      radioName = mapByID[li[:srcID]].radioName if(not mapByID[li[:srcID]].nil?)
      linksByName[radioName]=Array.new if(not radioName.nil? and not linksByName.has_key?(radioName))
      linksByName[radioName].push( li ) if(not radioName.nil?)

    end
  end

  #################################################################################################
  ## Now, we need a unique numeric ID for every single transmitter.  This is strictly for the
  ## MIP optimization representation.  We need to keep track of these and we can have a lookup.
  uid=1
  linksByID.each_key do |id|
    idToUID[id]=uid
    uidToID[uid]=id
    uid+=1
  end
  
  #################################################################################################
  ## Output the frequencies to the appropriate ZIMPL file.  This specifies, for each transmitter,
  ## the possible set of frequencies that can be *configured*.  That means, if we cannot reconfigure
  ## the transmitter, it should only have 1 possible frequency: its current.
  of = File.new("radio_frequencies.zpl","w")
  of.puts "set FB[W] :="
  (1 .. uidToID.size-1).each do |uid|
    puts "#{uid} --> #{uidToID[uid]}"
  end
  of.close


end
