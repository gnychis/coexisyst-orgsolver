#!/usr/bin/ruby

types=["802.11g","802.11n","ZigBee","AnalogPhone"]
T={"802.11g" => 2000, "802.11n" => 2000, "ZigBee" => 2000, "AnalogPhone" => 2000}
B={"802.11g" => 20000, "802.11n" => 20000, "ZigBee" => 5000, "AnalogPhone" => 1000}

def airtime(type)
  if(type=="802.11g" || type=="802.11n")
    return rand
  elsif(type=="ZigBee")
    line=IO.readlines("exps.txt")
    c = rand*line.length.to_i
    return line[c-1].to_f
  elsif(type=="AnalogPhone")
    return 1
  else
    return -1
  end
end

def frequencies(type)
  if(type=="802.11g" || type=="802.11n")
    return "2412e3,2437e3,2462e3"
  elsif(type=="ZigBee")
    return "2405e3,2410e3,2415e3,2420e3,2425e3,2430e3,2435e3,2440e3,2445e3,2450e3,2455e3,2460e3,2465e3,2470e3,2475e3,2480e3"
  elsif(type=="AnalogPhone")
    return "2412e3,2437e3,2462e3,2476e3"
  else
    return -1
  end
end

# Benchmark for 1 network, all the way up to 50 networks
(2 .. 10).each do |n|

  fn=File.new("networks.dat","w")
  ff=File.new("network_frequencies.zpl","w")
  fc=File.new("unified_coordination.zpl","w")
  ff.puts "set FB[W] := "

  chosen=Array.new
  atsum=0;
  
  # Just round robin the type of network used
  (1 .. n).each do |j|
    type = types[(j-1) % types.size];

    # Generate the networks dat file
    rat=airtime(type)
    atsum+=rat
    fn.puts "#{j} #{type} #{rat} #{B[type]} #{T[type]}"

    # Generate the network frequencies
    ff.print "\t<#{j}> {#{frequencies(type)}}"
    if(j==n)
      ff.puts ";"
    else
      ff.puts ","
    end
    chosen.push(type)
  end

  coordinate=Array.new
  uncoordinate=Array.new

  # Write the coordination data
  chosen.each_index do |r|
    coordinate[r]=Array.new
    uncoordinate[r]=Array.new
    chosen.each_index do |t|
      rval=rand
      if(r==t)
        coordinate[r].push(t+1) 
      elsif(chosen[r]!=chosen[t])
        uncoordinate[r].push(t+1)
      elsif(rval>0.25)
        coordinate[r].push(t+1)
      else
        uncoordinate[r].push(t+1)
      end
    end
  end
  
  fc.puts "set C[W] :="
  coordinate.each_index do |r|
    fc.print "\t<#{r+1}> {"
      coordinate[r].each_index do |t|
        if(t!=coordinate[r].size-1)
          fc.print "#{coordinate[r][t]},"
        else
          fc.print "#{coordinate[r][t]}"
        end
      end
    fc.print "}"

    if(r==coordinate.size-1)
      fc.puts ";"
    else
      fc.puts ","
    end
  end
  
  fc.puts ""
  fc.puts "set U[W] :="
  uncoordinate.each_index do |r|
    fc.print "\t<#{r+1}> {"
      uncoordinate[r].each_index do |t|
        if(t!=uncoordinate[r].size-1)
          fc.print "#{uncoordinate[r][t]},"
        else
          fc.print "#{uncoordinate[r][t]}"
        end
      end
    fc.print "}"

    if(r==uncoordinate.size-1)
      fc.puts ";"
    else
      fc.puts ","
    end
  end

  # Close the files
  fn.close
  ff.close
  fc.close

  `zimpl spectrum_organizer.zpl &> /dev/null`
  t1 = Time.now.getutc
  `scip -f spectrum_organizer.lp &> /dev/null`
  t2 = Time.now.getutc

  puts "#{n} #{atsum} #{t2-t1}"
end
