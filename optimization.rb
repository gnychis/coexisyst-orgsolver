#!/usr/bin/ruby
require './hypergraph'
class Array; def sum; inject( nil ) { |sum,x| sum ? sum+x : x }; end; end
class Array; def mean; sum / size; end; end
class Array; def same_values?; self.uniq.length == 1; end; end

module Objective
  PROD_PROP_AIRTIME = "obj_prodPropAirtime"
  SUM_AIRTIME = "obj_sumAirtime"
  PROP_AIRTIME = "obj_propAirtime"
  PROD_JAIN_FAIRNESS = "obj_jainFairness"
  FCFS = "obj_FCFS"
  LARGEST_FIRST = "obj_LF"
end

def getLossRate(baseEdge,opposingEdge)
  return 0 if(baseEdge.nil? or opposingEdge.nil?)
  return 0 if(baseEdge.rssi>=opposingEdge.rssi)
  return 1
end

Conflict = Struct.new(:from, :to, :type)
NetworkConflict = Struct.new(:from, :to)

class Optimization
  attr_accessor :rand_dir
  attr_accessor :data
  attr_accessor :hgraph
  attr_accessor :solve_time
  attr_accessor :subgraph_time
  attr_accessor :init_time
  attr_accessor :conflict_graph

  def getRandDir()
    return @rand_dir
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

  def initialize(hgraph)
    @data = Hash.new
    @conflict_graph = Array.new
    @hgraph=hgraph
    @solve_time = 0
    @subgraph_time = 0
    @init_time = 0
    @rand_dir="/tmp/#{rand(10000)}"
    `mkdir -p #{@rand_dir}`
    dataOF = File.new("#{@rand_dir}/data.zpl", "w")

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

    # Set the digital flag for 802.11n, forced
    hgraph.getRadios.each do |r1|
      hgraph.getRadios.each do |r2|
        next if(r1==r2)
        se_toBase = hgraph.getSpatialEdge(r2.radioID, r1.radioID)
        se_toBase.digitally = true if(!se_toBase.nil? and r2.protocol.gsub("-40MHz","")=="802.11n" and r1.protocol.gsub("-40MHz","")=="802.11n")

        se_toOpp = hgraph.getSpatialEdge(r1.radioID, r2.radioID)
        se_toOpp.digitally = true if(!se_toOpp.nil? and r2.protocol.gsub("-40MHz","")=="802.11n" and r1.protocol.gsub("-40MHz","")=="802.11n")
      end
    end

    data["DC[R]"]=Array.new
    hgraph.getRadios.each {|r| 
      ses=Array.new
      hgraph.getSpatialEdgesTo(r.radioID).each {|se| 
        se2 = hgraph.getSpatialEdge(r.radioID,se.from)
        if(not se2.nil?)
          ses.push(se) if(se.backoff==1 and se2.backoff==1 and se.digitally==true)
        end
      }
      data["DC[R]"].push( ses.map {|se| hgraph.getRadioIndex(se.from)+1} )
      }
    dataOF.puts translateVar("DC[R]", "For each radio, the set of radios that it digitally coordinates with (must be bi-directional)")
    
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
    digitalU=Array.new; (1..hgraph.getLinkEdges.size).each {|i|digitalU.push(Array.new)}
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
          outgoingCoord=true if((not outgoingSE.nil?) and outgoingSE.backoff==1 and !outgoingSE.digitally)
          incomingCoord=true if((not incomingSE.nil?) and incomingSE.backoff==1 and !incomingSE.digitally)
          break if(outgoingCoord && incomingCoord)
          if(outgoingCoord==false && incomingCoord==false)
            symByRadio[radioIndex].push(oli+1) 
            symByLink[bli].push(oli+1)
            digitalU[bli].push(oli+1) if((!outgoingSE.nil? && outgoingSE.digitally) || (!incomingSE.nil? && incomingSE.digitally))
            @conflict_graph.push(Conflict.new(oppLink, baseLink, nil))
          end

          if(incomingCoord==true)  # Baseline coordinates with opposing
            asym1ByRadio[radioIndex].push(oli+1)  
            asym1ByLink[bli].push(oli+1)
            digitalU[bli].push(oli+1) if((!outgoingSE.nil? && outgoingSE.digitally) || (!incomingSE.nil? && incomingSE.digitally))
            @conflict_graph.push(Conflict.new(oppLink, baseLink, nil))
          end
          if(outgoingCoord==true)  # Opposing coordinates with baseline
            asym2ByRadio[radioIndex].push(oli+1)     
            asym2ByLink[bli].push(oli+1)
            digitalU[bli].push(oli+1) if((!outgoingSE.nil? && outgoingSE.digitally) || (!incomingSE.nil? && incomingSE.digitally))
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
    data["DU[L]"] = digitalU
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

    dataOF.puts translateVar("DU[L]", "For all links, all other links that are digitally uncoordinated")
    dataOF.puts translateVar("U[L]", "For all links, all other links that will contribute to it in a negative scenario")
    dataOF.puts translateVar("LU[L]", "For all links, the set of links that the radio is in a completely blind situation")
    dataOF.puts translateVar("LUO[L]", "For all radios, the set of links that are asymmetric, where the opposing link does not coordinate")
    dataOF.puts translateVar("LUB[L]", "For all radios, the set of links that are asymmetric, where the baseline link does not coordinate")
    dataOF.puts translateVar("OL", "For all conflicting link pairs, the loss rate on the link")
    dataOF.close
    @init_time = Time.now - init_start
  end
  
  def run(parallel, ofunction, solution_name)
    if(ofunction == Objective::FCFS)
      run_fcfs(parallel, solution_name)
    elsif(ofunction == Objective::LARGEST_FIRST)
      run_lf(parallel, solution_name)
    else
      return solve(parallel, ofunction, solution_name)
    end
