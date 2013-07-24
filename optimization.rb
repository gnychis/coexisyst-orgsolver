#!/usr/bin/ruby

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
