#!/usr/bin/ruby

Network = Struct.new(:networkID, :protocol, :activeFreq, :bandwidth, :dAirtime, :airtime, :goodAirtime, :lossRate, :radios, :links, :rfs_max, :networkTypeID) do
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    to_map.to_json(*a)
  end
end

Radio = Struct.new(:radioID, :protocol, :radioName, :networkID, :frequencies, :networkTypeID, :activeFreq, :lossRate, :goodAirtime, :airtime, :dAirtime, :residual, :ats, :rfs_max) do
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    to_map.to_json(*a)
  end
end

SpatialEdge = Struct.new(:from, :to, :rssi, :backoff, :digitally) do
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    to_map.to_json(*a)
  end
end


LinkEdge = Struct.new(:srcID, :dstID, :freq, :bandwidth, :pps, :ppsMax, :txLen, :protocol) do

  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    to_map.to_json(*a)
  end

  def airtime
    return (pps*(txLen/1000000.0)).round(3)
  end

  def dAirtime
    return (ppsMax*(txLen/1000000.0)).round(3)
  end
end

Hyperedge = Struct.new(:id, :radios) do
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    to_map.to_json(*a)
  end
end

class Hypergraph
  @@spatialEdges=Array.new
  @@radios=Array.new
  @@hyperEdges=Array.new     
  @@linkEdges=Array.new

  def to_json
    {'hyperEdges' => @@hyperEdges,'linkEdges' => @@linkEdges, 'spatialEdges' => @@spatialEdges, 'radios' => @@radios}.to_json
  end

  def getSpatialEdges()
    return @@spatialEdges
  end

  def getLinkEdges()
    return @@linkEdges
  end

  def getRadios()
    return @@radios
  end

  def getRadioByIndex(idx)
    return @@radios[idx]
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
    return if(edge.from==edge.to)
    @@spatialEdges.push(edge) if(getSpatialEdge(edge.from, edge.to).nil?)
  end

  def deleteSpatialEdge(edge)
    @@spatialEdges.delete(edge)
  end

  def getSpatialEdge(from, to)
    @@spatialEdges.each {|l| return l if(l.from==from and l.to==to)}
    return nil
  end

  def newLinkEdge(link)
    return if(link.srcID==link.dstID)
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

    if(getHyperedge(radio.networkID).nil?)
      createHyperedge(radio.networkID)
      addToHyperedge(radio.networkID, radio)
    else
      addToHyperedge(radio.networkID, radio)
    end
  end

  def getNetworks()
    links=getLinkEdges()
    se=getSpatialEdges()
    radios=getRadios()

    # Next, go through and create all of the networks
    networks=Hash.new
    radios.each do |r|
      if(not networks.has_key?(r.networkID))
        networks[r.networkID] = Network.new(r.networkID, r.protocol, r.activeFreq, nil, 0, 0, 0, 0, Array.new, Array.new,0.0,r.networkTypeID)
      end
      network = networks[r.networkID]
      
      network.radios.push(r)
      getLinkEdgesByTX(r.radioID).each {|l| network.links.push(l)}
      
      lEdges = getLinkEdgesByTX(r.radioID)
      next if(lEdges.nil? or lEdges.length==0)

      network.bandwidth = lEdges[0].bandwidth

      network.dAirtime+=r.dAirtime        if(not r.dAirtime.nil?)
      network.airtime+=r.airtime          if(not r.airtime.nil?)
      network.lossRate+=r.lossRate        if(not r.lossRate.nil?)
      network.goodAirtime+=r.goodAirtime  if(not r.goodAirtime.nil?)
      network.rfs_max=r.rfs_max           if((not r.rfs_max.nil?) and (r.rfs_max>network.rfs_max))
      network.rfs_max=r.rfs_max           if((not r.rfs_max.nil?) and (r.rfs_max>network.rfs_max))

    end
    return networks
  end

  def newNetwork(type, frequencies, airtime_to, airtime_from, rssi_backoff_to, rssi_backoff_from)
    total_radios=getRadios.length
    radios=Array.new
    networks=getNetworks()
    nets_of_type=0
    networks.each {|net| nets_of_type+=1 if(net[1].protocol==type)}
    (total_radios+1..total_radios+2).each { |rid| 
      r = Radio.new("#{rid}", type, "radio#{rid}", "network#{networks.length+1}", frequencies, nets_of_type+1)
      newRadio(r) 
    }

    len=2750 if(type=="802.11agn")
    len=2750 if(type=="802.11n-40MHz")
    len=3000 if(type=="802.11n")
    len=400 if(type=="Analog")
    len=1750 if(type=="ZigBee")

    bw=40 if(type=="802.11n-40MHz")
    bw=20 if(type=="802.11n")
    bw=20 if(type=="802.11agn")
    bw=2  if(type=="Analog")
    bw=5  if(type=="ZigBee")
    
    pps_to=((1000000*airtime_to)/len).to_i       if(not airtime_to.nil?)
    pps_from=((1000000*airtime_from)/len).to_i   if(not airtime_from.nil?)
      
    newLinkEdge( LinkEdge.new( "#{total_radios+1}","#{total_radios+2}", 2437, bw, pps_to, pps_to, len, type) ) if(not pps_to.nil?)
    newLinkEdge( LinkEdge.new( "#{total_radios+2}","#{total_radios+1}", 2437, bw, pps_from, pps_from, len, type) ) if(not pps_from.nil?)
      
    newSpatialEdge( SpatialEdge.new("#{total_radios+1}","#{total_radios+2}",rssi_backoff_to[0],rssi_backoff_to[1])) if(not rssi_backoff_to.nil?)
    newSpatialEdge( SpatialEdge.new("#{total_radios+2}","#{total_radios+1}",rssi_backoff_from[0],rssi_backoff_from[1])) if(not rssi_backoff_from.nil?)
  end

  def initialize()
    @@spatialEdges=Array.new
    @@radios=Array.new
    @@hyperEdges=Array.new     
    @@linkEdges=Array.new
  end

  def loadData(data_dir)

    #################################################################################################
    # Read in the map.txt file in to a data structure
    #######
    File.readlines("#{data_dir}/map.txt").each do |line|

      # Read in the map data
      ls = line.split
      f = line[line.index("{")+1,line.index("}")-line.index("{")-1].split(",").map{|i| i.to_i}

      r = Radio.new(ls[0],   # the radioID
                    ls[1],   # the protocol
                    ls[2],   # the radio name
                    ls[3],   # the network name
                    f)       # the set of frequencies


      # Store the radio if we do not yet have it in our graph
      newRadio(r) if(getRadio(r.radioID).nil?)
      
      ## FIXME: try to check for duplicate radio IDs and names
    end


    #################################################################################################
    # Now, go through each of the data files and read the link data associated to the node
    #######
    Dir.glob("#{data_dir}/capture*.dat").each do |capfile|
      
      baselineRadio=nil           # Store the baseline radio for the capture file
      baselineRadioInfo=nil       # This should resolve to the map info

      File.readlines(capfile).each do |line|

        # Read in the baselineRadio if this is the very first line
        if(baselineRadio.nil?)
          baselineRadioID = line.chomp.strip       
          baselineRadio = getRadioByName(baselineRadioID)   # Try to get it by name first
          baselineRadio = getRadio(baselineRadioID) if(baselineRadio.nil?)  # Then, try to get it by ID
          next
        end
        
        ls = line.split  # Go ahead and split the line

        # Create a unique linkID for this link if it does not yet exist
        lSrc = ls[0]
        lDst = ls[1]
        if(getLinkEdge(lSrc, lDst).nil?)
          newLinkEdge( LinkEdge.new( 
                              ls[0],        # The source ID for the link
                              ls[1],        # The destination ID for the link
                              ls[3].to_i,   # The frequency used
                              ls[5].to_i,   # The bandwidth used on the link
                              ls[6].to_f,   # The PPS observed on the link from the source to destination
                              ls[6].to_f,   # The max/peak PPS observed on the link from the source to destination
                              ls[7].to_i,   # The average transmission length in microseconds
                              ls[2]))       # The protocol in use on the link
        end
        
        # Create radio instances for both the source and destination if they do not exist
        [lSrc,lDst].each do |radioID|
          if(getRadio(radioID).nil?)
            newRadio( Radio.new(
                              radioID,
                              ls[2],
                              nil,
                              nil,
                              [ls[3].to_i]))
          end
        end

        # Now create a spatial edge from the link source to the baseline radio
        if(getSpatialEdge(lSrc, baselineRadio.radioID).nil? and lSrc!=baselineRadio.radioID)
          newSpatialEdge( SpatialEdge.new(
                                 lSrc,                      # From
                                 baselineRadio.radioID,     # To
                                 ls[4].to_i,                # RSSI
                                 ls[8].to_i                 # Backoff
                                 ))
        end
      end
    end
  end

  def init_json(json)
    json["spatialEdges"].each {|se| @@spatialEdges.push(SpatialEdge.new(*se.values)) }
    json["radios"].each {|ra| @@radios.push(Radio.new(*ra.values)) }
    json["hyperEdges"].each {|he| @@hyperEdges.push(Hyperedge.new(*he.values)) }
    json["linkEdges"].each {|le| @@linkEdges.push(LinkEdge.new(*le.values)) }    
  end

end