#    `rm -r #{@rand_dir}`
  end
  
  def run_lf(parallel, solution_name)
    networks = hgraph.getNetworks

    sorted_nets = networks.sort_by {|key,vals| networks[key].bandwidth}
    sorted_nets.reverse!   # Largest first
    
    # Get all of the unique bandwidths
    bandwidths = Array.new
    networks.each_value {|n| bandwidths.push(n.bandwidth) if(not bandwidths.include?(n.bandwidth))}

    chosen_freqs=Hash.new
    networks.each_key {|n| chosen_freqs[n]="4000"}

    potential_freqs=Hash.new
    networks.each_key {|n| potential_freqs[n]=networks[n].radios[0].frequencies}
    networks.each_key {|n|
      networks[n].radios.each {|r| r.frequencies=[4000]}
    }
    
    cnn=1
    bandwidths.sort.reverse.each do |bw|
      print "network (#{cnn} / #{networks.size}) "
      curr_networks=Array.new
      networks.each_value {|n| curr_networks.push(n) if(n.bandwidth==bw)}
      curr_networks.sort_by! {|n| n.dAirtime}
      curr_networks.reverse!   # Most airtime first

      curr_networks.each do |net|
        frequencies=net.radios[0].frequencies
        outcomes=Hash.new
        potential_freqs[net.networkID].each do |pf|
          net.radios.each {|r| r.frequencies=[pf]}
          initialize(hgraph)
          solve(false, Objective::PROD_PROP_AIRTIME, nil)
          outcomes[pf]=hgraph.getNetworks[net.networkID].radios[0].residual
        end
        os = outcomes.sort_by {|key,val| val}
        #puts os.inspect
        vls = os.map {|i| i[1]}
        mx = 0; os.each {|i| mx=i[1] if(i[1]>mx)}
        choose=Array.new
        os.each {|i| choose.push(i[0]) if(i[1]==mx)}
        #puts choose.inspect
        freq = choose[rand(choose.length)]
        net.radios.each {|r| r.frequencies=[freq]}
        #puts freq.inspect
        puts "#{net.networkID} #{net.dAirtime} #{freq} #{outcomes}"
        cnn+=1
      end
    end
     return solve(parallel, Objective::LARGEST_FIRST, solution_name) 
  end
  
  def run_fcfs(solution_name)
    networks = hgraph.getNetworks
    potential_freqs=Hash.new
    networks.each_key {|n| potential_freqs[n]=networks[n].radios[0].frequencies}
    networks.each_key {|n|
      networks[n].radios.each {|r| r.frequencies=[4000]}
    }
    curr_networks = networks.to_a.map {|i| i[1]}
    cnn=1
    curr_networks.shuffle.each do |net|
      puts "network (#{cnn} / #{networks.size}) networkID: #{net.networkID} dAirtime: #{net.dAirtime} protocol: #{net.protocol}"
      frequencies=net.radios[0].frequencies
      outcomes=Hash.new
      potential_freqs[net.networkID].each do |pf|
        net.radios.each {|r| r.frequencies=[pf]}
        initialize(hgraph)
        solve(false, Objective::PROD_PROP_AIRTIME, nil)
        outcomes[pf]=hgraph.getNetworks[net.networkID].radios[0].residual
      end
      os = outcomes.sort_by {|key,val| val}
      #puts os.inspect
      vls = os.map {|i| i[1]}
      mx = 0; os.each {|i| mx=i[1] if(i[1]>mx)}
      choose=Array.new
      os.each {|i| choose.push(i[0]) if(i[1]==mx)}
      #puts choose.inspect
      freq = choose[rand(choose.length)]
      net.radios.each {|r| r.frequencies=[freq]}
      #puts freq.inspect
      #puts "yep #{net.dAirtime} #{hgraph.getNetworks[net.networkID].airtime} #{hgraph.getNetworks[net.networkID].activeFreq}"
      #puts "#{net.networkID} #{net.dAirtime} #{freq} #{outcomes}"
      cnn+=1
    end
    return solve(parallel, Objective::FCFS, solution_name) 
  end

  def reload_data(ofunction, solution_name)
    solve_start = Time.now
    radios = hgraph.getRadios 
    curr_dir=Dir.pwd
    radios.each {|r|
      r.lossRate=0.0
      r.goodAirtime=0.0
      r.airtime=0.0
      r.ats=0.0
      r.residual=0.0
      r.rfs_max=0.0
    }
    fString=`cat #{solution_name} | grep -E "RadioAirtime\|rfs_max\|GoodAirtime\|Residual\|ats\|RadioLossRate\|af\#|no solution"`.split("\n").map {|i| i.chomp}
    raise RuntimeError, '!!!! NO SOLUTION AVAILABLE !!!!' if(fString.include?("no solution available"))
    fString.each { |line|
      spl=line.split[0].split("#")
      rid=spl[1].to_i

      if(spl[0]=="af")
        freq=spl[2].to_i
        val=line.split[1].to_f
        puts line
        radios[rid-1].activeFreq = freq if(line.split[1].to_f>0.1)
      end

      if(spl[0]=="RadioLossRate")
        radios[rid-1].lossRate = line.split[1].to_f
      end
      
      if(spl[0]=="Residual")
        radios[rid-1].residual = line.split[1].to_f
      end
      
      if(spl[0]=="ats")
        radios[rid-1].ats = line.split[1].to_f
      end
      
      if(spl[0]=="rfs_max")
        radios[rid-1].rfs_max = line.split[1].to_f
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
      r.ats=0.0 if(r.ats.nil?)
      r.residual=0.0 if(r.residual.nil?)
      r.rfs_max=0.0 if(r.rfs_max.nil?)
    }
    @solve_time = Time.now - solve_start
    return radios
  end
  
  def solve(parallel, ofunction, solution_name)
    `rm -f /tmp/*.sol`
    solve_start = Time.now
    radios = hgraph.getRadios 
    `touch /tmp/fscip.set`

    radios.each {|r|
      r.lossRate=0.0
      r.goodAirtime=0.0
      r.airtime=0.0
      r.ats=0.0
      r.residual=0.0
      r.rfs_max=0.0
    }
    
    if(solution_name.nil? or solution_name=="")
      solution_name="fscip.sol" if(solution_name.nil? or solution_name=="")
      curr_dir="#{@rand_dir}"
    else
      solution_name = "#{solution_name}_#{ofunction.gsub("obj_","")}.sol"
      curr_dir="#{Dir.pwd}"
    end

    if((ofunction == Objective::FCFS) or (ofunction == Objective::LARGEST_FIRST))
      ofunction=Objective::PROP_AIRTIME
    end

    `cp spectrum_optimization.zpl #{@rand_dir}`
    `cp obj_* #{@rand_dir}`
    #`rm -f #{curr_dir}/#{solution_name}`
    if(parallel)
      `cd #{@rand_dir} && fscip /tmp/fscip.set #{ofunction}.zpl -q -fsol #{curr_dir}/#{solution_name} 2> /dev/null`
    else
      `cd #{@rand_dir} && scip -f #{ofunction}.zpl > #{curr_dir}/#{solution_name} 2> /dev/null`
    end

    fString=`cat #{curr_dir}/#{solution_name} | grep -E "RadioAirtime\|GoodAirtime\|rfs_max\|Residual\|ats\|RadioLossRate\|af\#|no solution"`.split("\n").map {|i| i.chomp}
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

      if(spl[0]=="Residual")
        radios[rid-1].residual = line.split[1].to_f
      end
      
      if(spl[0]=="ats")
        radios[rid-1].ats = line.split[1].to_f
      end
      
      if(spl[0]=="rfs_max")
        radios[rid-1].rfs_max = line.split[1].to_f
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
      r.ats=0.0 if(r.ats.nil?)
      r.residual=0.0 if(r.residual.nil?)
      r.rfs_max=0.0 if(r.rfs_max.nil?)
    }
    @solve_time = Time.now - solve_start
    return `cat #{curr_dir}/#{solution_name}`
  end
  
  def self.getMultiFairnessBarPlot(pdata,options)

    additional=""

    k1 = pdata.keys[0]
    k2 = pdata.keys[1]

    vs1 = pdata[k1]
    vs2 = pdata[k2]

    objects=10
    vs1[0].each_index do |ri|

      str1 = vs1[0][ri]
      vals1 = vs1[1][ri]

      str2 = vs2[0][ri]
      vals2 = vs2[1][ri]

      if(vals1>vals2)
        additional+="set object #{objects} rect from #{str1} fs pattern 11 lw 3\n"
        objects+=1
        additional+="set object #{objects} rect from #{str2} fs pattern 12 lw 3\n"
        objects+=1
      else
        additional+="set object #{objects} rect from #{str2} fs pattern 12 lw 3\n"
        objects+=1
        additional+="set object #{objects} rect from #{str1} fs pattern 11 lw 3\n"
        objects+=1
      end
    end

    options["additional"]=additional
   
    return options
  end
  
  def getFairnessBarPlot()
    data = Hash.new
    additional=""

    protocols=["802.11agn","802.11n","802.11n-40MHz","ZigBee","Analog"]
    protocols.each {|p| data[p]=Array.new}

    radios = hgraph.getRadios

    total_radios=0    
    hgraph.getRadios.each do |r|
      next if(r.dAirtime.nil? or r.dAirtime==0)
      straight_up = r.goodAirtime.round(3) / r.dAirtime.round(3)

      prefix="W" if(r.protocol=="802.11agn")
      prefix="N" if(r.protocol=="802.11n" || r.protocol=="802.11n-40MHz")
      prefix="A" if(r.protocol=="Analog")
      prefix="Z" if(r.protocol=="ZigBee")

      scaling=1.0
