#!/usr/bin/ruby

## This is my ccommand, actuially this is months old, but im in win at the mo and no access to current
#  file i use.  You can guess the variables.    time mencoder $3 -dvd-device $DVD -alang en -forceidx -fps
#  25 -oac mp3lame -lameopts abr:br=$2:aq=2 -ovc x264 -x264encopts
#  threads=2:trellis=0:crf=17:qp_min=11:qp_max=35:subq=4:keyint=100 -vf
#  scale=560:448,pp=ac/lb,hqdn3d=1:1:1:1 -sws 2 -o $4.avi


## Utility functions
def usage
  puts "Usage: #{$0} [<options> ...] <inputfile>"
  puts "Options:"
  puts "  -o --output {<filename>|auto}    Set the output file"
  puts "  -T --temp-file {<file>|auto}     Change the temp file for two-pass"
  puts "  -L --log {<filename>|auto}       Change the log file"
  puts "  -2 --two-pass                    Enable two-pass encoding"
  puts "  -1 --one-pass                    Disable two-pass encoding"
  puts "  -S --skip-first                  Skip the first pass (advanced only)"
  puts "     --old-stats                   Use old statistics file (advanced only)"
  puts "     --skip-stats                  Do not autodetect (advanced only)"
  puts "  -A --append <options>            Append <options> to BOTH encode passes"
  puts "  -R --rip-from <device> <title>   Rip dvd://<title> from <device> to <inputfile> first"
  puts "     --rip-only                    Don't encode, just rip the DVD"
  puts "  -L --rip-lang <lang-id>          Set the rip subtitle language (after -R) (default: en)"
  puts "     --subid <subtitle-index>      Set the subtitle language by numerical ID"
  puts "     --eject                       Eject after ripping from DVD"
  puts "  -q --quality {1..100}            Quality (affects bitrate, default is 50 for onepass)"
  puts "  -M --size <size>                 Calculate bitrate from the size given (in megabytes)"
  puts "  -P --no-preview                  Disable the preview of what will be ripped from DVD"
  puts "  -p --pretend                     Don't actually execute any commands"
  puts "  -y --yes                         Do not ask confirm the various transcode phases"
  puts "  -I --iphone                      Make iphone-compatible video"
  exit
end

def chgext(filename, newext)
  pieces = filename.to_s.split(/\./)
  if pieces.length > 1
    pieces.pop
  end
  pieces.push newext.to_s unless newext.nil?
  return pieces.join(".")
end

def confirm_or_abort
  print "<press enter to confirm> "
  STDIN.gets
  if ($_.chomp.length > 0)
    puts "[ ABORTED ]"
    exit
  end
end

## System settings
mencoder = "/usr/bin/mencoder"
mplayer = "/usr/bin/mplayer"
midentify = "/usr/bin/midentify"
mp4box = "/usr/bin/MP4Box"
encodeargs = File.dirname($0) + "/encode-args.rb"

## Argument Processing
# Control Variables
cmdline = ARGV.join(" ")
pretend = false
outfile = "auto"
twofile = "auto"
logfile = "auto" # "transcode.log"
twopass = true
confirm = false
ripfrom = nil
riponly = false
skipfirst = false
autocrop = true
autodetect = true
skipstats = false
append = ""
quality = -1
size = -1
iphone = false

args = Array.new # unprocessed arguments

