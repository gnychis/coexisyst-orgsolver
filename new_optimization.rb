#!/usr/bin/ruby
require 'trollop'

opts = Trollop::options do
  opt :directory, "The directory containing the data", :type => :string
end

# A couple tests to make sure we are OK to run
Trollop::die :directory, "must exist" if(opts[:directory].nil? || File.directory?(opts[:directory])==false)
Trollop::die :directory, "must include map.txt" if(File.exist?("#{opts[:directory]}/map.txt")==false)
Trollop::die :directory, "must include data in files labaled capture<#>.dat" if(Dir.glob("#{opts[:directory]}/capture*.dat").size<1)

Radio = Struct.new(:radioID, :protocol, :radioName, :networkID, :frequencies)
SpatialEdge = Struct.new(:from, :to, :rssi, :backoff)
LinkEdge = Struct.new(:srcID, :dstID, :freq, :bandwidth, :airtime, :txLen, :protocol)
Hyperedge = Struct.new(:id, :radios)

class Hypergraph
  @@spatialEdges=Array.new
  @@radios=Array.new
  @@hyperEdges=Array.new     
  @@linkEdges=Array.new

  def getLinkEdges()
    return @@linkEdges
  end

  def getRadios()
    return @@radios
  end

  def printLinkEdges()
    @@linkEdges.each {|l| puts l.inspect}
  end

  def printHyperedges()
    @@hyperEdges.each {|h| puts h.inspect}
  end

  def printSpatialEdges()
    @@spatialEdges.each {|s| puts s.inspect } 
  end

  def printRadios()
    @@radios.each {|r| puts r.inspect }
  end
  
  def newSpatialEdge(edge)
    @@spatialEdges.push(edge) if(getSpatialEdge(edge.from, edge.to).nil?)
  end

  def getSpatialEdge(from, to)
    @@spatialEdges.each {|l| return l if(l.from==from and l.to==to)}
    return nil
  end

  def newLinkEdge(link)
    @@linkEdges.push(link) if(getLinkEdge(link.srcID, link.dstID).nil?)
  end

  def getLinkEdgesByTX(srcID)
    x = Array.new
    @@linkEdges.each {|l| x.push(l) if(l.srcID==srcID)}
    return x
  end

  def getLinkEdge(srcID, dstID)
    @@linkEdges.each {|l| return l if(l.srcID==srcID and l.dstID==dstID)}
    return nil
  end

  def getHyperedge(edgeID)
    @@hyperEdges.each {|h| return h if(h.id==edgeID)}
    return nil
  end

  def addToHyperedge(edgeID, radio)
    h=getHyperedge(edgeID)
    return false if(h.nil?)
    return false if(h.radios.include?(radio))
    h.radios.push(radio)
    return true
  end

  def inHyperedge?(edgeID, radio)
    h = getHyperedge(edgeID)
    return false if(h.nil?)
    return true if(h.radios.include?(radio))
  end

  def createHyperedge(networkID)
    @@hyperEdges.push(Hyperedge.new(networkID,Array.new)) if(getHyperedge(networkID).nil?)
  end

  def getRadioByName(radioName)
    @@radios.each {|r| return r if((not r.radioName.nil?) && r.radioName==radioName) }
    return nil
  end

  def getRadioIndex(radioID)
    @@radios.each_index {|i| return i if(@@radios[i].radioID==radioID)}
    return nil
  end

  def getRadio(radioID)
    @@radios.each {|r| return r if(r.radioID==radioID)}
    return nil
  end

  def newRadio(radio)
    @@radios.push(radio) if(getRadio(radio.radioID).nil?)
  end

end

hgraph=Hypergraph.new
  
