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
Link = Struct.new(:lID, :srcID, :dstID, :freq, :bandwidth, :airtime, :txLen, :protocol)
LinkView = Struct.new(:lID, :rssi, :backoff)

def error(err)
  puts err
  exit
end

def coordinates(links, linkProtocols, ridBR, ridOR)
  linksBR=getLinksByRID(links, ridBR)
  linksOR=getLinksByRID(links, ridOR)
  lid1 = linksBR[0].lID
  lid2 = linksOR[0].lID
  return true if(linkProtocols[lid1]==linkProtocols[lid2])
  return false
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

def getLinksFromViews(links, linkViews)
  return [] if(links.nil? or linkViews.nil? or linkViews.size==0 or links.size==0)
  x = Array.new
  linkViews.each {|lv| x.push(links[lv[:lID]])}
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
  linkProtocols = Array.new # Keep track of the protocols on each link

  uridToRID = Array.new     # Keep track of unique ID (UID) for each ID
  ridToURID = Hash.new      # Go from ID to a UID

  linksInRange = Hash.new   # All of the links in range of a radio, indexed by RID
  
  dataOF = File.new("data.zpl", "w")
  
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
  linkProtocols.push(nil)
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

        linksInRange[baselineRadioInfo.radioID] = Array.new
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
                    ls[3].to_i,   # The frequency used
                    ls[5].to_i,   # The bandwidth used on the link
                    ls[6].to_f,   # The airtime observed on the link from the source to destination
                    ls[7].to_i)   # The average transmission length in microseconds
                    
      lv = LinkView.new(lID,      # The link ID seen by this view
                    ls[4].to_i,   # the RSSI from the transmitter to the baseline node
                    ls[8].to_i)   # Whether the baseline node backs off to this link

      # Store the link if we haven't seen it before
      links.push(li) if(pushLink)
      linkProtocols.push(ls[2]) if(pushLink)

      # But always push that the link is within range of the baseline radio, even if we've seen it
      # before within range of another radio.
      linksInRange[baselineRadioInfo.radioID].push(lv)

    end
  end

  #################################################################################################
  ## Now, we need a unique numeric ID for every single transmitter.  This is strictly for the
  ## MIP optimization representation.  We need to keep track of these and we can have a lookup.
  dataOF.puts "############################################################"
  dataOF.puts "## Information related to links"
  dataOF.puts ""
  urid=1
  urids=Array.new
  getRadiosFromLinks(links).each do |rid|
    ridToURID[rid]=urid
    uridToRID[urid]=rid
    urids.push(urid)
    urid+=1
  end
  dataOF.puts "  # The set of radios in the optimization"
  dataOF.puts "  set R       := { #{urids.inspect[1..-2]} };"
  dataOF.puts "\n"

  #################################################################################################
  ## Output the frequencies to the appropriate ZIMPL file.  This specifies, for each radio,
  ## the possible set of frequencies that can be *configured*.  That means, if we cannot reconfigure
  ## the transmitter, it should only have 1 possible frequency: its current.
  dataOF.puts "  # The frequencies available for each radio"
  dataOF.puts "  set FB[R] :="
  (1 .. uridToRID.size-1).each do |urid|
    rid=uridToRID[urid]        # get the ID from the UID
    mi=mapItemByID[rid]        # Get the map item if it exists based on the ID
    dataOF.print "\t<#{urid}> {"   # Print out the header

    # If there is no map item associated, then the possible set of frequencies is just the
    # frequency it is operating on.  We take this from any of the active links it is involved in.
    if(mi.nil?)
      dataOF.print "#{getLinksByRID(links,rid)[0].freq}e3}"
    else
      mi[:frequencies].each_index do |i|
        dataOF.print "#{mi[:frequencies][i]}e3"
        dataOF.print "," if(i<mi[:frequencies].size-1)
      end
      dataOF.print "}"
    end

    dataOF.puts "," if(urid<uridToRID.size-1)
    dataOF.puts ";" if(urid==uridToRID.size-1)
  end
  dataOF.puts ""

  #################################################################################################
  ## Now we go through and prepare the links and transfer them over to the optimization.  We first
  ## need to condense the links so that there is only a single "link" for every transmitter and
  ## receiver.
  lids = Array.new; links.each {|l| lids.push(l.lID) if(not l.nil?)}
  dataOF.puts "\n\n############################################################"
  dataOF.puts "## Information related to links"
  dataOF.puts ""
  dataOF.puts "  # The set of links and the attributes for each link"
  dataOF.puts "  set LIDs       := { #{lids.inspect[1..-2]} };"
  dataOF.puts "  set LinkAttr   := { #{Link.members.inspect[8..-2]} };"
  dataOF.puts ""
  dataOF.puts "  # The data for each link"
  dataOF.puts "  param L[LIDs * LinkAttr] :="
  dataOF.print "      |#{Link.members.inspect[8..-14]}|"
  links.each do |l|
    next if(l.nil?)
    dataOF.print "\n   |#{l.lID}|\t    #{ridToURID[l.srcID]},\t      #{ridToURID[l.dstID]},  #{l.freq},\t\t  #{l.bandwidth},\t    #{l.airtime},   #{l.txLen} |"
  end
  dataOF.print ";\n"

  #################################################################################################
  ## Go through and output all of the radios within spatial range and not.  This is 'S' in the
  ## optimization representation.  For each radio that we have a "view" at, we go through and
  ## mark the transmitters in range
  dataOF.puts "\n\n############################################################"
  dataOF.puts "## Information related to spatial data, what is in range of what"
  dataOF.puts ""
  dataOF.puts "  # For each radio, the list of radios that are within spatial range of it"
  dataOF.puts "  set SR[R] :="
  sr=Array.new; sr.push(nil)
  (1 .. uridToRID.size-1).each do |urid|
    idBR=uridToRID[urid]
    lvs = linksInRange[idBR]
    dataOF.print "\t<#{urid}> {"   # Print out the header
    xmitters=getTransmitterIDs(getLinksFromViews(links,lvs))
    sr[urid]=Array.new
    xmitters.each_index do |xi|
      idTR=xmitters[xi]
      uridTR = ridToURID[idTR]
      dataOF.print "#{uridTR}"
      dataOF.print "," if(xi<xmitters.size-1)
      sr[urid].push(uridTR)
    end
    dataOF.puts "}," if(urid<uridToRID.size-1)
    dataOF.puts "};" if(urid==uridToRID.size-1)
  end
  
  dataOF.puts ""
  dataOF.puts "  # For each radio, the list of links that are within spatial range of it"
  dataOF.puts "  set SL[R] :="
  sl=Array.new; sl.push(nil)
  (1 .. uridToRID.size-1).each do |urid|
    idBR=uridToRID[urid]
    lvs = linksInRange[idBR]
    dataOF.print "\t<#{urid}> {"   # Print out the header
    lks=getLinksFromViews(links,lvs)
    sl[urid] = Array.new
    lks.each_index do |lk|
      dataOF.print "#{lks[lk].lID}"
      dataOF.print "," if(lk<lks.size-1)
      sl[urid].push(lks[lk].lID)
    end
    dataOF.puts "}," if(urid<uridToRID.size-1)
    dataOF.puts "};" if(urid==uridToRID.size-1)
  end

  #################################################################################################
  ## Go through all of the radios and place them in to coordination or not.
  dataOF.puts "\n\n############################################################"
  dataOF.puts "## Information about what coordinates with what"
  dataOF.puts ""
  dataOF.puts "  # for each radio, the radios it coordinates with in spatial range"
  dataOF.puts "  set CRR[R] :="
  (1 .. uridToRID.size-1).each do |uridBR|
    ridBR=uridToRID[uridBR]
    dataOF.print "\t<#{uridBR}> {"   # Print out the header
    coord=Array.new
    sr[uridBR].each do |uridOR|
      ridOR=uridToRID[uridOR]
      c=coordinates(links, linkProtocols, ridBR, ridOR)
      coord.push(uridOR) if(c)
    end
    dataOF.print "#{coord.inspect[1..-2]}"
    dataOF.puts "}," if(uridBR<uridToRID.size-1)
    dataOF.puts "};" if(uridBR==uridToRID.size-1)
  end

  dataOF.puts ""
  dataOF.puts "  # for each radio, the links it coordinates with in spatial range"
  dataOF.puts "  set CRL[R] :="
  (1 .. uridToRID.size-1).each do |uridBR|
    ridBR=uridToRID[uridBR]
    dataOF.print "\t<#{uridBR}> {"   # Print out the header
    coord=Array.new
    sr[uridBR].each do |uridOR|
      ridOR=uridToRID[uridOR]
      c=coordinates(links, linkProtocols, ridBR, ridOR)
      if(c)
        lks=getLinksByTransmitter(links, ridOR)
        lks.each {|l| coord.push(l.lID)}
      end
      #coord.push(uridOR) if(c)
    end
    dataOF.print "#{coord.inspect[1..-2]}"
    dataOF.puts "}," if(uridBR<uridToRID.size-1)
    dataOF.puts "};" if(uridBR==uridToRID.size-1)
  end

  dataOF.close
end
