#!/usr/bin/ruby
require 'trollop'

opts = Trollop::options do
  opt :directory, "The directory containing the data", :type => :string
end

# A couple tests to make sure we are OK to run
Trollop::die :directory, "must exist" if(opts[:directory].nil? || File.directory?(opts[:directory])==false)
Trollop::die :directory, "must include map.txt" if(File.exist?("#{opts[:directory]}/map.txt")==false)
Trollop::die :directory, "must include data in files labaled capture<#>.dat" if(Dir.glob("#{opts[:directory]}/capture*.dat").size<1)

MapItem = Struct.new(:radioID, :protocol, :radioName, :netID, :frequencies)
Link = Struct.new(:srcID, :dstID, :protocol, :freq, :rssi, :bandwidth, :airtime, :txLen, :backoff)

def error(err)
  puts err
  exit
end

begin
  
  #################################################################################################
  # A few variables to keep track of the data
  #######
  mapItemByID = Hash.new      # For keeping track of the device map, indexed by radioID
  mapItemByName = Hash.new    # Indexing it by radioName

  linksByID = Hash.new    # Keep track the links that belong to specific node
  linksByName = Hash.new  # Keep track of the links by name

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
                     ls[1],       # the protocol
                     ls[2],       # the radio name
                     ls[3], f)    # the set of frequencies
    
    # Make sure for some reason that two nodes in the map do not have the same ID or name.
    # These must both be unique for the code to work properly.
    error("map radioID collision -- #{mi.inspect}") if(mapItemByID.has_key?(mi[:radioID]))
    error("map radioName collision -- #{mi.inspect}") if(mapItemByName.has_key?(mi[:radioName]))
    
    # Map the data to the ID and name
    mapItemByID[mi[:radioID]]=mi
    mapItemByName[mi[:radioName]]=mi
  end

  #################################################################################################
  # Now, go through each of the data files and read the link data associated to the node
  #######
  Dir.glob("#{opts[:directory]}/capture*.dat").each do |capfile|
    
    baselineRadio=nil           # Store the baseline radio for the capture file
    baselineRadioInfo=nil       # This should resolve to the map info

    File.readlines(capfile).each do |line|

      # Read in the baselineRadio if this is the very first line
      if(baselineRadio.nil?)
        baselineRadio = line.chomp.strip       

        # Lookup the info
        baselineRadioInfo = mapItemByName[baselineRadio]
        baselineRadioInfo = mapItemByID[baselineRadio] if(baselineRadioInfo.nil?)

        # Now, just create some empty Arrays for this radio also
        linksByID[baselineRadioInfo.radioID]=Array.new if(linksByID[baselineRadioInfo.radioID].nil?)
        linksByName[baselineRadioInfo.radioName]=Array.new if(linksByName[baselineRadioInfo.radioName].nil?)
        next
      end

      # Read in the link data
      ls = line.split
      li = Link.new(ls[0],        # The source ID for the link
                    ls[1],        # The destination ID for the link
                    ls[2],        # the protocol used for the link
                    ls[3].to_i,   # The frequency used
                    ls[4].to_i,   # the RSSI from the transmitter to the baseline node
                    ls[5].to_i,   # The bandwidth used on the link
                    ls[6].to_f,   # The airtime observed on the link from the source to destination
                    ls[7].to_i,   # The average transmission length in microseconds
                    ls[8].to_i)   # Whether the baseline node backs off to this link

      # Keep track of all links by their srcID, as we consider links belonging to the transmitter
      linksByID[li[:srcID]]=Array.new if(not linksByID.has_key?(li[:srcID]))
      linksByID[li[:srcID]].push( li )

      # Keep track of all links by their name also, if one exists.  This is for convenience.
      radioName = mapItemByID[li[:srcID]].radioName if(not mapItemByID[li[:srcID]].nil?)
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
    id=uidToID[uid]           # get the ID from the UID
    mi=mapItemByID[id]        # Get the map item if it exists based on the ID
    of.print "\t<#{uid}> {"   # Print out the header

    # If there is no map item associated, then the possible set of frequencies is just the
    # frequency it is operating on.  We take this from any of the active links it is involved in.
    if(mi.nil?)
      of.print "#{linksByID[id][0].freq}e3}"
    else
      mi[:frequencies].each_index do |i|
        of.print "#{mi[:frequencies][i]}e3"
        of.print "," if(i<mi[:frequencies].size-1)
      end
      of.print "}"
    end

    of.puts "," if(uid<uidToID.size-1)
    of.puts ";" if(uid==uidToID.size-1)

  end
  of.close



end