#################################################################################################
# Read in the map.txt file in to a data structure
#######
File.readlines("#{opts[:directory]}/map.txt").each do |line|

  # Read in the map data
  ls = line.split
  f = line[line.index("{")+1,line.index("}")-line.index("{")-1].split(",").map{|i| i.to_i}

  r = Radio.new(ls[0],   # the radioID
                ls[1],   # the protocol
                ls[2],   # the radio name
                ls[3],   # the network name
                f)       # the set of frequencies


  # Store the radio if we do not yet have it in our graph
  hgraph.newRadio(r) if(hgraph.getRadio(r.radioID).nil?)

  # Store the hyperedge if we don't yet have the network in our graph
  if(hgraph.getHyperedge(r.networkID).nil?)
    hgraph.createHyperedge(r.networkID)
    hgraph.addToHyperedge(r.networkID, r)
  else
    hgraph.addToHyperedge(r.networkID, r)
  end
  
  ## FIXME: try to check for duplicate radio IDs and names
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
      baselineRadioID = line.chomp.strip       
      baselineRadio = hgraph.getRadioByName(baselineRadioID)   # Try to get it by name first
      baselineRadio = hgraph.getRadio(baselineRadioID) if(baselineRadio.nil?)  # Then, try to get it by ID
      next
    end
    
    ls = line.split  # Go ahead and split the line

    # Create a unique linkID for this link if it does not yet exist
    lSrc = ls[0]
    lDst = ls[1]
    if(hgraph.getLinkEdge(lSrc, lDst).nil?)
      hgraph.newLinkEdge( LinkEdge.new( 
                          ls[0],        # The source ID for the link
                          ls[1],        # The destination ID for the link
                          ls[3].to_i,   # The frequency used
                          ls[5].to_i,   # The bandwidth used on the link
                          ls[6].to_f,   # The airtime observed on the link from the source to destination
                          ls[7].to_i,  # The average transmission length in microseconds
                          ls[2]))       # The protocol in use on the link
    end
    
    # Create radio instances for both the source and destination if they do not exist
    [lSrc,lDst].each do |radioID|
      if(hgraph.getRadio(radioID).nil?)
        hgraph.newRadio( Radio.new(
                          radioID,
                          ls[2],
                          nil,
                          nil,
                          [ls[3].to_i]))
      end
    end

    # Now create a spatial edge from the link source to the baseline radio
    if(hgraph.getSpatialEdge(lSrc, baselineRadio.radioID).nil? and lSrc!=baselineRadio.radioID)
      hgraph.newSpatialEdge( SpatialEdge.new(
                             lSrc,                      # From
                             baselineRadio.radioID,     # To
                             ls[4].to_i,                # RSSI
                             ls[8].to_i                 # Backoff
                             ))
    end
  end
end


dataOF = File.new("data.zpl", "w")

#################################################################################################
## Now, we need a unique numeric ID for every single transmitter.  This is strictly for the
## MIP optimization representation.  We need to keep track of these and we can have a lookup.
dataOF.puts "############################################################"
dataOF.puts "## Information related to radios"
dataOF.puts ""
dataOF.puts "  # The set of radios in the optimization"
dataOF.puts "  set R       := { #{(1..hgraph.getRadios.size).to_a.inspect[1..-2]} };"
dataOF.puts "\n"
dataOF.puts "  # The frequencies available for each radio"
dataOF.puts "  set FB[R] :="
hgraph.getRadios.each_index do |r|
  dataOF.print "\t<#{r+1}> { #{hgraph.getRadios[r].frequencies.inspect[1..-2]} }"   # Print out the header
  dataOF.puts "," if(r<hgraph.getRadios.size-1)
  dataOF.puts ";" if(r==hgraph.getRadios.size-1)
end

#################################################################################################
## Now we go through and prepare the links and transfer them over to the optimization.  We first
## need to condense the links so that there is only a single "link" for every transmitter and
## receiver.
dataOF.puts "\n\n############################################################"
dataOF.puts "## Information related to links"
dataOF.puts ""
dataOF.puts "  # The set of links and the attributes for each link"
dataOF.puts "  set LIDs       := { #{(1..hgraph.getLinkEdges.size).to_a.inspect[1..-2]} };"
dataOF.puts "  set LinkAttr   := { #{LinkEdge.members.inspect[1..-2]} };"
dataOF.puts ""
dataOF.puts "  # The data for each link"
dataOF.puts "  param L[LIDs * LinkAttr] :="
dataOF.print "      |#{LinkEdge.members.inspect[1..-14]} |"
hgraph.getLinkEdges.each_index do |l|
  le = hgraph.getLinkEdges[l]
  dataOF.print "\n   |#{l+1}|\t    #{hgraph.getRadioIndex(le.srcID)+1},\t      #{hgraph.getRadioIndex(le.dstID)+1},  #{le.freq},\t\t  #{le.bandwidth},\t    #{le.airtime},   #{le.txLen}  |"
