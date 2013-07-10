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
Link = Struct.new(:lID, :srcID, :dstID, :protocol, :freq, :bandwidth, :airtime, :txLen)
LinkView = Struct.new(:lID, :rssi, :backoff)

def error(err)
  puts err
  exit
end

def getTransmitterIDs(links)
  x = Array.new
  links.each {|l| x.push( l.srcID ) if(not l.nil?) }
  return x.uniq
end

def getLinksByTransmitter(links,rid)
  x = Array.new
  links.each {|l| x.push(l) if(not l.nil? and l.srcID==rid)}
  return x
end

def getLinksByRID(links,rid)
  x = Array.new
  links.each {|l| x.push(l) if(not l.nil? and (l.srcID==rid or l.dstID==rid))}
  return x
end

def getRadiosFromLinks(links)
  x = Array.new
  links.each do |l|
    x.push(l.srcID) if(not l.nil?)
    x.push(l.dstID) if(not l.nil?)
  end
  return x.uniq
end

begin
  
  #################################################################################################
  # A few variables to keep track of the data
  #######
  mapItemByID = Hash.new      # For keeping track of the device map, indexed by radioID
  mapItemByName = Hash.new    # Indexing it by radioName
  
  linkIDs = Hash.new        # Get a link ID by source and destination
  links = Array.new         # Store the links, exactly at the index of the linkID

  uridToRID = Array.new     # Keep track of unique ID (UID) for each ID
  ridToURID = Hash.new      # Go from ID to a UID
  
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
  lastLinkID=0
  links.push(nil)
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
        next
      end
      
      ls = line.split  # Go ahead and split the line

      # Create a unique linkID for this link if it does not yet exist
      lSrc = ls[0]
      lDst = ls[1]
      if(not linkIDs.has_key?([lSrc,lDst]))
        lID = lastLinkID+1 
        linkIDs[[lSrc,lDst]]=lID
        lastLinkID+=1
        pushLink=true
      else
        lID = linkIDs[[lSrc,lDst]]
        pushLink=false
      end

      # Read in the link data
      li = Link.new(lID,          # Put the link ID in which is unique
                    ls[0],        # The source ID for the link
                    ls[1],        # The destination ID for the link
                    ls[2],        # the protocol used for the link
                    ls[3].to_i,   # The frequency used
                    ls[5].to_i,   # The bandwidth used on the link
                    ls[6].to_f,   # The airtime observed on the link from the source to destination
                    ls[7].to_i)   # The average transmission length in microseconds
                    
      lv = LinkView.new(lID,      # The link ID seen by this view
                    ls[4].to_i,   # the RSSI from the transmitter to the baseline node
                    ls[8].to_i)   # Whether the baseline node backs off to this link

      # Store the link if we haven't seen it before
      links.push(li) if(pushLink)

    end
  end

  #################################################################################################
  ## Now, we need a unique numeric ID for every single transmitter.  This is strictly for the
  ## MIP optimization representation.  We need to keep track of these and we can have a lookup.
  urid=1
  getRadiosFromLinks(links).each do |rid|
    ridToURID[rid]=urid
    uridToRID[urid]=rid
    urid+=1
  end

  puts ridToURID.inspect
  
  #################################################################################################
  ## Output the frequencies to the appropriate ZIMPL file.  This specifies, for each radio,
  ## the possible set of frequencies that can be *configured*.  That means, if we cannot reconfigure
  ## the transmitter, it should only have 1 possible frequency: its current.
  of = File.new("radio_frequencies.zpl","w")
  of.puts "set FB[R] :="
  (1 .. uridToRID.size-1).each do |urid|
    rid=uridToRID[urid]        # get the ID from the UID
    mi=mapItemByID[rid]        # Get the map item if it exists based on the ID
    of.print "\t<#{urid}> {"   # Print out the header

    # If there is no map item associated, then the possible set of frequencies is just the
    # frequency it is operating on.  We take this from any of the active links it is involved in.
    if(mi.nil?)
      of.print "#{getLinksByRID(links,rid)[0].freq}e3}"
    else
      mi[:frequencies].each_index do |i|
        of.print "#{mi[:frequencies][i]}e3"
        of.print "," if(i<mi[:frequencies].size-1)
      end
      of.print "}"
    end

    of.puts "," if(urid<uridToRID.size-1)
    of.puts ";" if(urid==uridToRID.size-1)
  end
  of.close

  #################################################################################################
  ## Go through and output all of the radios within spatial range and not.  This is 'S' in the
  ## optimization representation.
  of = File.new("spatial_range.zpl", "w")
  of.puts "set S[R] :="
  toOut=spatialRangeByID.size
  spatialRangeByID.each do |idBR,xmitters|  # idBR: id of the baseline radio
    uridBR = ridToURID[idBR]
    of.print "\t<#{uridBR}> {"   # Print out the header
    xmitters.uniq!
    xmitters.each_index do |xi|
      idTR=xmitters[xi]
      uridTR = ridToURID[idTR]
      of.print "#{uridTR}"
      of.print "," if(xi<xmitters.size-1)
    end
    of.puts "}," if(toOut>1)
    of.puts "};" if(toOut==1)
    toOut-=1
  end
  of.close

  #################################################################################################
  ## Now we go through and prepare the links and transfer them over to the optimization.  We first
  ## need to condense the links so that there is only a single "link" for every transmitter and
  ## receiver.
  #puts linkViews.inspect
  
  #################################################################################################
  ## Go through all of the radios and place them in to coordination or not


end
