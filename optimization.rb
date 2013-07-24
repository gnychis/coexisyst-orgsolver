#!/usr/bin/ruby
require 'hypergraph'

def getLossRate(baseEdge,opposingEdge)
  return 0 if(baseEdge.nil? or opposingEdge.nil?)
  return 0 if(baseEdge.rssi>=opposingEdge.rssi)
  return 1
end

class Optimization
  attr_accessor :data
  attr_accessor :hgraph

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

  def initialize(hgraph)
    @data = Hash.new
    @hgraph=hgraph
    dataOF = File.new("data.zpl", "w")

    #################################################################################################
    ## Now, we need a unique numeric ID for every single transmitter.  This is strictly for the
    ## MIP optimization representation.  We need to keep track of these and we can have a lookup.
    dataOF.puts "############################################################"
    dataOF.puts "## Information related to radios"
    dataOF.puts ""

    data["R"]=Array.new
    hgraph.getRadios.each_index {|r| data["R"].push(r+1)}
    dataOF.puts translateVar("R", "The set of radios in the optimization")

    data["RadioAttr"]=["numLinks", "dAirtime", "bandwidth"]
    dataOF.puts translateVar("RadioAttr", nil)

    data["FR[R]"]=Array.new
    hgraph.getRadios.each {|r| data["FR[R]"].push(r.frequencies)}
    dataOF.puts translateVar("FR[R]", "The frequencies available for each radio")

    data["RL[R]"]=Array.new
    hgraph.getRadios.each {|r| data["RL[R]"].push( hgraph.getLinkEdgesToIndices(hgraph.getLinkEdgesByTX(r.radioID)).map {|i| i+1} ) }
    dataOF.puts translateVar("RL[R]", "For each radio, the links that belong to the radio")

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

    data["S[R]"]=Array.new
    hgraph.getRadios.each {|r| data["S[R]"].push( hgraph.getSpatialEdgesTo(r.radioID).map {|se| hgraph.getRadioIndex(se.from)+1} )}
    dataOF.puts translateVar("S[R]", "For each radio, the set of radios that are within spatial range (i.e., r senses them)")

    data["C[R]"]=Array.new
    hgraph.getRadios.each {|r| 
      ses=Array.new
      hgraph.getSpatialEdgesTo(r.radioID).each {|se| ses.push(se) if(se.backoff==1)}
      data["C[R]"].push( ses.map {|se| hgraph.getRadioIndex(se.from)+1} )
      }
    dataOF.puts translateVar("C[R]", "For each radio, the set of radios that are within spatial range (i.e., r senses them) and it coordinates with them (uni-directional)")

    data["ROL[R]"]=Array.new
    hgraph.getRadios.each {|r| data["ROL[R]"].push([hgraph.getLinkEdgeIndex(hgraph.getLinkEdgesByID(r.radioID)[0])+1]) }
    dataOF.puts translateVar("ROL[R]", "For each radio, give one link that the radio participates in, TX or RX")

    networks=Hash.new
    hgraph.getRadios.each {|r| 
      networks[r.networkID]=Array.new if(not networks.has_key?(r.networkID))
      networks[r.networkID].push( hgraph.getRadioIndex(r.radioID)+1 )
    }
    networks.delete(nil)
    data["H"]=(1..networks.size).to_a
    data["HE[H]"]=networks.values
    dataOF.puts translateVar("H", "The set of hyperedges")
    dataOF.puts translateVar("HE[H]", "For each hyperedge, the set of networks that belong to it")

    #################################################################################################
    ## Now we go through and prepare the links and transfer them over to the optimization.  We first
    ## need to condense the links so that there is only a single "link" for every transmitter and
    ## receiver.
    dataOF.puts "\n\n############################################################"
    dataOF.puts "## Information related to links"
    dataOF.puts ""

    data["L"]=Array.new
    hgraph.getLinkEdges.each_index {|l| data["L"].push(l+1)}
    dataOF.puts translateVar("L", "The set of links in the optimization")

    data["LinkAttr"]=LinkEdge.members[0..LinkEdge.members.size-2]
    dataOF.puts translateVar("LinkAttr", "The set of attributes for each link")

    data["FL[L]"]=Array.new
    hgraph.getLinkEdges.each {|le| data["FL[L]"].push(hgraph.getRadio(le.srcID).frequencies)}
    dataOF.puts translateVar("FL[L]", "The frequencies available for each link")

    dataOF.puts "  # The data for each link"
    dataOF.puts "  param LDATA[L * LinkAttr] :="
    dataOF.print "      |#{data["LinkAttr"].inspect[1..-2]} |"
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
    data["VW[L]"]=Array.new
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
      data["VW[L]"].push(a)
    end
    data["VW[L]"].each {|l| l.each_index {|i| l[i]/=1000000.0}}
    #dataOF.puts translateVar("VW[L]", "The vulnerability window between each pair of links")

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


    data["U[L]"] = Array.new
    data["LU[L]"] = symByLink
    data["LUO[L]"] = asym1ByLink
    data["LUB[L]"] = asym2ByLink
    data["LU[L]"].each_index {|i| data["U[L]"][i] = data["LU[L]"][i] | data["LUO[L]"][i] | data["LUB[L]"][i]}

    data["OL"] = Hash.new
    data["U[L]"].each_index { |bli|
      baseLink = hgraph.getLinkEdgeByIndex(bli)
      data["U[L]"][bli].each { |oli|
        oli-=1
        oppLink = hgraph.getLinkEdgeByIndex(oli)

        # Get the spatial edge from the baseLink TX to RX
        baseEdge=hgraph.getSpatialEdge(baseLink.srcID,baseLink.dstID)
        opposingEdge=hgraph.getSpatialEdge(oppLink.srcID,baseLink.dstID)
        #puts "* BaseLink:  #{baseLink.inspect}"
        #puts "* OppsLink:  #{oppLink.inspect}"
        #puts "... #{baseEdge.inspect}"
        #puts "... #{opposingEdge.inspect}"
        data["OL"]["#{bli+1},#{oli+1},#{getLossRate(baseEdge,opposingEdge)}"]=nil
      }
    }

    dataOF.puts translateVar("U[L]", "For all links, all other links that will contribute to it in a negative scenario")
    dataOF.puts translateVar("LU[L]", "For all links, the set of links that the radio is in a completely blind situation")
    dataOF.puts translateVar("LUO[L]", "For all radios, the set of links that are asymmetric, where the opposing link does not coordinate")
    dataOF.puts translateVar("LUB[L]", "For all radios, the set of links that are asymmetric, where the baseline link does not coordinate")
    dataOF.puts translateVar("OL", "For all conflicting link pairs, the loss rate on the link")
    dataOF.close
  end

  def run()
    radios=Array.new
    fString=`scip -f spectrum_optimization.zpl | grep "af\#"`.split("\n").map 
    fString.each { |line|
      spl=line.split[0].split("#")
      rid=spl[1].to_i
      freq=spl[2].to_i
      radios.push( [@hgraph.getRadioByIndex(rid-1), freq])
    }
    return radios
  end
end