# Processing Loop
while ARGV.length > 0
  unless ARGV[0][0].chr == "-"
    args.push ARGV.shift
    next
  end
  switch = ARGV.shift

  # If it's a compound short switch
  if switch.length > 2 and switch[1].chr != "-"
    (2...switch.length).each { |i|
      ARGV.unshift "-#{switch[i].chr}"
    }
    switch = "-#{switch[1].chr}"
  end

  # Process the switch
  case switch
    when "-o", "--output"
      outfile = ARGV.shift
    when "-L", "--log"
      logfile = ARGV.shift
    when "-T", "--temp-file"
      twofile = ARGV.shift
    when "-2", "--two-pass"
      twopass = true
      quality = 60 if quality == -1
    when "-1", "--one-pass"
      twopass = false
    when "-q", "--quality"
      quality = ARGV.shift.to_i
      if (quality < 1 or quality > 1000)
        puts "Could not get reasonable quality from: #{quality}"
      end
    when "-M", "--size"
      size = ARGV.shift.to_f
      if (size < 20 or size > 1024*8) # less than 20MB or more than 8GB
        puts "Could not get reasonable (20MB..8GB) size from: #{size}"
      end
    when "-y", "--yes"
      confirm = false
    when "-A", "--append"
      append += ARGV.shift + " "
    when "-S", "--skip-first"
      skipfirst = true
    when "-R", "--rip-from"
      ripfrom = {:device => ARGV.shift, :title => ARGV.shift, :slang => "en"}
      if (ripfrom[:title].to_i == 0)
        puts "Error: Cannot convert \"#{ripfrom[:title]}\" into an integer"
        usage
      end
    when "-L", "--rip-lang"
      if ripfrom.nil?
        puts "Error: can't set rip language unless I'm ripping! (-R must come before -L)"
        usage
      else
        ripfrom[:slang] = ARGV.shift
      end
    when "--rip-only"
      riponly = true
    when "--subid"
      if ripfrom.nil?
        puts "Error: can't set rip vobsub unless I'm ripping! (--subid must come after -R)"
        usage
      else
        ripfrom[:sid] = ARGV.shift
      end
    when "--eject"
      if ripfrom.nil?
        puts "Error: can't set eject unless I'm ripping! (--eject must come after -R)"
      else
        ripfrom[:eject] = true
      end
    when "-P", "--no-preview"
      if ripfrom.nil?
        puts "Error: can't turn off rip preview unless I'm ripping! (-R must come before -P)"
        usage
      else
        ripfrom[:no_preview] = true
      end
    when "-p", "--pretend"
      pretend = true
      confirm = false
    when "--old-stats", "--skip-stats"
      skipstats = true
    when "-I", "--iphone"
      iphone = true
    else
      puts "Error: Unknown switch: #{switch}"
      usage
  end
end

if args.length < 1
  puts "Error: Too few arguments!"
  usage
elsif args.length > 1
  puts "Error: Too many arguments!"
  puts "Left over: #{args.join(" ")}"
  usage
end

infile = args.shift
outfile = chgext(infile,"avi")    if outfile == "auto"
twofile = chgext(infile,"fp.avi") if twofile == "auto"
logfile = chgext(infile,"log")    if logfile == "auto"

# Detect the size
source = infile
source = "dvd://#{ripfrom[:title]} -dvd-device #{ripfrom[:device]}" unless ripfrom.nil?
cmd = "#{midentify} #{source} | grep \"ID_LENGTH\" | cut -d'=' -f2"
lines = `#{cmd}`.split(/\s+/)
length = 0
lines.each { |l|
  puts "Line: #{l}"
  length += l.strip.to_f
}
abitrate = 256 # approx. audio bitrate

# Calculate video bitrate
if (size == -1)
  if (quality == -1)
    quality = 50
  end
  bitrate = 20*quality
  size = (bitrate + abitrate) * length / 1024 / 8
else
  if (length > 60) # reasonable time length, one minute?
    bitrate = size * 1024 * 8 / length - abitrate
  else
    puts "Unable to determine length of video to encode"
    exit
  end
end
bitrate = bitrate.to_i # truncate
size = (10.0*size).round.to_i/10.0 # round to 1 decimal place

puts "Paths:"
puts "  mencoder:           #{mencoder}"
puts "  mplayer:            #{mplayer}"
puts "  midentify:          #{midentify}"
puts "  mp4box:             #{mp4box}"
puts "  encodeargs:         #{encodeargs}"

unless ripfrom.nil?
  puts "Rip job information:"
  puts "  Device:             #{ripfrom[:device]}"
  puts "  Title(s):           #{ripfrom[:title]}"
  unless ripfrom.keys.include? :sid
    puts "  Language:           #{ripfrom[:slang]}"
  else
    puts "  Subtitle ID:        #{ripfrom[:sid]}"
  end
  puts "  Output File:        #{infile}"
end