#      if(r.protocol=="ZigBee")
#        scaling=0.3
#      elsif(prefix=="W" and r.networkTypeID==4)
#        scaling=0.45
#      else
#        scaling=0.6
#      end
      max_additional = (r.rfs_max-r.airtime) * (1-r.lossRate) * scaling
      with_retries = [r.goodAirtime + max_additional, r.dAirtime].min / r.dAirtime
      data[r.protocol].push([straight_up.round(3),with_retries.round(3)].max)
      total_radios+=1

      puts "#{prefix}#{r.networkTypeID} Loss: #{r.lossRate.round(3)}  Desired: #{r.dAirtime} Good: #{r.goodAirtime.round(3)} RfsMax: #{r.rfs_max} MaxAdd: #{max_additional}"
    end

    protocols_in_use=0
    protocols.each {|p| protocols_in_use+=1 if(data[p].length>0)}
    protocols.each {|p| data.delete(p) if(data[p].length==0)}

    curr_protocol=0
    curr_radio=0
    objects=1
    xtics="("
    st=0
    en=0
    locations=Array.new
    values = Array.new
    data.each_key do |p|
 
      st=(2*curr_protocol)+curr_radio-0.5
      data[p].each_index do |di|
        color="#1E90FF" if(p=="802.11agn")
        color="gold" if(p=="802.11n" || p=="802.11n-40MHz")
        color="red" if(p=="Analog")
        color="green" if(p=="ZigBee")
        additional+="set object #{objects} rect from #{(2*curr_protocol)+curr_radio-0.4},#{0} to #{(2*curr_protocol)+curr_radio+0.4},#{data[p][di]} fc rgb \"#{color}\" lw 3\n"
        values.push(data[p][di])
        locations.push("#{(2*curr_protocol)+curr_radio-0.4},#{0} to #{(2*curr_protocol)+curr_radio+0.4},#{data[p][di]} fc rgb \"#{color}\"")
        en=(2*curr_protocol)+curr_radio-0.5
        objects+=1
        curr_radio+=1
      end
      
      xtics+="\"#{p.gsub("-","\\n")}\" #{[st,en].mean+0.5},"

      curr_protocol+=1
    end
    xtics=xtics[0..-2]
    xtics+=") font \"Times-Roman,28\""

    additional+="set y2label \"Loss Rate\" offset -1,0\n"
    additional+="set y2range [0:1]\n"
    additional+="set y2tics (\"0\" 0, \"0.2\" 0.2, \"0.4\" 0.4, \"0.6\" 0.6, \"0.8\" 0.8, \"1\" 1.0)\n"
    ytics="(\"0\" 0, \"0.2\" 0.2, \"0.4\" 0.4, \"0.6\" 0.6, \"0.8\" 0.8, \"1\" 1)"
    options=Hash["xoff",[0,-0.75], "xtics",xtics, "xrange",[-2,(2*curr_protocol)+curr_radio], "additional",additional, "ytics",ytics, "pointsize",4, "yrange",[0,1], "style","bargraph", "grid",true, "linewidth",8, "ylabel","Received / Desired Airtime \\nFraction", "xlabel","Networks Grouped By Protocol", "nokey",true]
   
    return data, options, locations, values
  end

