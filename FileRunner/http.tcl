# $Id: http.tcl,v 1.1 2006/07/09 10:10:12 butz Exp $

proc HTTP_Get { URL filename } {
  set r [HTTP_Config]
  if {$r} { 
    return
  }
  HTTP_Get_ $URL $filename 0
}

proc HTTP_Get_ { URL filename iter } {
  global glob

  set r [catch {open $filename w} fid]
  if {$r} {
    PopError $fid
    return
  }

  fconfigure $fid -translation binary

  set glob(http,filename) $filename
  set glob(http,fid) $fid

  LogStatusOnly "Transfer $filename : Contacting..."

  set glob(http,tl) {}
  for {set i 0} {$i < 30} {incr i} {
    lappend glob(http,tl) {0 -1}
  }
  set glob(http,chunk) 1

  set oldicon [wm iconname .]
  set glob(http,t_one) [ClockMilliSeconds]
  set time1 [clock seconds]
  set time1_ms [ClockMilliSeconds]
  set r [catch {::http::geturl $URL -handler HTTP_Handler} token]
  set time2 [clock seconds]
  set time2_ms [ClockMilliSeconds]
  close $fid
  wm iconname . $oldicon
  if {$r} {
    PopError $token
    return
  }

  upvar #0 $token state

#  puts "Metadata:"
#  foreach {name value} $state(meta) {
#    puts [format "%s %s" $name: $value]
#  }

  foreach {name value} $state(meta) {
    if {[regexp -nocase ^location$ $name]} {
      # Handle URL redirects
      # puts "Redirect: Location: $value"
      incr iter
      if {$iter > 10} {
        PopError "Maximum number of HTTP redirects reached. Loop suspected..."
        return
      }
      HTTP_Get_ [string trim $value] $filename $iter
      return 
    }
  }

  if {$state(totalsize) != 0} {
    set total $state(totalsize)
    if {$state(currentsize) != $state(totalsize)} {
      PopWarn "Source $URL and destination $filename are not the same length"
    }
  } else {
    set total ?
  }
  
  if {($time2_ms - $time1_ms) != 0} {
    if {($time2 - $time1) < 1000} {
      set diff [expr ($time2_ms - $time1_ms)/1000.0]
    } else {
      set diff [expr $time2 - $time1]
    }
    set speed [format "%.2f" [expr $state(currentsize)/(1024.0 * $diff)]]
  } else {
    set speed ?
  }
  Log "Transfer $filename : $state(currentsize) / $total bytes -- done ($speed kB/s)"
  LogSilent "Transfer $URL to $filename : $state(currentsize) / $total bytes -- done ($speed kB/s)"
}


proc HTTP_Config {} {
  global config
  if {$config(http,proxy) != ""} {
    set r [regexp {(.*):([0-9]*)} $config(http,proxy) match host port]
    if {!$r} {
      PopError "Cannot parse $config(http,proxy) as proxyhost:port"
      return 1
    }
    ::http::config -proxyhost $host -proxyport $port
  }
  return 0
}

proc HTTP_Handler { socket token } {
  global glob config
  upvar #0 $token state
  set chunksize 4096
  set goal_upd_length 2000
  # That's 2000 milliseconds, by the way...

  if {[fconfigure $socket -translation] != "binary"} {
    fconfigure $socket -translation binary
  }
  set size $state(currentsize)

  set timesum 0.0
  set bytesum 0
  foreach tli $glob(http,tl) {
    if { [lindex $tli 1] != -1 } {
      set timesum [expr $timesum + [lindex $tli 0]]
      incr bytesum [lindex $tli 1]
    }
  }
  if { $timesum <= 0.0 } { set timesum 1.0 }
  set speed [format "%.2f" [expr ($bytesum / ($timesum / 1000.0)) / 1024.0]]
  set speed_Bps [expr ($bytesum / ($timesum / 1000.0))]
  set eta "?"
  set eta_abs "?"
  if {$speed_Bps > 0} {
    set tmp [format "%.0f" [expr ($state(totalsize) - $size) / $speed_Bps]]
    if { $tmp >= 0 } { 
      set eta [format "%02d:%02d" [expr $tmp / 60] [expr $tmp % 60]] 
      if { $config(dateformat) == "yymmdd" } {
        set tmp_date "%y%m%d "
      } else {
        set tmp_date "%y%m%d "
      } 
      set tmp_s [clock seconds]
      if { [clock format [expr $tmp_s + $tmp] -format "%y%m%d"] == [clock format $tmp_s -format "%y%m%d"] } {
        set tmp_date ""
      }
      set eta_abs [clock format [expr $tmp_s + $tmp] -format "$tmp_date%R"]
    }
  }
  if {$state(totalsize) > 0} {
    LogStatusOnly "Transfer $glob(http,filename) : $size / $state(totalsize) bytes ($speed kB/s, ETA $eta $eta_abs)"
  } else {
    LogStatusOnly "Transfer $glob(http,filename) : $size bytes ($speed kB/s)"
  }
  wm iconname . "$eta $eta_abs $glob(http,filename)"
  update idletasks
#  if { $glob(abortcmd) } {
#    set glob(abortcmd) 0
#    close $socket
#    error "Transfer aborted"
#  }
  set i [fcopy $socket $glob(http,fid) -size [expr $glob(http,chunk) * $chunksize]]
  set glob(http,t_two) [ClockMilliSeconds]
  set t [expr $glob(http,t_two) - $glob(http,t_one)]
  if {$t < 0} {
    set t 0
  }
  set glob(http,t_one) $glob(http,t_two)
  if {$i == 0} {
    return 0
  }
  lappend glob(http,tl) "$t [expr $glob(http,chunk) * $chunksize]"
  set glob(http,tl) [lrange $glob(http,tl) 1 end]
  set glob(http,oldchunk) $glob(http,chunk)
  if {$t == 0} {
    set glob(http,chunk) [expr 2 * $glob(http,oldchunk)]
  } else {
    set glob(http,chunk) [expr int(($glob(http,oldchunk) * $goal_upd_length) / $t)]
  }
  set glob(http,chunk) [Clamp [expr $glob(http,oldchunk) / 2] $glob(http,chunk) [expr 2 * $glob(http,oldchunk)]]
  set glob(http,chunk) [Clamp 1 $glob(http,chunk) 900]

  return $i
}


proc Clamp { min x max } {
  if { $x < $min } { set x $min }
  if { $x > $max } { set x $max }
  return $x
}