puts "Detection information:"
puts "  Autodetect:         #{(autodetect)?"ENABLED":"DISABLED"}"
puts "  Autocrop:           #{(autocrop&&autodetect)?"ENABLED":"DISABLED"}"
puts "  Detection source:   #{(skipstats)?"PREVIOUS":"SCAN"}"
puts "Transcode job information:"
puts "  Input filename:     #{infile}"
puts "    Input length:       #{length}s";
puts "  Output filename:    #{outfile}"
puts "    Output bitrate:     #{bitrate}kbps (~#{abitrate}kbps audio)"
puts "    Output filesize:    #{size}MB (approx.)"
puts "         #{size} = (#{bitrate} + #{abitrate}) * #{length} / 1024 / 8}";
puts "  First Pass file:    #{twofile}" if twopass
puts "  Log file:           #{logfile}"
puts "  Two-pass encoding:  #{(twopass)?"ENABLED":"DISABLED"}"
puts "    First pass:         #{(skipfirst)?"SKIPPED":"NORMAL"}" if twopass
puts "  iPhone mode:        #{(iphone)?"ENABLED":"DISABLED"}"

confirm_or_abort if confirm


passes = (twopass)?2:1;

cmddesc = Array.new
commands = Array.new

### RIPPING
unless ripfrom.nil?
  puts "Ripping..."

  cmd = "mplayer -dvd-device #{ripfrom[:device]} dvd://#{ripfrom[:title]}"
  if ripfrom.keys.include? :sid
    cmd += " -sid #{ripfrom[:sid]}"
  elsif ripfrom[:slang].length > 0
    cmd += " -slang #{ripfrom[:slang]}"
  end
  cmd += " #{append}"
  Kernel.system(cmd) unless ripfrom.keys.include? :no_preview
  confirm_or_abort if confirm and not ripfrom.keys.include? :no_preview
  
  cmdpieces = Array.new
  cmdpieces.push mplayer
  cmdpieces.push "-dvd-device #{ripfrom[:device]}"
  cmdpieces.push "dvd://#{ripfrom[:title]}"
  cmdpieces.push "-v" # verbose
  cmdpieces.push "-dumpstream"
  cmdpieces.push "-dumpfile #{infile}"
  # Logging
  cmdpieces.push "2>&1"     # redirect stderr to stdout
  cmdpieces.push "|"        # redirect stdout to stdin of logging processes
  cmdpieces.push "tee"      # redirect stdin to stdout and file
  cmdpieces.push "-a"       # if it's the second pass, append it
  cmdpieces.push logfile    # send the output to both the screen and the file

  command = cmdpieces.join(" ")
  cmddesc.push "Video Rip"
  commands.push command

  if ripfrom[:slang].length > 0
    filetitle = chgext(infile, nil)
    cmdpieces = Array.new
    cmdpieces.push mencoder
    cmdpieces.push "-dvd-device #{ripfrom[:device]}"
    cmdpieces.push "dvd://#{ripfrom[:title]}"
    cmdpieces.push "-nosound"
    cmdpieces.push "-ovc frameno"
    cmdpieces.push "-o /dev/null"
    if ripfrom.keys.include? :sid
      cmdpieces.push "-sid #{ripfrom[:sid]}"
    elsif ripfrom[:slang].length > 0
      cmdpieces.push "-slang #{ripfrom[:slang]}"
    end
    cmdpieces.push "-vobsubout #{filetitle}"
    # Logging
    cmdpieces.push "2>&1"     # redirect stderr to stdout
    cmdpieces.push "|"        # redirect stdout to stdin of logging processes
    cmdpieces.push "tee"      # redirect stdin to stdout and file
    cmdpieces.push "-a"       # if it's the second pass, append it
    cmdpieces.push logfile    # send the output to both the screen and the file
    command = cmdpieces.join(" ")
    cmddesc.push "Subtitle Rip"
    commands.push command
  end

  if ripfrom.keys.include? :eject
    command = "eject #{ripfrom[:device]}"
    cmddesc.push "Eject"
    commands.push command
  end
end

