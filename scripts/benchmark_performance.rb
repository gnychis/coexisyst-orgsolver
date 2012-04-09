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

# Benchmark for 1 network, all the way up to 50 networks
(5 .. 5).each do |n|

  fn=File.new("networks.dat","w")
  
  # Just round robin the type of network used
  (1 .. n).each do |j|
    type = types[(j-1) % types.size];

    # Generate the networks dat file
    rat=airtime(type)
    fn.puts "#{j} #{type} #{rat} #{B[type]} #{T[type]}"

  end
  
  fn.close
end
