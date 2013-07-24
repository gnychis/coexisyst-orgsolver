#!/usr/bin/ruby

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
