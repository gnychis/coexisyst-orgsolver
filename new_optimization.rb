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
LinkEdge = Struct.new(:srcID, :dstID, :freq, :bandwidth, :airtime, :dAirtime, :txLen, :protocol)
Hyperedge = Struct.new(:id, :radios)

class Optimization
  attr_accessor :data

  def initialize
    @data = Hash.new
  end

  def translateVar(var,comment)
    s=String.new
    s += "  # #{comment}\n" if(not comment.nil?)

    if(data[var].kind_of?(Array) and (not data[var][0].kind_of?(Array)))
      s += "  set #{var}  := { #{data[var].inspect[1..-2]} };"
    end

    if(data[var].kind_of?(Array) and data[var][0].kind_of?(Array))

      s += "  set #{var}  := \n"

      data[var].each_index do |i|
        s += "    <#{i+1}> { #{data[var][i].inspect[1..-2]} }"   # Print out the header
        s += ",\n" if(i <  data[var].size-1)
        s += ";" if(i == data[var].size-1)
      end

    end

    s += "\n\n"
    return s
  end
end
opt = Optimization.new

class Hypergraph
  @@spatialEdges=Array.new
  @@radios=Array.new
  @@hyperEdges=Array.new     
  @@linkEdges=Array.new

  def getSpatialEdges()
    return @@spatialEdges
  end

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

  def getSpatialEdgesTo(radioID)
    s=Array.new
    @@spatialEdges.each do |se|
      s.push(se) if(se.to==radioID)
    end
    return s
  end

  def getSpatialEdgesToIndices(edges)
    x = Array.new
    edges.each do |l|
      @@spatialEdges.each_index {|i| x.push(i) if(@@spatialEdges[i]==l)}
    end
    return x
  end

  def getLinkEdgesToIndices(links)
    x = Array.new
    links.each do |l|
      @@linkEdges.each_index {|i| x.push(i) if(@@linkEdges[i]==l)}
    end
    return x
  end

  def getLinkEdgesByTX(srcID)
    x = Array.new
    @@linkEdges.each {|l| x.push(l) if(l.srcID==srcID)}
    return x
  end
  
  def getLinkEdgesByID(id)
    x = Array.new
    @@linkEdges.each {|l| x.push(l) if(l.srcID==id or l.dstID==id)}
    return x
  end

  def getLinkEdgeByIndex(idx)
    return @@linkEdges[idx]
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

  def getLinkEdgeIndex(link)
    @@linkEdges.each_index {|i| return i if(@@linkEdges[i]==link)}
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
                          ls[6].to_f*1.3,   # FIXME: desired airtime is just the current airtime
                          ls[7].to_i,   # The average transmission length in microseconds
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

opt.data["R"]=Array.new
hgraph.getRadios.each_index {|r| opt.data["R"].push(r+1)}
dataOF.puts opt.translateVar("R", "The set of radios in the optimization")

opt.data["RadioAttr"]=["numLinks", "dAirtime", "bandwidth"]
dataOF.puts opt.translateVar("RadioAttr", nil)

opt.data["FR[R]"]=Array.new
hgraph.getRadios.each {|r| opt.data["FR[R]"].push(r.frequencies)}
dataOF.puts opt.translateVar("FR[R]", "The frequencies available for each radio")

opt.data["RL[R]"]=Array.new
hgraph.getRadios.each {|r| opt.data["RL[R]"].push( hgraph.getLinkEdgesToIndices(hgraph.getLinkEdgesByTX(r.radioID)).map {|i| i+1} ) }
dataOF.puts opt.translateVar("RL[R]", "For each radio, the links that belong to the radio")

dataOF.puts "\n  # For each radio, the attributes"
dataOF.puts "  param RDATA[R * RadioAttr] :="
dataOF.puts "      | \"numLinks\", \"dAirtime\", \"bandwidth\" |"
hgraph.getRadios.each_index do |r|
  links=Array.new
  hgraph.getLinkEdgesByTX(hgraph.getRadios[r].radioID).each {|le| links.push(le) }
  da = 0; links.each {|l| da+=l.dAirtime}
  anylink=Array.new
  hgraph.getLinkEdgesByID(hgraph.getRadios[r].radioID).each {|le| anylink.push(le)}
  dataOF.print "     |#{r+1}| \t#{links.size}, \t#{da}, \t\t#{anylink[0].bandwidth} |"   # Print out the header
  dataOF.print "\n" if(r<hgraph.getRadios.size-1)
  dataOF.puts ";" if(r==hgraph.getRadios.size-1)
end
dataOF.puts "\n"

opt.data["S[R]"]=Array.new
hgraph.getRadios.each {|r| opt.data["S[R]"].push( hgraph.getSpatialEdgesTo(r.radioID).map {|se| hgraph.getRadioIndex(se.from)+1} )}
dataOF.puts opt.translateVar("S[R]", "For each radio, the set of radios that are within spatial range (i.e., r senses them)")

opt.data["C[R]"]=Array.new
hgraph.getRadios.each {|r| 
  ses=Array.new
  hgraph.getSpatialEdgesTo(r.radioID).each {|se| ses.push(se) if(se.backoff==1)}
  opt.data["C[R]"].push( ses.map {|se| hgraph.getRadioIndex(se.from)+1} )
  }
dataOF.puts opt.translateVar("C[R]", "For each radio, the set of radios that are within spatial range (i.e., r senses them) and they coordinate")