unless riponly
  ### DETECTION
  progressive = false
  interlaced = false
  telecined = false
  crop = ""
  autofile = "/tmp/detect.#{File.basename(infile)}"

  # Gather the information that we'll need
  if autocrop or autodetect
    # mplayer -nosound -vo null -vf cropdetect -benchmark #{infile}
    cmdpieces = Array.new
    cmdpieces.push mplayer
    cmdpieces.push "-nosound"
    cmdpieces.push "-vo null"
    cmdpieces.push "-vf-add cropdetect" if autocrop
    cmdpieces.push "-vf-add pullup" if autodetect
    cmdpieces.push "-v" if autodetect # needed for pullup to be interesting
    cmdpieces.push "-benchmark"
    cmdpieces.push infile
    cmdpieces.push ">#{autofile} 2>&1"
    command = cmdpieces.join(" ")
    cmddesc.push "Statistics" unless skipstats
    commands.push command     unless skipstats
    cmddesc.push "Calculated Arguments"
    commands.push "#{encodeargs} #{autofile}"

    if autodetect or autocrop
      append = "#{append} `#{encodeargs} #{autofile}`".strip
    end
  end

  ### TRANSCODE
  puts "Transcoding..."
  (1..passes).each { |pass|
    ## Set transcode parameters
    # Video
    video = "-ovc x264"

    # Video options
    ## X264
    votag = "-x264encopts"
    if !iphone
      vopts = [ "8x8dct", "bframes=5", "b_pyramid", "weight_b", "qcomp=0.8", "threads=auto", "trellis=1", "psnr" ]
      vopts += [ "bitrate=#{bitrate}" ]
      if !twopass
        vopts += [ "subq=7", "me=umh", "frameref=6", "trellis=2" ] # "pass=1", or not # We'll have this save statistics for -S use
      elsif pass == 1
        vopts += [ "subq=1", "me=dia", "frameref=1", "pass=1", "turbo=2" ]
      elsif pass == 2
        vopts += [ "subq=6", "me=hex", "frameref=4", "pass=2" ]
      end

      if interlaced
        vopts += [ "interlaced" ]
      else
        vopts += [ "nointerlaced" ]
      end

      # Audio
      if !twopass
        #audio = "-oac lavc"
        audio = "-oac mp3lame"
      elsif pass == 1
        audio = "-oac copy"
      elsif pass == 2
        audio = "-oac mp3lame"
        #audio = "-oac lavc"
      end

      # Audio options
      aotag = "-lameopts"
      aopts = [ "preset=extreme" ]

      append.chomp!

      cmdpieces = Array.new
      cmdpieces.push mencoder
      cmdpieces.push video
      cmdpieces.push votag + " " + vopts.join(":")
      cmdpieces.push audio
      cmdpieces.push aotag + " " + aopts.join(":")
      cmdpieces.push append if !append.nil? and append.length > 0
      cmdpieces.push infile
      cmdpieces.push "-o" 
      if !twopass
        cmdpieces.push outfile
      elsif pass == 1
        cmdpieces.push twofile
      else
        cmdpieces.push outfile
      end
    else
      vopts = [ "vbv_maxrate=768", "vbv_bufsize=244", "nocabac", "level_idc=13", "psnr" ]
      # vopts += [ "bframes=5", "b_pyramid", "weight_b", "qcomp=0.8", "threads=auto", "trellis=1", "psnr" ]
      vopts += [ "bitrate=#{bitrate}" ]
      if !twopass
        vopts += [ "subq=7", "me=umh", "frameref=6", "trellis=2" ] # "pass=1", or not # We'll have this save statistics for -S use
      elsif pass == 1
        vopts += [ "subq=1", "me=dia", "frameref=1", "pass=1", "turbo=2" ]
      elsif pass == 2
        vopts += [ "subq=6", "me=hex", "frameref=4", "pass=2" ]
      end

      append = "#{append} -vf-add scale=480:-2,expand=480:320"

      if interlaced
        vopts += [ "interlaced" ]
      else
        vopts += [ "nointerlaced" ]
      end

      # Audio
      if !twopass
        audio = "-oac faac"
      elsif pass == 1
        audio = "-oac copy"
      elsif pass == 2
        audio = "-oac faac"
      end

      # Audio options
      aotag = "-faacopts"
      aopts = [ "mpeg=4", "object=2" ]
      aopts += [ "br=#{abitrate}" ]
      aappend = [ "-channels 2", "-srate 48000" ]

      append.chomp!

      cmdpieces = Array.new
      cmdpieces.push mencoder
      cmdpieces.push video
      cmdpieces.push votag + " " + vopts.join(":")
      cmdpieces.push audio
      cmdpieces.push aotag + " " + aopts.join(":")
      cmdpieces.push aappend.join(" ")
      cmdpieces.push append if !append.nil? and append.length > 0
      cmdpieces.push infile
      cmdpieces.push "-o" 
      if !twopass
        cmdpieces.push outfile
      elsif pass == 1
        cmdpieces.push twofile
      else
        cmdpieces.push outfile
      end
    end

    # Logging
    cmdpieces.push "2>&1"     # redirect stderr to stdout
    cmdpieces.push "|"        # redirect stdout to stdin of logging processes
    cmdpieces.push "tee"      # redirect stdin to stdout and file
    cmdpieces.push "-a"       # if it's the second pass, append it
    cmdpieces.push logfile    # send the output to both the screen and the file

    command = cmdpieces.join(" ")

    unless skipfirst and pass == 1 and twopass
      cmddesc.push "Pass #{pass}"
      commands.push command
    end

    if (!twopass or pass == 2) and iphone
      filebase = chgext(outfile, nil)
      ofps = "`#{encodeargs} -f #{autofile}`"

      cmddesc.push "Extract raw audio"
      commands.push "#{mp4box} -aviraw audio #{outfile} >/dev/null"
      cmddesc.push "Extract raw video"
      commands.push "#{mp4box} -aviraw video #{outfile} >/dev/null"

      cmddesc.push "Moving raw audio"
      commands.push "mv #{filebase}_audio.raw #{filebase}.aac"
      cmddesc.push "Moving raw video"
      commands.push "mv #{filebase}_video.h264 #{filebase}.h264"

      cmddesc.push "Import audio to output file"
      commands.push "#{mp4box} -add #{filebase}.aac:lang=en #{filebase}.m4v"
      cmddesc.push "Import video to output file"
      commands.push "#{mp4box} -add #{filebase}.h264:fps=#{ofps} #{filebase}.m4v"
    end

    ## [x264]
    #oac=lavc
    ##lavcopts=acodec=mp3
    #lavcopts=acodec=ac3
    ##channels=6
    #ovc=x264
    ##vf=scale=640:480
    #af=volume=5
    #x264encopts=bitrate=1000:subq=6:8x8dct=yes:me=dia:frameref=2:bframes=3:weight_b=yes:qcomp=0.8:pass=2:threads=2:trellis=1
    ## [x264-fp]
    #profile=x264
    #oac=copy
    #x264encopts=bitrate=1000:subq=1:8x8dct=yes:me=dia:frameref=1:bframes=3:weight_b=yes:qcomp=0.8:pass=1:threads=2:trellis=1:turbo=2
    ## [x264-hq]
    #oac=lavc
    #lavcopts=acodec=ac3
    #ovc=x264
    #x264encopts=bitrate=1200:subq=7:8x8dct=yes:me=hex:frameref=5:bframes=3:weight_b=yes:qcomp=0.8:pass=2:threads=2:trellis=2
    ## [x264-hq-fp]
    #profile=x264-hq
    #oac=copy
    #x264encopts=bitrate=1200:subq=2:frameref=1:pass=1:turbo=2:threads=2:trellis=2
  }
end

confirm_or_abort if confirm

Kernel.system("echo \'#{cmdline.gsub(/'/,"")}' >> #{logfile}")
Kernel.system("echo \"#####################\" >> #{logfile}") unless pretend
commands.each_index { |idx|
  cmd = commands[idx]
  desc = cmddesc[idx]
  if pretend
    puts "# #{desc}"
    puts "#{cmd}"
  else
    puts "Executing:"
    puts "(#{desc})# #{cmd}"
    Kernel.system("echo \"##### (#{desc}) DATE: `date`\" >> #{logfile}")
    Kernel.system(cmd)
    if $? != 0
      puts "[[ Terminated with status: #{$?} ]]"
      break
    end
  end
}
Kernel.system("echo \"##### RUN COMPLETED AT: `date`\" >> #{logfile}")
