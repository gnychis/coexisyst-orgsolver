#!/usr/bin/ruby

Radio = Struct.new(:radioID, :protocol, :radioName, :networkID, :frequencies)
SpatialEdge = Struct.new(:from, :to, :rssi, :backoff)
LinkEdge = Struct.new(:srcID, :dstID, :freq, :bandwidth, :airtime, :dAirtime, :txLen, :protocol)
Hyperedge = Struct.new(:id, :radios)

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

  def initialize(data_dir)

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

      # Store the hyperedge if we don't yet have the network in our graph
      if(getHyperedge(r.networkID).nil?)
        createHyperedge(r.networkID)
        addToHyperedge(r.networkID, r)
      else
        addToHyperedge(r.networkID, r)
      end
      
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
                              ls[6].to_f,   # The airtime observed on the link from the source to destination
                              ls[6].to_f*1.3,   # FIXME: desired airtime is just the current airtime
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

end