#  def getFairnessPlot()
#    data = Hash.new
#    data["d"]=Array.new
#    additional=""
#
#    radios = hgraph.getRadios
#
#    radios.sort_by! {|r| r.protocol}
#
#    start_end=Array.new
#    curr_radio=0
#    curr_protocol=radios[0].protocol
#    start=0
#    radios.each do |r|
#      next if(r.dAirtime.nil? or r.dAirtime==0)
#      if(r.protocol != curr_protocol)
#        start_end.push([curr_protocol, start,curr_radio-1])
#        start=curr_radio
#        curr_protocol=r.protocol
#      end
#
#      straight_up = r.goodAirtime.round(3) / r.dAirtime.round(3)
#      with_retries = (r.rfs_max * (1-r.lossRate)).round(3) / r.dAirtime.round(3)
#
#      data["d"].push([straight_up,with_retries].max)
#      curr_radio+=1
#    end
#
#    additional+="set style rect fc lt -1 fs solid 0.15 noborder\n"
#    start_end.each_index do |sei|
#      st=start_end[sei][1]
#      en=start_end[sei][2]
#      proto=start_end[sei][0]
#      offset=0
#      offset=-0.5 if(proto=="802.11agn")
#      offset=0 if(proto=="ZigBee")
#      offset=-0.5 if(proto=="802.11n")
#      offset=-1 if(proto=="802.11n-40MHz")
#      additional+="set label \"#{proto}\" at #{en-((en-st)/2.0)+offset},1.05\n"
#      next if(sei%2==1)
#      additional+="set obj rect from #{st-0.5}, graph 0 to #{en+0.5}, graph 1\n"
#    end
#  
#    ytics="(\"0\" 0, \"0.2\" 0.2, \"0.4\" 0.4, \"0.6\" 0.6, \"0.8\" 0.8, \"1\" 1)"
#    options=Hash["xrange",[-0.5,data["d"].length-0.5], "additional",additional, "ytics",ytics, "pointsize",4, "yrange",[0,1], "style","linespoints", "grid",true, "linewidth",8, "ylabel","Airtime / Desired Airtime", "xlabel","Relative Radio", "nokey",true]
#   
#    return data, options
#  end
  
  def getPipelinePlot(ordered)

    additional=""
    curr_x=0
    objects=10

    # For each bandwidth, get the networks that belong to it and sort by airtime
    ordered.each do |net|

      hgraph.getNetworks().each {|nkey,n2| net = n2 if(n2.networkID==net.networkID)}
      
      color="#1E90FF" if(net.protocol=="802.11agn")
      color="gold" if(net.protocol=="802.11n" || net.protocol=="802.11n-40MHz")
      color="red" if(net.protocol=="Analog")
      color="green" if(net.protocol=="ZigBee")

      prefix="W" if(net.protocol=="802.11agn")
      prefix="N" if(net.protocol=="802.11n" || net.protocol=="802.11n-40MHz")
      prefix="A" if(net.protocol=="Analog")
      prefix="Z" if(net.protocol=="ZigBee")

      additional+="set object #{objects} rect from #{curr_x},0 to #{curr_x+net.dAirtime},1 fc rgb \"#{color}\" lw 3\n"
      location=Array.new
      location[0]=([curr_x,curr_x+net.dAirtime].mean)-0.05
      location[1]=0.5
      location[0]+=0.01 if(prefix=="Z" and (net.networkTypeID==3 || net.networkTypeID==2))

      splits=["W4","W10","W8","W12"]
      spl=""
      if(splits.include?("#{prefix}#{net.networkTypeID}"))
        spl="\\n"
        location[0]+=0.01
        location[1]+=0.15      
      end
      additional+="set label \"#{prefix}#{spl}#{net.networkTypeID}\" at #{location[0]},#{location[1]} font \"Times-Roman,67\"\n"
      objects+=1
      curr_x+=net.dAirtime
    end
      
    additional+="set style arrow 1 head filled ls 1\n"
    additional+="set label \"Network arrival order\" at 0,1.23 font \"Times-Roman,80\"\n"
    additional+="set arrow from 0.95,1.22 to 1.1,1.22 as 1 lc -1 lw 20\n"

