#!/usr/bin/ruby

# Data should be in the format:
# Hash: <key> <array>
#   where key will be used as the data name
# NEEDED: a key element named "x" which is the shared X data
def plot(filename, data, options)

  if(!options.has_key?("mult_x"))
		# Dump the data somewhere
		of = File.open("/tmp/data","w")
		of.print "x "
		data.sort.each {|k,v| of.print "\"#{k}\" " if(k!="x")}; of.print "\n"

		if(!data.has_key?("x"))
			size=0;
			data.each_key do |key|
				size = data[key].size
				break
			end
			data["x"] = Array.new
			(0..size-1).each {|v| data["x"].push(v)}
		end

		(0..data["x"].size).each do |i|
			#of.print "\"#{data["x"][i]}\" "
			of.print "#{data["x"][i]} "
			data.sort.each {|k,v| next if(k=="x"); of.print "#{v[i]} "}; of.print "\n"
		end
		of.close  
	end
  
	names=Array.new; i=0
  if(options.has_key?("mult_x") && options["mult_x"]==true)
    data.each_key do |k|
      names.push("\"#{k}\"") if(k!="x")
      next if(k=="x")
      of = File.open("/tmp/#{i}","w")
      data[k].each {|x,y| of.puts "#{x} #{y}"}
      of.close
      i += 1
    end
  end

  pf = File.open("/tmp/plot","w")
  fontsize=34
  fontsize=options["fontsize"] if(options.has_key?("fontsize"))
  pf.puts "set term postscript eps enhanced color \"Times-Roman,#{fontsize}\""
  pf.puts "set size 1.5,1"
  pf.puts "set output \"#{filename}.eps\""
  pf.puts "set xtic auto"
  pf.puts "set ytic auto"
  pf.puts "set pointsize 1"

	pf.puts "set title \"#{options["title"]}" if(options.has_key?("title"))

  pf.puts "set mxtics #{options["mxtics"]}" if(options.has_key?("mxtics"))
  pf.puts "set mytics #{options["mytics"]}" if(options.has_key?("mytics"))
  pf.puts "set size #{options["size"]}" if(options.has_key?("size"))
  pf.puts "set ylabel \"#{options["ylabel"]}\" offset 1,0" if(options.has_key?("ylabel"))
  pf.puts "set xlabel \"#{options["xlabel"]}\"" if(options.has_key?("xlabel"))
  pf.puts "set key #{options["key"]}" if(options.has_key?("key"))
  pf.puts "set logscale x" if(options.has_key?("xlogscale") && options["xlogscale"]==true)
  pf.puts "set logscale y" if(options.has_key?("ylogscale") && options["ylogscale"]==true)
  pf.puts "set ytics #{options["ytics"]}" if(options.has_key?("ytics"))
  pf.puts "set xtics #{options["xtics"]}" if(options.has_key?("xtics"))
  pf.puts "unset key" if(options.has_key?("nokey") && options["nokey"]==true)
  pf.puts "set grid" if(options.has_key?("grid") && options["grid"]==true)
  pf.puts "set yrange [#{options["yrange"][0]}:#{options["yrange"][1]}]" if(options.has_key?("yrange"))
  pf.puts "set xrange [#{options["xrange"][0]}:#{options["xrange"][1]}]" if(options.has_key?("xrange"))
  pf.puts "set pointsize #{options["pointsize"]}" if(options.has_key?("pointsize"))
  pf.puts "#{options["additional"]}" if(options.has_key?("additional"))

  if(options.has_key?("style") && options["style"]=="bargraph")
		gap = "1"
		gap = options["gap"] if(options.has_key?("gap"))
    pf.puts "set style fill   solid 1.00 border -1"
    pf.puts "set style histogram clustered gap #{gap} title  offset character 0, 0, 0"
    pf.puts "set datafile missing '-'"
    pf.puts "set style data histograms"
    rotate = "0"
    rotate = "-45" if(options.has_key?("rotate") && options["rotate"]==true)
    pf.puts "set xtics border in scale 1,0.5 nomirror rotate by #{rotate} offset character 0, 0, 0"
  end

  tics = ":xtic(1)" if(options.has_key?("style") && options["style"]=="bargraph")
  lw = "lw #{options["linewidth"]}" if(options.has_key?("linewidth"))
  lines = "w lines #{lw}" if(options.has_key?("style") && options["style"]=="lines")
  linespoints = "w linespoints #{lw}" if(options.has_key?("style") && options["style"]=="linespoints")
  usex = "1:" if(options.has_key?("usex") && options["usex"]==true)
  points = "w points pt 7" if(options.has_key?("style") && options["style"]=="points")
  
	if(!options.has_key?("mult_x"))
    line_colors=Array.new
    line_types=Array.new
    (1..data.size).each {|l| line_colors.push("")}
    (1..data.size).each {|l| line_colors.push("")}
    if(options.has_key?("lc") and (options["lc"].size==(data.size-1)))
      options["lc"].each_index {|lci| line_colors[lci]=" lc #{options["lc"][lci]} "}
    end
    if(options.has_key?("lt") and (options["lt"].size==(data.size-1)))
      options["lt"].each_index {|lti| line_types[lti]=" lt #{options["lt"][lti]} "}
    end
    pf.print "plot \"/tmp/data\" using #{usex}2#{tics} ti col #{lines}#{points}#{linespoints}#{line_colors[0]}#{line_types[0]}" 
    (0..data.size-3).each {|i| pf.print ", '' using #{usex}#{i+3}#{tics} ti col #{lines}#{points}#{linespoints}#{line_colors[i+1]}#{line_types[i+1]}"}
  end


  if(options.has_key?("mult_x") && options["mult_x"]==true)
    line_colors=Array.new
    (1..names.size).each {|l| line_colors.push("")}
    if(options.has_key?("lc") && options["lc"].length==names.size)
      options["lc"].each_index do |lci|
        line_colors[lci]=" lc #{options["lc"][lci]} "
      end
    end

    pf.print "plot \"/tmp/0\" using 1:2 #{lines}#{points}#{linespoints}#{line_colors[0]} title #{names[0]}"
    (1..names.size-1).each do |i|
      pf.print ", \"/tmp/#{i}\" using 1:2 #{lines}#{points}#{linespoints}#{line_colors[i]} title #{names[i]}"
    end
  end

  pf.print "\n"

  pf.close

  `gnuplot /tmp/plot 2> /dev/null`
  loc=`which epstopdf`.chop
    system("perl #{loc} #{filename}.eps")
	system("rm #{filename}.eps")

end