end
dataOF.print ";\n"


#################################################################################################
## Output the hyperlinks in the graph

#################################################################################################
## Outputting the coordinating set of links.  
dataOF.puts "\n\n############################################################"
dataOF.puts "## Information related to coordination between links"
dataOF.puts ""
allLinks = hgraph.getLinkEdges
coordByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| coordByRadio.push(Array.new)}
coordByLink=Array.new;  (1..hgraph.getLinkEdges.size).each {|i| coordByLink.push(Array.new)}
allLinks.each_index do |bli|
  baseLink = allLinks[bli]
  radioIndex = hgraph.getRadioIndex(baseLink.srcID)

  allLinks.each_index do |oli|
    oppLink = allLinks[oli]
    outgoingSE = hgraph.getSpatialEdge(baseLink.srcID, oppLink.srcID)
    incomingSE = hgraph.getSpatialEdge(oppLink.srcID, baseLink.srcID)

    # Skip if the links are the same or if both links have same transmitter
    next if(oppLink == baseLink)
    next if(oppLink.srcID==baseLink.srcID)

    next if(outgoingSE.nil? or incomingSE.nil?)

    if(outgoingSE.backoff==1 and incomingSE.backoff==1)
      coordByRadio[radioIndex].push(oli+1) if(not coordByRadio[radioIndex].include?(oli+1))
      coordByLink[bli].push(oli+1) if(not coordByLink[bli].include?(oli+1))
    end
  end
end
dataOF.puts "  # For all radios, the set of links that the radio coordinates with"
dataOF.puts "  set CR[R] :="
coordByRadio.each_index do |r|
  dataOF.print "\t<#{r+1}> { #{coordByRadio[r].inspect[1..-2]} }"   # Print out the header
  dataOF.puts "," if(r<coordByRadio.size-1)
  dataOF.puts ";" if(r==coordByRadio.size-1)
end
#hgraph.printRadios
#puts hgraph.getRadios.size

#dataOF.puts "\n  # For all links, the set of links that the radio coordinates with"
#dataOF.puts "  set CL[R] :="
#coordByLink.each_index do |l|
#  dataOF.print "\t<#{l+1}> { #{coordByLink[l].inspect[1..-2]} }"   # Print out the header
#  dataOF.puts "," if(l<coordByLink.size-1)
#  dataOF.puts ";" if(l==coordByLink.size-1)
#end

#################################################################################################
## Go through and check against sets of conflicts between a pair of links.
## The interaction that we care about is as follows:
##    1.  That the receiver is within spatial range of the opposing transmitter.  If it's not,
##        there is no possible conflict.
##    2.  The interaction between the two transmitters.  Do they defer to each other or not?
##
## For each link, go through and mark each of the other links as coordinating or conflicting, 
## and whether the conflict is symmetric or asymmetric
allLinks = hgraph.getLinkEdges
symByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| symByRadio.push(Array.new)}
asym1ByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| asym1ByRadio.push(Array.new)}
asym2ByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| asym2ByRadio.push(Array.new)}
allLinks.each_index do |bli|
  baseLink = allLinks[bli]
  radioIndex = hgraph.getRadioIndex(baseLink.srcID)

  allLinks.each_index do |oli|
    oppLink = allLinks[oli]
    outgoingSE = hgraph.getSpatialEdge(baseLink.srcID, oppLink.srcID)
    incomingSE = hgraph.getSpatialEdge(oppLink.srcID, baseLink.srcID)
    
    # Skip if the links are the same or if both links have same transmitter
    next if(oppLink == baseLink)
    next if(oppLink.srcID==baseLink.srcID)
    
    if(hgraph.getSpatialEdge(oppLink.srcID,baseLink.dstID))  # If receiver in range of opposing...
      outgoingCoord=false; incomingCoord=false
      outgoingCoord=true if((not outgoingSE.nil?) and outgoingSE.backoff==1)
      incomingCoord=true if((not incomingSE.nil?) and incomingSE.backoff==1)
      break if(outgoingCoord && incomingCoord)
      symByRadio[radioIndex].push(oli+1) if(outgoingCoord==false && incomingCoord==false)
      asym1ByRadio[radioIndex].push(oli+1) if(incomingCoord==true)
      asym2ByRadio[radioIndex].push(oli+1) if(outgoingCoord==true)
    end
  end
end

