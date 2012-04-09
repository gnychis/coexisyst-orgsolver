#!/usr/bin/ruby

types=["802.11g","802.11n","ZigBee","AnalogPhone"]
T=["802.11g" => 2000, "802.11n" => 2000, "ZigBee" => 2000, "AnalogPhone" => 2000]
B=["802.11g" => 20000, "802.11n" => 20000, "ZigBee" => 5000, "AnalogPhone" => 1000]



# Benchmark for 1 network, all the way up to 50 networks
(1 .. 50).each do |n|

  # Just round robin the type of network used
  (1 .. n).each do |j|
    
  end

end