#    additional+="set ylabel \"Networks\\n(in order of arrival)\" offset 1.5,0 rotate by 270\n"
    additional+="unset ytics\n"
    options=Hash["fontsize",72, "xrange",[0,curr_x], "additional",additional, "style","lines", "size","6,1", "rotate",true, "yrange",[0,1], "lt",[1,1,1], "lc",[3,1,2], "grid",true, "xlabel", "Total Airtime","nokey",true]
    data=Hash.new
    return data,options
  end

  def get5GHzSpectrumPlot(dc)
    return spectrumPlot(dc,5660,5840)
  end

  def getSpectrumPlot(dc)
    return spectrumPlot(dc,2400,2485)
  end
  
  def spectrumPlot(dc,from,to)

    draw_conflicts=dc[0]
    dc_set=dc[1]

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
    (0..to-from).each {|v| data["x"].push(from+v)}
    additional=""

    airtime_bins=Hash.new
    airtime_bins["802.11agn"]=Hash.new
    airtime_bins["802.11n"]=Hash.new
    airtime_bins["ZigBee"]=Hash.new
    airtime_bins["Analog"]=Hash.new
    airtime_bins["802.11agn"].default=0
    airtime_bins["802.11n"]=airtime_bins["802.11agn"]
#    airtime_bins["802.11n"].default=0
    airtime_bins["ZigBee"].default=0
    airtime_bins["Analog"].default=0
    airtime_bins["802.11n-40MHz"]=airtime_bins["802.11n"]
  

    objects=10
    net_locations=Hash.new
    # For each bandwidth, get the networks that belong to it and sort by airtime
    bandwidths.sort.reverse.each do |bw|
      curr_networks=Array.new
      networks.each_value {|n| curr_networks.push(n) if(n.bandwidth==bw)}
      curr_networks.sort_by {|n| n.dAirtime}
      curr_networks.reverse!   # Most airtime first

      curr_networks.shuffle.each do |net|

        color="#1E90FF" if(net.protocol=="802.11agn")
        color="gold" if(net.protocol=="802.11n" || net.protocol=="802.11n-40MHz")
        color="red" if(net.protocol=="Analog")
        color="green" if(net.protocol=="ZigBee")

        start_freq = (net.activeFreq - (net.bandwidth / 2.0)).to_i
        end_freq = (net.activeFreq + (net.bandwidth / 2.0)).to_i

        max_airtime=0.0
        (start_freq..end_freq).each {|f| max_airtime=airtime_bins[net.protocol][f] if(airtime_bins[net.protocol][f]>max_airtime) }
        (start_freq..end_freq).each {|f| airtime_bins[net.protocol][f]+=net.dAirtime }

        prefix="W" if(net.protocol=="802.11agn")
        prefix="N" if(net.protocol=="802.11n" || net.protocol=="802.11n-40MHz")
        prefix="A" if(net.protocol=="Analog")
        prefix="Z" if(net.protocol=="ZigBee")

        location=[net.activeFreq-1,max_airtime+(net.dAirtime/2.0)]
        additional+="set object #{objects} rect from #{start_freq},#{max_airtime} to #{end_freq},#{max_airtime+net.dAirtime} fc rgb \"#{color}\" lw 3\n"
        fontsize = (net.dAirtime>0.15) ? 32 : 20;
        xoff = (net.dAirtime>0.15) ? 1 : 0.5;
        additional+="set label \"#{prefix}{#{net.networkTypeID}}\" at #{location[0]-xoff},#{location[1]} font \"Times-Roman,#{fontsize}\"\n" if(prefix!="A")
        net_locations[net.networkID]=location
        objects+=1
      end
    end

    if(draw_conflicts)

      additional+="set style line 1 lt 1 lw 14\n"
      additional+="set style arrow 1 head filled size screen 0.035,30,45 ls 1\n"

      net_conflicts=Array.new
      @conflict_graph.each do |c|
        next if(!dc_set.include?(c.from.srcID) and !dc_set.include?(c.to.srcID))
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
          add_from = -1
          add_to = 3
        end
        additional+="set arrow from #{loc_from[0]+add_from},#{loc_from[1]} to #{loc_to[0]+add_to},#{loc_to[1]} as 1 lc 1\n"
      }
    end
    
    ###### Right Side
