#!/usr/bin/ruby
require 'trollop'
require 'hgraph'

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

def getLossRate(baseEdge,opposingEdge)
  return 0 if(baseEdge.nil? or opposingEdge.nil?)
  return 0 if(baseEdge.rssi>=opposingEdge.rssi)
  return 1
end

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

    if(data[var].kind_of?(Hash))
      s += "  set #{var}  := "
      d=data[var].keys
      s+= "{ "
      d.each_index do |i|
        s += "<#{d[i]}>"
        s += ", " if(i <  d.size-1)
      end
      s+= " };"
    end

    s += "\n\n"
    return s
  end
end
opt = Optimization.new


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
dataOF.puts opt.translateVar("C[R]", "For each radio, the set of radios that are within spatial range (i.e., r senses them) and it coordinates with them (uni-directional)")

opt.data["ROL[R]"]=Array.new
hgraph.getRadios.each {|r| opt.data["ROL[R]"].push([hgraph.getLinkEdgeIndex(hgraph.getLinkEdgesByID(r.radioID)[0])+1]) }
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
  dataOF.print "\n   |#{l+1}|\t    #{hgraph.getRadioIndex(le.srcID)+1},\t      #{hgraph.getRadioIndex(le.dstID)+1},  #{le.freq},\t\t  #{le.bandwidth},\t  #{le.airtime}, \t      #{le.dAirtime},   #{le.txLen / 1000000.0}  |"
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

# Calculate the vulnerability windows
allLinks = hgraph.getLinkEdges
opt.data["VW[L]"]=Array.new
allLinks.each do |baseLink|
  a=Array.new
  allLinks.each do |oppLink|
    
    # If the two links are the same, they have no impact on each other
    if(baseLink==oppLink)
      a.push(0) 
      next
    end

    # Two links with the same transmitter cannot have any impact on each other
    if(baseLink.srcID == oppLink.srcID)
      a.push(0)
      next
    end

    outgoingSE = hgraph.getSpatialEdge(baseLink.srcID, oppLink.srcID)
    incomingSE = hgraph.getSpatialEdge(oppLink.srcID, baseLink.srcID)

    # The receiver is within range of the opposing link
    if(hgraph.getSpatialEdge(oppLink.srcID,baseLink.dstID))
      outgoingCoord=false; incomingCoord=false
      outgoingCoord=true if((not outgoingSE.nil?) and outgoingSE.backoff==1)
      incomingCoord=true if((not incomingSE.nil?) and incomingSE.backoff==1)
      
      # They coordinate so there is no impact
      if(outgoingCoord && incomingCoord)
        a.push(0)
        next
      end
      
      # Both do not coordinate, so the vulnerability window is both tx len
      if(outgoingCoord==false && incomingCoord==false)
        a.push(baseLink.txLen + oppLink.txLen)
        next
      end

      if(outgoingCoord==true && incomingCoord==false)
        a.push(oppLink.txLen)
        next
      end

      if(outgoingCoord==false && incomingCoord==true)
        a.push(baseLink.txLen)
        next
      end
      
    end
    
    a.push(0)
  end
  opt.data["VW[L]"].push(a)
end
opt.data["VW[L]"].each {|l| l.each_index {|i| l[i]/=1000000.0}}
#dataOF.puts opt.translateVar("VW[L]", "The vulnerability window between each pair of links")

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

opt.data["OL"] = Hash.new
opt.data["U[L]"].each_index { |bli|
  baseLink = hgraph.getLinkEdgeByIndex(bli)
  opt.data["U[L]"][bli].each { |oli|
    oli-=1
    oppLink = hgraph.getLinkEdgeByIndex(oli)

    # Get the spatial edge from the baseLink TX to RX
    baseEdge=hgraph.getSpatialEdge(baseLink.srcID,baseLink.dstID)
    opposingEdge=hgraph.getSpatialEdge(oppLink.srcID,baseLink.dstID)
    #puts "* BaseLink:  #{baseLink.inspect}"
    #puts "* OppsLink:  #{oppLink.inspect}"
    #puts "... #{baseEdge.inspect}"
    #puts "... #{opposingEdge.inspect}"
    opt.data["OL"]["#{bli+1},#{oli+1},#{getLossRate(baseEdge,opposingEdge)}"]=nil
  }
}

dataOF.puts opt.translateVar("U[L]", "For all links, all other links that will contribute to it in a negative scenario")
dataOF.puts opt.translateVar("LU[L]", "For all links, the set of links that the radio is in a completely blind situation")
dataOF.puts opt.translateVar("LUO[L]", "For all radios, the set of links that are asymmetric, where the opposing link does not coordinate")
dataOF.puts opt.translateVar("LUB[L]", "For all radios, the set of links that are asymmetric, where the baseline link does not coordinate")
dataOF.puts opt.translateVar("OL", "For all conflicting link pairs, the loss rate on the link")