opt.data["ROL[R]"]=Array.new
hgraph.getRadios.each {|r| opt.data["ROL[R]"].push([hgraph.getLinkEdgeIndex(hgraph.getLinkEdgesByTX(r.radioID)[0])+1]) }
dataOF.puts opt.translateVar("ROL[R]", "For each radio, give one link that the radio participates in, TX or RX")

networks=Hash.new
hgraph.getRadios.each {|r| 
  networks[r.networkID]=Array.new if(not networks.has_key?(r.networkID))
  networks[r.networkID].push( hgraph.getRadioIndex(r.radioID)+1 )
}
networks.delete(nil)
opt.data["H"]=(1..networks.size).to_a
opt.data["HE[H]"]=networks.values
dataOF.puts opt.translateVar("H", "The set of hyperedges")
dataOF.puts opt.translateVar("HE[H]", "For each hyperedge, the set of networks that belong to it")

#################################################################################################
## Now we go through and prepare the links and transfer them over to the optimization.  We first
## need to condense the links so that there is only a single "link" for every transmitter and
## receiver.
dataOF.puts "\n\n############################################################"
dataOF.puts "## Information related to links"
dataOF.puts ""

opt.data["L"]=Array.new
hgraph.getLinkEdges.each_index {|l| opt.data["L"].push(l+1)}
dataOF.puts opt.translateVar("L", "The set of links in the optimization")

opt.data["LinkAttr"]=LinkEdge.members[0..LinkEdge.members.size-2]
dataOF.puts opt.translateVar("LinkAttr", "The set of attributes for each link")

opt.data["FL[L]"]=Array.new
hgraph.getLinkEdges.each {|le| opt.data["FL[L]"].push(hgraph.getRadio(le.srcID).frequencies)}
dataOF.puts opt.translateVar("FL[L]", "The frequencies available for each link")

dataOF.puts "  # The data for each link"
dataOF.puts "  param LDATA[L * LinkAttr] :="
dataOF.print "      |#{opt.data["LinkAttr"].inspect[1..-2]} |"
hgraph.getLinkEdges.each_index do |l|
  le = hgraph.getLinkEdges[l]
  dataOF.print "\n   |#{l+1}|\t    #{hgraph.getRadioIndex(le.srcID)+1},\t      #{hgraph.getRadioIndex(le.dstID)+1},  #{le.freq},\t\t  #{le.bandwidth},\t  #{le.airtime}, \t      #{le.dAirtime},   #{le.txLen}  |"
end
dataOF.print ";\n"

#################################################################################################
## Go through and check against sets of conflicts between a pair of links.
## The interaction that we care about is as follows:
##    1.  That the receiver is within spatial range of the opposing transmitter.  If it's not,
##        there is no possible conflict.
##    2.  The interaction between the two transmitters.  Do they defer to each other or not?
##
## For each link, go through and mark each of the other links as coordinating or conflicting, 
## and whether the conflict is symmetric or asymmetric
dataOF.puts "\n\n############################################################"
dataOF.puts "## Information related to coordination between links"
dataOF.puts ""

allLinks = hgraph.getLinkEdges
symByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| symByRadio.push(Array.new)}
symByLink=Array.new;  (1..hgraph.getLinkEdges.size).each {|l| symByLink.push(Array.new)}
asym1ByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| asym1ByRadio.push(Array.new)}
asym1ByLink=Array.new; (1..hgraph.getLinkEdges.size).each {|l| asym1ByLink.push(Array.new)}
asym2ByRadio=Array.new; (1..hgraph.getRadios.size).each {|i| asym2ByRadio.push(Array.new)}
asym2ByLink=Array.new; (1..hgraph.getLinkEdges.size).each {|i|asym2ByLink.push(Array.new)}
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
      if(outgoingCoord==false && incomingCoord==false)
        symByRadio[radioIndex].push(oli+1) 
        symByLink[bli].push(oli+1)
      end

      if(incomingCoord==true)  # Baseline coordinates with opposing
        asym1ByRadio[radioIndex].push(oli+1)  
        asym1ByLink[bli].push(oli+1)
      end
      if(outgoingCoord==true)  # Opposing coordinates with baseline
        asym2ByRadio[radioIndex].push(oli+1)     
        asym2ByLink[bli].push(oli+1)
      end
    end
  end
end
symByRadio.each {|r| r.uniq!}; asym1ByRadio.each {|r| r.uniq!}; asym2ByRadio.each {|r| r.uniq!}
symByLink.each {|r| r.uniq!};  asym1ByLink.each {|r| r.uniq!}; asym2ByLink.each {|r| r.uniq!}


opt.data["U[L]"] = Array.new
opt.data["LU[L]"] = symByLink
opt.data["LUO[L]"] = asym1ByLink
opt.data["LUB[L]"] = asym2ByLink
opt.data["LU[L]"].each_index {|i| opt.data["U[L]"][i] = opt.data["LU[L]"][i] | opt.data["LUO[L]"][i] | opt.data["LUB[L]"][i]}
dataOF.puts opt.translateVar("U[L]", "For all links, all other links that will contribute to it in a negative scenario")
dataOF.puts opt.translateVar("LU[L]", "For all links, the set of links that the radio is in a completely blind situation")
dataOF.puts opt.translateVar("LUO[L]", "For all radios, the set of links that are asymmetric, where the opposing link does not coordinate")
dataOF.puts opt.translateVar("LUB[L]", "For all radios, the set of links that are asymmetric, where the baseline link does not coordinate")