#    additional+="set object #{objects} rect from 2460,1.4 to 2466,1.5 fc rgb \"#1E90FF\" lw 2\n"; objects+=1
#    additional+="set object #{objects} rect from 2460,1.25 to 2466,1.35 fc rgb \"green\" lw 2\n"; objects+=1
#    additional+="set object #{objects} rect from 2460,1.10 to 2466,1.20 fc rgb \"red\" lw 2\n"; objects+=1
#    additional+="set object #{objects} rect from 2423,1.4 to 2429,1.5 fc rgb \"gold\" lw 2\n"; objects+=1
#    additional+="set label \"802.11abgn\" at 2467.5,1.45\n"
#    additional+="set label \"802.11n (HT mode)\" at 2430.5,1.45\n"
#    additional+="set label \"ZigBee\" at 2467.5,1.30\n"
#    additional+="set label \"Analog\" at 2467.5,1.15\n"
    
    ###### Left Side
    additional+="set object #{objects} rect from 2402,1.4 to 2408,1.5 fc rgb \"#1E90FF\" lw 2\n"; objects+=1
    additional+="set object #{objects} rect from 2402,1.25 to 2408,1.35 fc rgb \"green\" lw 2\n"; objects+=1
    additional+="set object #{objects} rect from 2402,1.10 to 2408,1.20 fc rgb \"red\" lw 2\n"; objects+=1
    additional+="set object #{objects} rect from 2426,1.25 to 2432,1.35 fc rgb \"gold\" lw 2\n"; objects+=1
    additional+="set label \"802.11abgn\" at 2409.5,1.45\n"
    additional+="set label \"802.11n\\n(HT mode)\" at 2433.5,1.30\n"
    additional+="set label \"ZigBee\" at 2409.5,1.30\n"
    additional+="set label \"Analog\" at 2409.5,1.15\n"

    if(false) 
      additional+="set style rect fc lt -1 fs solid 0.07 noborder\n"
      additional+="set style arrow 2 nohead lt 5 lw 5\n"

      c1_low=0; airtime_bins.each {|k,v| c1_low = v[2402] if(v[2402]>c1_low)}
      c1_high=0; airtime_bins.each {|k,v| c1_high = v[2423] if(v[2423]>c1_high)}
      additional+="set obj 1 rect from 2402,0 to 2423,1\n"
      additional+="set arrow from 2402,#{c1_low} to 2402,1 as 2 lc -1\n"
      additional+="set arrow from 2423,#{c1_high} to 2423,1 as 2 lc -1\n"
      
      c6_low=0; airtime_bins.each {|k,v| c6_low = v[2427] if(v[2427]>c6_low)}
      c6_high=0; airtime_bins.each {|k,v| c6_high = v[2447] if(v[2447]>c6_high)}
      additional+="set obj 2 rect from 2427,0 to 2447,1\n"
      additional+="set arrow from 2427,#{c6_low} to 2427,1 as 2 lc -1\n"
      additional+="set arrow from 2447,#{c6_high} to 2447,1 as 2 lc -1\n"
      
      c11_low=0; airtime_bins.each {|k,v| c11_low = v[2452] if(v[2452]>c11_low)}
      c11_high=0; airtime_bins.each {|k,v| c11_high = v[2472] if(v[2472]>c11_high)}
      additional+="set obj 3 rect from 2452,0 to 2472,1\n"
      additional+="set arrow from 2452,#{c11_low} to 2452,1 as 2 lc -1\n"
      additional+="set arrow from 2472,#{c11_high} to 2472,1 as 2 lc -1\n"
    end

    additional+="set ylabel \"Airtime\" offset 1,-1.7\n"
    ytics="(\"0\" 0, \"0.2\" 0.2, \"0.4\" 0.4, \"0.6\" 0.6, \"0.8\" 0.8, \"1\" 1)"
    options=Hash["xrange",[data["x"][0],data["x"][-1]], "additional",additional, "style","lines", "ytics",ytics, "rotate",true, "yrange",[0,1.55], "lt",[1,1,1], "lc",[3,1,2], "grid",true, "xlabel", "Spectrum (MHz)","nokey",true]
    return data,options
  end

end
