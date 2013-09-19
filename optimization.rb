#!/usr/bin/ruby
require 'hypergraph'

def getLossRate(baseEdge,opposingEdge)
  return 0 if(baseEdge.nil? or opposingEdge.nil?)
  return 0 if(baseEdge.rssi>=opposingEdge.rssi)
  return 1
end

Conflict = Struct.new(:from, :to, :type)
NetworkConflict = Struct.new(:from, :to)

class Optimization
  attr_accessor :data
  attr_accessor :hgraph
  attr_accessor :solve_time
  attr_accessor :subgraph_time
  attr_accessor :init_time
  attr_accessor :conflict_graph

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
    @conflict_graph = Array.new
    @hgraph=hgraph
    @solve_time = 0
    @subgraph_time = 0
    @init_time = 0
    dataOF = File.new("data.zpl", "w")

    init_start=Time.now

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
      hgraph.getRadios[r].dAirtime=da
      anylink=Array.new
      hgraph.getLinkEdgesByID(hgraph.getRadios[r].radioID).each {|le| anylink.push(le)}
      dataOF.print "     |#{r+1}| \t#{links.size}, \t#{da}, \t\t#{anylink[0].bandwidth} |"   # Print out the header
      dataOF.print "\n" if(r<hgraph.getRadios.size-1)
      dataOF.puts ";" if(r==hgraph.getRadios.size-1)
    end
    dataOF.puts "\n"
    
    data["C[R]"]=Array.new
    hgraph.getRadios.each {|r| 
      ses=Array.new
      hgraph.getSpatialEdgesTo(r.radioID).each {|se| 
        se2 = hgraph.getSpatialEdge(r.radioID,se.from)
        if(not se2.nil?)
          ses.push(se) if(se.backoff==1 and se2.backoff==1)
        end
      }
      data["C[R]"].push( ses.map {|se| hgraph.getRadioIndex(se.from)+1} )
      }
    dataOF.puts translateVar("C[R]", "For each radio, the set of radios that coordinate (bi-directionaly)")
    
    data["AS[R]"]=Array.new
    hgraph.getRadios.each {|r| 
      ses=Array.new
      hgraph.getSpatialEdgesTo(r.radioID).each {|se| 
        se2 = hgraph.getSpatialEdge(r.radioID,se.from)
        if(se2.nil? or se2.backoff==0)
          ses.push(se) if(se.backoff==1)
        end
      }
      data["AS[R]"].push( ses.map {|se| hgraph.getRadioIndex(se.from)+1} )
      }
    dataOF.puts translateVar("AS[R]", "Asymmetric sensing of other radios (i.e., you sense them, but they don't sense you)")

    data["S[R]"]=Array.new
    hgraph.getRadios.each {|r| 
      ses=Array.new
      hgraph.getSpatialEdgesTo(r.radioID).each {|se| ses.push(se) if(se.backoff==1)}
      data["S[R]"].push( ses.map {|se| hgraph.getRadioIndex(se.from)+1} )
      }
    dataOF.puts translateVar("S[R]", "For each radio, the set of radios that are within spatial range (i.e., r senses them) and it coordinates with them (uni-directional)")

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

    data["LinkAttr"]=["srcID", "dstID", "freq", "bandwidth", "airtime", "dAirtime", "txLen"]
    dataOF.puts translateVar("LinkAttr", "The set of attributes for each link")

    data["FL[L]"]=Array.new
    hgraph.getLinkEdges.each {|le| data["FL[L]"].push(hgraph.getRadio(le.srcID).frequencies)}
    dataOF.puts translateVar("FL[L]", "The frequencies available for each link")

    dataOF.puts "  # The data for each link"
    dataOF.puts "  param LDATA[L * LinkAttr] :="
    #dataOF.print "      | \"srcID\", \"dstID\", \"freq\", \"bandwidth\", \"airtime\", \"dAirtime\", \"txLen\"  |"
    dataOF.print "      |#{data["LinkAttr"].inspect[1..-2]} |"
    hgraph.getLinkEdges.each_index do |l|
      le = hgraph.getLinkEdges[l]
      dataOF.print "\n   |#{l+1}|\t    #{hgraph.getRadioIndex(le.srcID)+1},\t      #{hgraph.getRadioIndex(le.dstID)+1},  #{le.freq},\t\t  #{le.bandwidth},\t  #{le.airtime}, \t      #{le.dAirtime},   #{le.txLen / 1000000.0}  |"
    end
    dataOF.print ";\n"

    dataOF.puts "\n"
    data["LR"]=Hash.new
    hgraph.getLinkEdges.each_index do |lei|
      data["LR"]["#{lei+1},#{hgraph.getRadioIndex(hgraph.getLinkEdges[lei].srcID)+1}"]=nil
    end
    dataOF.puts translateVar("LR", "For each link, a radio that it belongs to")

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

    subgraph_start=Time.now
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
            @conflict_graph.push(Conflict.new(oppLink, baseLink, nil))
          end

          if(incomingCoord==true)  # Baseline coordinates with opposing
            asym1ByRadio[radioIndex].push(oli+1)  
            asym1ByLink[bli].push(oli+1)
            @conflict_graph.push(Conflict.new(oppLink, baseLink, nil))
          end
          if(outgoingCoord==true)  # Opposing coordinates with baseline
            asym2ByRadio[radioIndex].push(oli+1)     
            asym2ByLink[bli].push(oli+1)
            @conflict_graph.push(Conflict.new(oppLink, baseLink, nil))
          end
        end
      end
    end
    symByRadio.each {|r| r.uniq!}; asym1ByRadio.each {|r| r.uniq!}; asym2ByRadio.each {|r| r.uniq!}
    symByLink.each {|r| r.uniq!};  asym1ByLink.each {|r| r.uniq!}; asym2ByLink.each {|r| r.uniq!}

    @subgraph_time = Time.now - subgraph_start


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
    @init_time = Time.now - init_start
  end
  
  def run_debug()
    radios=Array.new
    all=`scip -f spectrum_optimization.zpl`
    puts "\n-------------------------"
    puts all.split("\n")[45..-157]
    puts "\n"
    fString=`scip -f spectrum_optimization.zpl | grep -E "af\#|no solution"`.split("\n").map {|i| i.chomp}
    raise RuntimeError, '!!!! NO SOLUTION AVAILABLE !!!!' if(fString.include?("no solution available"))
    fString.each { |line|
      spl=line.split[0].split("#")
      rid=spl[1].to_i
      freq=spl[2].to_i
      val=line.split[1].to_f
      radio = @hgraph.getRadioByIndex(rid-1)
      if(line.split[1].to_f>0.1)
        radio.activeFreq = freq
        radios.push( radio ) 
      end
    }
    return radios
  end

  def run()
    solve_start = Time.now
    radios = hgraph.getRadios 
    fString=`scip -f spectrum_optimization.zpl | grep -E "RadioAirtime\|GoodAirtime\|RadioLossRate\|af\#|no solution"`.split("\n").map {|i| i.chomp}
    raise RuntimeError, '!!!! NO SOLUTION AVAILABLE !!!!' if(fString.include?("no solution available"))
    fString.each { |line|
      spl=line.split[0].split("#")
      rid=spl[1].to_i

      if(spl[0]=="af")
        freq=spl[2].to_i
        val=line.split[1].to_f
        radios[rid-1].activeFreq = freq if(line.split[1].to_f>0.1)
      end

      if(spl[0]=="RadioLossRate")
        radios[rid-1].lossRate = line.split[1].to_f
      end

      if(spl[0]=="GoodAirtime")
        radios[rid-1].goodAirtime = line.split[1].to_f
      end
      
      if(spl[0]=="RadioAirtime")
        radios[rid-1].airtime = line.split[1].to_f
      end
    }

    radios.each {|r|
      r.lossRate=0.0 if(r.lossRate.nil?)
      r.goodAirtime=0.0 if(r.goodAirtime.nil?)
      r.airtime=0.0 if(r.airtime.nil?)
    }
    @solve_time = Time.now - solve_start
    return radios
  end
  
  def getSpectrumPlot(draw_conflicts)

    networks = hgraph.getNetworks

    # Now sort the networks by their bandwidth
    sorted_nets = networks.sort_by {|key,vals| networks[key].bandwidth}
    sorted_nets.reverse!   # Largest first
    
    # Get all of the unique bandwidths
    bandwidths = Array.new
    networks.each_value {|n| bandwidths.push(n.bandwidth) if(not bandwidths.include?(n.bandwidth))}
    
    # Start to setup the data
    data=Hash.new
    data["x"]=Array.new
    (0..2485-2400).each {|v| data["x"].push(2400+v)}
    additional=""

    airtime_bins=Hash.new
    airtime_bins["802.11agn"]=Hash.new
    airtime_bins["ZigBee"]=Hash.new
    airtime_bins["Analog"]=Hash.new
    airtime_bins["802.11agn"].default=0
    airtime_bins["ZigBee"].default=0
    airtime_bins["Analog"].default=0

    objects=1
    net_locations=Hash.new
    # For each bandwidth, get the networks that belong to it and sort by airtime
    bandwidths.sort.reverse.each do |bw|
      curr_networks=Array.new
      networks.each_value {|n| curr_networks.push(n) if(n.bandwidth==bw)}
      curr_networks.sort_by {|n| n.dAirtime}
      curr_networks.reverse!   # Most airtime first

      curr_networks.each do |net|

        color="#1E90FF" if(net.protocol=="802.11agn")
        color="red" if(net.protocol=="Analog")
        color="green" if(net.protocol=="ZigBee")

        start_freq = (net.activeFreq - (net.bandwidth / 2.0)).to_i
        end_freq = (net.activeFreq + (net.bandwidth / 2.0)).to_i

        max_airtime=0.0
        (start_freq..end_freq).each {|f| max_airtime=airtime_bins[net.protocol][f] if(airtime_bins[net.protocol][f]>max_airtime) }
        (start_freq..end_freq).each {|f| airtime_bins[net.protocol][f]+=net.dAirtime }

        prefix="W" if(net.protocol=="802.11agn")
        prefix="A" if(net.protocol=="Analog")
        prefix="Z" if(net.protocol=="ZigBee")

        location=[net.activeFreq-1,max_airtime+(net.dAirtime/2.0)]
        additional+="set object #{objects} rect from #{start_freq},#{max_airtime} to #{end_freq},#{max_airtime+net.dAirtime} fc rgb \"#{color}\" lw 3\n"
        additional+="set label \"#{prefix}_{#{net.networkID.gsub("network","")}}\" at #{location[0]},#{location[1]} font \"Times-Roman,14\"\n"
        net_locations[net.networkID]=location
        objects+=1
      end
    end

    net_conflicts=Array.new
    @conflict_graph.each do |c|
      puts c.from.srcID
      net_from=nil; net_to=nil
      networks.each_value  do |n|
        n.radios.each do |r|
          net_from=n if(r.radioID==c.from.srcID)
          net_to=n if(r.radioID==c.to.srcID)
        end
      end
      net_conflicts.push(NetworkConflict.new(net_from, net_to))
    end

    net_conflicts.each {|nc| 
      loc_from=net_locations[nc.from.networkID]
      loc_to=net_locations[nc.to.networkID]
      add_from=0
      add_to=0
      if(loc_from[0] < loc_to[0])
        add_from = 2
        add_to = -1.5
      else
        add_from = -1.5
        add_to = 2.5
      end
      additional+="set arrow from #{loc_from[0]+add_from},#{loc_from[1]} to #{loc_to[0]+add_to},#{loc_to[1]} lc rgb \'red\' lw 4\n"
    }
    
    additional+="set object #{objects} rect from 2463,1.4 to 2469,1.5 fc rgb \"#1E90FF\" lw 2\n"; objects+=1
    additional+="set object #{objects} rect from 2463,1.25 to 2469,1.35 fc rgb \"green\" lw 2\n"; objects+=1
    additional+="set object #{objects} rect from 2463,1.10 to 2469,1.20 fc rgb \"red\" lw 2\n"; objects+=1
    additional+="set label \"802.11\" at 2470.5,1.45\n"
    additional+="set label \"ZigBee\" at 2470.5,1.30\n"
    additional+="set label \"Analog\" at 2470.5,1.15\n"
    additional+="set ylabel \"Airtime\" offset 1,-1.7\n"
    ytics="(\"0\" 0, \"0.2\" 0.2, \"0.4\" 0.4, \"0.6\" 0.6, \"0.8\" 0.8, \"1\" 1)"
    options=Hash["xrange",[data["x"][0],data["x"][-1]], "additional",additional, "style","lines", "ytics",ytics, "rotate",true, "yrange",[0,1.55], "lt",[1,1,1], "lc",[3,1,2], "grid",true, "xlabel", "Spectrum (MHz)","nokey",true]
    return data,options
  end

end
