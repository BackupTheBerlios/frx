# $Id: ftp.tcl,v 1.1 2006/07/09 10:10:09 butz Exp $


# --------- API commands 
proc FTP_OpenSession { ftpI host_and_port user password realhost} {
  global ftp

  set ftp($ftpI,realhost) $realhost
  set ftp($ftpI,user) $user
  set ftp($ftpI,password) $password
  set ftp($ftpI,state) initial
  set ftp($ftpI,type) unknown
  set ftp($ftpI,ctl_fd) 0
  set ftp($ftpI,server_fd) 0
  set ftp($ftpI,debug) 0
  set ftp($ftpI,local_ip) ""
  set ftp($ftpI,pwd) ""
  set ftp($ftpI,new_wd) ""
  set ftp($ftpI,ctl_mess) ""
  set ftp($ftpI,ctl_cmd) ""
  set ftp($ftpI,resume) 0
  set r [regexp {([^:]+)(:([0-9]+))?} $host_and_port match ftp($ftpI,host) dummy ftp($ftpI,port)]
  if {!$r} {
    FTP_Error $ftpI "Malformed FTP URL $host_and_port. Format: site:port ex: ftp.foo.bar:21"
  }
  if {$ftp($ftpI,port) == ""} {
    set ftp($ftpI,port) 21
  }

  FTP_CtlAutomata $ftpI
  #FTP_CD $ftpI /
}

proc FTP_MakeSureLinkIsUp { ftpI } {
  # Can only be called after FTP_SetHost has been called 
  global ftp
  if { $ftp($ftpI,state) == "initial" } {
    Log "Reopening FTP link to $ftp($ftpI,realhost)"
    FTP_CtlAutomata $ftpI
    #FTP_CD $ftpI /
  }
}

proc FTP_TrimDir { dir } {
  while { [string range $dir 0 1] == "//" } {
    set dir [string range $dir 1 end]
  }
  set dir [string trimright $dir /]
  if { $dir == "" } { set dir / }
  if { [string index $dir 0] == "/" } {
    while { 1 } {
      set len [string length $dir]
      if { [string range $dir [expr $len - 3] end] == "/.." } {
        set dir [file dirname [file dirname $dir]]
      } else {
        break
      }
    }
  }
  return $dir
}

proc FTP_CD { ftpI new_wd } {
  global ftp
  if {[string index $new_wd 0] != "/"} {
    FTP_Error $ftpI "Internal error: FTP_CD can only be called with an absolute path."
  }
  FTP_MakeSureLinkIsUp $ftpI
  set new_wd [FTP_TrimDir $new_wd]
  if { $new_wd == $ftp($ftpI,pwd) } {
    return ""
  }
  set ftp($ftpI,new_wd) $new_wd
  set ftp($ftpI,state) docd
  FTP_CtlAutomata $ftpI
}

proc FTP_Rename { ftpI oldname newname } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,rename,oldname) $oldname
  set ftp($ftpI,rename,newname) $newname
  set ftp($ftpI,state) rename
  FTP_InvalidateCache
  FTP_CtlAutomata $ftpI
}

proc FTP_Delete { ftpI filename } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,delete,filename) $filename
  set ftp($ftpI,state) delete
  FTP_InvalidateCache
  FTP_CtlAutomata $ftpI
}

proc FTP_MkDir { ftpI dir } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,mkdir,dir) $dir
  set ftp($ftpI,state) mkdir
  FTP_InvalidateCache
  FTP_CtlAutomata $ftpI
}

proc FTP_RmDir { ftpI dir } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,rmdir,dir) $dir
  set ftp($ftpI,state) rmdir
  FTP_InvalidateCache
  FTP_CtlAutomata $ftpI
}

proc FTP_IsDir { ftpI new_wd } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set new_wd [FTP_TrimDir $new_wd]
  set ftp($ftpI,new_wd) $new_wd
  set ftp($ftpI,state) isdir
  return [FTP_CtlAutomata $ftpI]
}

proc FTP_PWD { ftpI } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,state) dopwd
  return [FTP_CtlAutomata $ftpI]
}

proc FTP_CloseSession { ftpI } {
  global ftp

# Just shut down the sockets
  FTP_ShutDown $ftpI
  return

# This is slow...
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,state) closing
  FTP_CtlAutomata $ftpI
}

proc FTP_List { ftpI showall } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  LogStatusOnly "Reading ftp directory $ftp($ftpI,realhost)$ftp($ftpI,pwd)"
  set cache_result [FTP_ReadCache $ftp($ftpI,realhost)$ftp($ftpI,pwd)]
  if {$cache_result != ""} {
    LogStatusOnly "Reading ftp directory $ftp($ftpI,realhost)$ftp($ftpI,pwd) -- done (found in cache)"
    return $cache_result
  }
  set ftp($ftpI,state) listing
  set ftp($ftpI,fileshow,all) $showall
  set result [FTP_CtlAutomata $ftpI]
  FTP_WriteCache $ftp($ftpI,realhost)$ftp($ftpI,pwd) $result
  LogStatusOnly "Reading ftp directory $ftp($ftpI,realhost)$ftp($ftpI,pwd) -- done"
  return $result
}

proc FTP_DoSearch { ftpI filename } {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,state) search
  set ftp($ftpI,search,name) $filename
  return [FTP_CtlAutomata $ftpI]
}

proc FTP_GetFile { ftpI remoteFileName localFileName expectedSize {resume 0}} {
  global ftp
  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,state) getfile

  if { [string range $remoteFileName 0 1] == "//" } {
    set remoteFileName [string range $remoteFileName 1 end]
  }
  if { [string range $localFileName 0 1] == "//" } {
    set localFileName [string range $localFileName 1 end]
  }

  set ftp($ftpI,remote_fname) $remoteFileName
  set ftp($ftpI,local_fname) $localFileName
  set ftp($ftpI,expected_size) $expectedSize
  set ftp($ftpI,resume) 0
  if { $resume && [file writable "$localFileName"] } {
    set r [catch {set ftp($ftpI,resume,pos) [file size "$localFileName"]}]
    set ftp($ftpI,resume) [expr !$r]
  }
  return [FTP_CtlAutomata $ftpI]
}

proc FTP_PutFile { ftpI localFileName remoteFileName expectedSize } {
  global ftp

  #FTP_CD $ftpI [file dirname $remoteFileName]

  if { [string range $remoteFileName 0 1] == "//" } {
    set remoteFileName [string range $remoteFileName 1 end]
  }
  if { [string range $localFileName 0 1] == "//" } {
    set localFileName [string range $localFileName 1 end]
  }

  FTP_MakeSureLinkIsUp $ftpI
  set ftp($ftpI,state) putfile

  set ftp($ftpI,remote_fname) $remoteFileName
  set ftp($ftpI,local_fname) $localFileName
  set ftp($ftpI,expected_size) $expectedSize
  FTP_InvalidateCache
  return [FTP_CtlAutomata $ftpI]
}

proc FTP_InvalidateCache {} {
  global ftp
  set ftp(cache) ""
}


# ----------- Helper functions

proc FTP_CtlAutomata { ftpI } {
  global ftp

  set ret ""
  while { 1 } {
    if { $ftp($ftpI,debug) } {
      puts "--$ftp($ftpI,state)"
    }
    switch $ftp($ftpI,state) {
      initial {
        # Initiating and logging in
        # Open control connection to ftp server
        set r [catch {FTP_Socket $ftp($ftpI,host) $ftp($ftpI,port)} tmp]
        if { $r != 0 } {
          FTP_Error $ftpI $tmp
        }
        set ftp($ftpI,ctl_fd) [lindex $tmp 0]
        set ftp($ftpI,local_ip) [lindex $tmp 1]
        #set ftp($ftpI,port_cmd) [FTP_SetupDatareceiver $ftpI] #Let's do this for every connection instead...
        set ftp($ftpI,state) ctl_open
      }
      ctl_open {
        if { $ctl_code0 == "2" } {
          FTP_WriteControl $ftpI "USER $ftp($ftpI,user)"
          set ftp($ftpI,state) user_sent
        } else {
          FTP_Error $ftpI "Error connecting"
        }
      }
      user_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } elseif { $ctl_code0 == "3" } {
          FTP_WriteControl $ftpI "PASS $ftp($ftpI,password)"
          set ftp($ftpI,state) password_sent
        } else {
          FTP_Error $ftpI "Error connecting"
        }
      }
      password_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Error $ftpI "Error connecting"
        }
      }
      closing {
        # closing down
        FTP_WriteControl $ftpI "QUIT"
        set ftp($ftpI,state) quit_sent
      }
      quit_sent {
        FTP_ShutDown $ftpI
        set ftp($ftpI,state) ready
      }
      listing {
        # listing
        if { $ftp($ftpI,type) != "A" } {
          FTP_WriteControl $ftpI "TYPE A"
          set ftp($ftpI,type)  A
          set ftp($ftpI,state) listing_type_sent
        } else {
          FTP_WriteControl $ftpI [FTP_SetupDatareceiver $ftpI]
          set ftp($ftpI,state) listing_port_sent
        }
      }
      listing_type_sent {
        if { $ctl_code0 == "2" } {
          FTP_WriteControl $ftpI [FTP_SetupDatareceiver $ftpI]
          set ftp($ftpI,state) listing_port_sent
        } else {
          FTP_Error $ftpI "Error changing to ascii mode"
        }
      }
      listing_port_sent {
        if { $ctl_code0 == "2" } {
          if {$ftp($ftpI,fileshow,all)} {
            FTP_WriteControl $ftpI "LIST -a"
          } else {
            FTP_WriteControl $ftpI "LIST"
          }
          set ftp($ftpI,state) listing_list_sent
        } else {
          FTP_Error $ftpI "Error setting receive port"
        }
      }
      listing_list_sent {
        if { $ctl_code0 == "1" } {
          set ret [FTP_ReadDataAsList $ftpI]
          if { $ftp($ftpI,debug) } {
            puts "$ret"
          }
          set ftp($ftpI,state) listing_list_received
        } else {
          FTP_Error $ftpI "Error listing"
        }
      }
      listing_list_received {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Error $ftpI "Error receiving list"
        }
      }
      docd {
        FTP_WriteControl $ftpI "CWD $ftp($ftpI,new_wd)"
        set ftp($ftpI,state) docd_cd_sent
      }
      docd_cd_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,pwd) $ftp($ftpI,new_wd)
          set ftp($ftpI,state) ready
        } elseif { $ctl_code == "421" } {
          FTP_Error $ftpI "Error cd'ing to $ftp($ftpI,new_wd)"
        } else {
          FTP_Warn $ftpI "Error cd'ing to $ftp($ftpI,new_wd)"
        }
      }
      dopwd {
          FTP_WriteControl $ftpI "PWD"
          set ftp($ftpI,state) dopwd_pwd_sent
      }
      dopwd_pwd_sent {
        if { $ctl_code0 == "2" } {
          set r [regexp {[0-9]+ "(.*)"} $ctl_mess match new_pwd]
          if { !$r } { FTP_Error $ftpI "Error parsing current directory ($ctl_mess)" }
          set ftp($ftpI,pwd) $new_pwd
          set ftp($ftpI,state) ready
          set ret $new_pwd
        } else {
          FTP_Error $ftpI "Error retreiving present working directory"
        }
      }
      isdir {
        FTP_WriteControl $ftpI "CWD $ftp($ftpI,new_wd)"
        set ftp($ftpI,state) isdir_cd_sent
      }
      isdir_cd_sent {
        if { $ctl_code0 == "2" } {
          set ret 1
        } else {
          set ret 0
        }
        set ftp($ftpI,pwd) ""
        set ftp($ftpI,state) ready
      }
      getfile {
        # retreiving file
        if { $ftp($ftpI,type) != "I" } {
          FTP_WriteControl $ftpI "TYPE I"
          set ftp($ftpI,type)  I
          set ftp($ftpI,state) getfile_type_sent
        } else {
          FTP_WriteControl $ftpI [FTP_SetupDatareceiver $ftpI]
          set ftp($ftpI,state) getfile_port_sent
        }
      }
      getfile_type_sent {
        if { $ctl_code0 == "2" } {
          FTP_WriteControl $ftpI [FTP_SetupDatareceiver $ftpI]
          set ftp($ftpI,state) getfile_port_sent
        } else {
          FTP_Error $ftpI "Error changing to binary mode"
        }
      }
      getfile_port_sent {
        if { $ctl_code0 == "2" } {
          if { $ftp($ftpI,resume) } {
            FTP_WriteControl $ftpI "REST $ftp($ftpI,resume,pos)"
            set ftp($ftpI,state) getfile_rest_sent
          } else {
            FTP_WriteControl $ftpI "RETR $ftp($ftpI,remote_fname)"
            set ftp($ftpI,state) getfile_retr_sent
          }
        } else {
          FTP_Error $ftpI "Error setting receive port"
        }
      }
      getfile_rest_sent {
        if { $ctl_code0 == "3" } {
          FTP_WriteControl $ftpI "RETR $ftp($ftpI,remote_fname)"
          set ftp($ftpI,state) getfile_retr_sent
        } else {
          FTP_Warn $ftpI "Server does not support resume on FTP transfers."
        }
      }
      getfile_retr_sent {
        if { $ctl_code0 == "1" } {
          if { $ftp($ftpI,resume) } {
            set ret [FTP_TransferFile $ftpI w+]
          } else {
            set ret [FTP_TransferFile $ftpI w]
          }
          set ftp($ftpI,state) getfile_file_received
        } else {
          FTP_Error $ftpI "Error retrieving remote file $ftp($ftpI,remote_fname)"
        }
      }
      getfile_file_received {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Error $ftpI "Error receiving remote file $ftp($ftpI,remote_fname)"
        }
      }
      putfile {
        # sending file
        if { $ftp($ftpI,type) != "I" } {
          FTP_WriteControl $ftpI "TYPE I"
          set ftp($ftpI,type)  I
          set ftp($ftpI,state) putfile_type_sent
        } else {
          FTP_WriteControl $ftpI [FTP_SetupDatareceiver $ftpI]
          set ftp($ftpI,state) putfile_port_sent
        }
      }
      putfile_type_sent {
        if { $ctl_code0 == "2" } {
          FTP_WriteControl $ftpI [FTP_SetupDatareceiver $ftpI]
          set ftp($ftpI,state) putfile_port_sent
        } else {
          FTP_Error $ftpI "Error changing to binary mode"
        }
      }
      putfile_port_sent {
        if { $ctl_code0 == "2" } {
          FTP_WriteControl $ftpI "STOR $ftp($ftpI,remote_fname)"
          set ftp($ftpI,state) putfile_stor_sent
        } else {
          FTP_Error $ftpI "Error setting port"
        }
      }
      putfile_stor_sent {
        if { $ctl_code0 == "1" } {
          set ret [FTP_TransferFile $ftpI r]
          set ftp($ftpI,state) putfile_file_sent
        } else {
          FTP_Error $ftpI "Error storing file $ftp($ftpI,remote_fname)"
        }
      }
      putfile_file_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Error $ftpI "Error storing file $ftp($ftpI,remote_fname)"
        }
      }
      rename {
        FTP_WriteControl $ftpI "RNFR $ftp($ftpI,rename,oldname)"
        set ftp($ftpI,state) rename_rnfr_sent
      }
      rename_rnfr_sent {
        if { $ctl_code0 == "3" } {
          FTP_WriteControl $ftpI "RNTO $ftp($ftpI,rename,newname)"
          set ftp($ftpI,state) rename_rnto_sent
        } else {
          FTP_Warn $ftpI "Error renaming file $ftp($ftpI,rename,oldname) to $ftp($ftpI,rename,newname)"
        }
      }
      rename_rnto_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Warn $ftpI "Error renaming file $ftp($ftpI,rename,oldname) to $ftp($ftpI,rename,newname)"
        }
      }
      delete {
        FTP_WriteControl $ftpI "DELE $ftp($ftpI,delete,filename)"
        set ftp($ftpI,state) delete_dele_sent
      }
      delete_dele_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Warn $ftpI "Error deleting file $ftp($ftpI,delete,filename)"
        }
      }
      mkdir {
        FTP_WriteControl $ftpI "MKD $ftp($ftpI,mkdir,dir)"
        set ftp($ftpI,state) mkdir_mkd_sent
      }
      mkdir_mkd_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Warn $ftpI "Error creating dir $ftp($ftpI,mkdir,dir)"
        }
      }
      rmdir {
        FTP_WriteControl $ftpI "RMD $ftp($ftpI,rmdir,dir)"
        set ftp($ftpI,state) rmdir_rmd_sent
      }
      rmdir_rmd_sent {
        if { $ctl_code0 == "2" } {
          set ftp($ftpI,state) ready
        } else {
          FTP_Warn $ftpI "Error deleting dir $ftp($ftpI,rmdir,dir) (not empty?)"
        }
      }
      search {
        FTP_WriteControl $ftpI "SITE EXEC LOCATE $ftp($ftpI,search,name)"
        set ftp($ftpI,state) search_locate_sent
      }
      search_locate_sent {
        if { $ctl_code0 == "2" } {
          set ret $ftp($ftpI,ctl_mess)
          set ftp($ftpI,state) ready
        } else {
          FTP_Warn $ftpI "Error searching for $ftp($ftpI,search,name)"
        }
      }
      default {
        FTP_Error $ftpI "Unhandled state in ftp automata"
      }
    }
    if { $ftp($ftpI,state) == "ready" } {
      if { $ftp($ftpI,debug) } {
        puts "++ready"
      }
      break
    }
    FTP_ReadControl $ftpI ctl_mess ctl_code ctl_code0 ctl_code1 ctl_code2
    set ftp($ftpI,ctl_mess) $ctl_mess
    if {$ctl_mess == ""} {
      FTP_Error $ftpI "Error reading ftp control socket"
    }
  }
  return $ret
}

proc FTP_Error { ftpI message } {
  global ftp
  set m "$message\n\nHost: $ftp($ftpI,realhost)\nState: $ftp($ftpI,state)\n\Command: $ftp($ftpI,ctl_cmd)\nMessage: $ftp($ftpI,ctl_mess)"
  FTP_ShutDown $ftpI
  error "$m"
}

proc FTP_Warn { ftpI message } {
  global ftp
  set m "$message\n\nHost: $ftp($ftpI,realhost)\nState: $ftp($ftpI,state)\n\Command: $ftp($ftpI,ctl_cmd)\nMessage: $ftp($ftpI,ctl_mess)"
  set ftp($ftpI,state) ready
  error "$m"
}

proc FTP_WarnLite { ftpI message } {
  global ftp
  set m "$message\n\nHost: $ftp($ftpI,realhost)\nState: $ftp($ftpI,state)\n\Command: $ftp($ftpI,ctl_cmd)\nMessage: $ftp($ftpI,ctl_mess)"
  #set ftp($ftpI,state) ready
  PopWarn "$m"
}

proc FTP_ReadControl { ftpI var_ctl_mess var_ctl_code var_ctl_code0 var_ctl_code1 var_ctl_code2 } {
  global ftp config

  upvar $var_ctl_mess ctl_mess
  upvar $var_ctl_code ctl_code
  upvar $var_ctl_code0 ctl_code0
  upvar $var_ctl_code1 ctl_code1
  upvar $var_ctl_code2 ctl_code2

  set ctl_mess ""
  set code 0

  while { 1 } {
    set r [catch {FTP_ReadText $ftp($ftpI,ctl_fd) $config(ftp,timeout)} line]
    if {$r} {FTP_Error $ftpI $line}
    set count [string length $line]
    if { $count == 0 } { 
      set ctl_mess ""
      break
    } else {
      set incode [string range $line 0 2]
      set contcode [string index $line 3]
      append ctl_mess $line
      if { $code == 0 } {
        if { $contcode == "-" } {
          set code $incode
        } else {
          set code $incode
          break
        }
      } else {
        if { $incode == $code && $contcode == " " } {
          break
        }
      }
    }
  }
  set ctl_code $code
  set ctl_code0 [string index $code 0]
  set ctl_code1 [string index $code 1]
  set ctl_code2 [string index $code 2]
  if { $ftp($ftpI,debug) } {
    puts "$ctl_mess"
  }
}


proc FTP_ShutDown { ftpI } {
  global ftp
  if { $ftp($ftpI,server_fd) != 0 } {
    catch { FTP_Close $ftp($ftpI,server_fd) } out
    set ftp($ftpI,server_fd) 0
  }
  if { $ftp($ftpI,ctl_fd) != 0 } {
    catch { FTP_Close $ftp($ftpI,ctl_fd) } out
    set ftp($ftpI,ctl_fd) 0
  }
#  set ftp($ftpI,host) ""
#  set ftp($ftpI,realhost) ""
#  set ftp($ftpI,user) ""
#  set ftp($ftpI,password) ""
  set ftp($ftpI,state) initial
  set ftp($ftpI,type) unknown
  set ftp($ftpI,ctl_fd) 0
  set ftp($ftpI,server_fd) 0
#  set ftp($ftpI,debug) 0
  set ftp($ftpI,local_ip) ""
  set ftp($ftpI,pwd) ""
  set ftp($ftpI,new_wd) ""
  set ftp($ftpI,ctl_mess) ""
  set ftp($ftpI,ctl_cmd) ""
  set ftp($ftpI,resume) 0
}

proc FTP_WriteControl { ftpI output } {
  global ftp
  set ftp($ftpI,ctl_cmd) "$output"
  set r [catch {FTP_WriteText $ftp($ftpI,ctl_fd) "$output\r\n"} out]
  if {$r} {FTP_Error $ftpI $out}
  if { $ftp($ftpI,debug) } {
    puts ">> $output"
  }
}

proc FTP_ConvPortToNums { portnum } {
  return [expr ($portnum & 0xff00) >> 8],[expr $portnum & 0xff]
}

proc FTP_SetupDatareceiver { ftpI } {
  global ftp
  if { $ftp($ftpI,server_fd) != 0 } {
    catch { FTP_Close $ftp($ftpI,server_fd) } out
    set ftp($ftpI,server_fd) 0
  }
  set r [catch {FTP_CreateServerSocket $ftp($ftpI,local_ip)} t]
  if {$r} {FTP_Error $ftpI $t}
  regexp {([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+),([0-9]+) (.+)} $t match a1 a2 a3 a4 p ftp($ftpI,server_fd)
  return "PORT $a1,$a2,$a3,$a4,[FTP_ConvPortToNums $p]"
}

# separate input lines to list elements 
proc FTP_ReadDataAsList { ftpI } {
  global ftp config
  set r [catch {FTP_AcceptConnect $ftp($ftpI,server_fd)} datafd]
  if {$r} {FTP_Error $ftpI $datafd}
  set list {}
  while { 1 } {
    set r [catch {FTP_ReadText $datafd $config(ftp,timeout)} line]
    if {$r} {
      FTP_Close $datafd
      FTP_Error $ftpI $line
    }
    lappend list "$line"
    if {$line == ""} {
      FTP_Close $datafd
      return $list
    }
  }
}


proc FTP_TransferFile { ftpI mode } {
  global ftp config glob
  set oldiconname [wm iconname .]
  set chunk 1
  set chunksize 4096
  set goal_upd_length 2000
  # That's 2000 milliseconds, by the way... (I hate myself for not commenting more...:-)
  set r [catch {FTP_OpenFile $ftp($ftpI,local_fname) $mode} fd1]
  if {$r} {FTP_Error $ftpI "$ftp($ftpI,local_fname): $fd1"}
  set r [catch {FTP_AcceptConnect $ftp($ftpI,server_fd)} fd2]
  if {$r} {FTP_Error $ftpI $fd2}

  if {$mode == "r"} {
    set from_fd $fd1
    set to_fd $fd2
  } else {
    set from_fd $fd2
    set to_fd $fd1
  }

  #fconfigure $from_fd -translation binary
  #fconfigure $to_fd -translation binary

  set size 0
  if {$ftp($ftpI,resume)} {
    set size $ftp($ftpI,resume,pos)
  }
  set start_time [clock seconds]
  set tl {}
  for {set i 0} {$i < 30} {incr i} {
    lappend tl {0 -1}
  }

  set t_one [ClockMilliSeconds]
  while { 1 } {
    set timesum 0.0
    set bytesum 0
    set timenum 0
    foreach tli $tl {
      if { [lindex $tli 1] != -1 } {
        set timesum [expr $timesum + [lindex $tli 0]]
        incr bytesum [lindex $tli 1]
        incr timenum
      }
    }
    if { $timesum <= 0.0 } { set timesum 1 }
    set speed [format "%.2f" [expr ($bytesum / ($timesum / 1000.0)) / 1024.0]]
    set speed_Bps [expr ($bytesum / ($timesum / 1000.0))]
    set eta "?"
    set eta_abs "?"
    if {$speed_Bps > 0} {
      set tmp [format "%.0f" [expr ($ftp($ftpI,expected_size) - $size) / $speed_Bps]]
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
    if {$ftp($ftpI,expected_size) > 0} {
      LogStatusOnly "Transfer [file tail $ftp($ftpI,remote_fname)] : $size / $ftp($ftpI,expected_size) bytes ($speed kB/s, ETA $eta $eta_abs)"
    } else {
      LogStatusOnly "Transfer [file tail $ftp($ftpI,remote_fname)] : $size bytes ($speed kB/s)"
    }
    wm iconname . "$eta $eta_abs [file tail $ftp($ftpI,remote_fname)]"
    update
    if { $glob(abortcmd) } {
      wm iconname . "$oldiconname"
      FTP_Close $from_fd
      FTP_Close $to_fd
      FTP_Error $ftpI "FTP transfer aborted, link closed."
    }
    set r [catch {FTP_Copy $from_fd $to_fd [expr $chunk * $chunksize] $config(ftp,timeout)} i]
    set t_two [ClockMilliSeconds]
    set t [expr $t_two - $t_one]
    if {$t < 0} {
      set t 0
    }
    set t_one $t_two
    if {$r} {  
      wm iconname . "$oldiconname"
      FTP_Close $from_fd
      FTP_Close $to_fd
      FTP_Error $ftpI $i
    }
    if {$i == 0} break
    lappend tl "$t [expr $chunk * $chunksize]"
    set tl [lrange $tl 1 end]
    incr size $i
    set oldchunk $chunk
    if {$t == 0} {
      set chunk [expr 2 * $oldchunk]
    } else {
      set chunk [expr int(($oldchunk * $goal_upd_length) / $t)]
    }
    if {$chunk > [expr 2 * $oldchunk]} {set chunk [expr 2 * $oldchunk]}
    if {$chunk < [expr $oldchunk / 2]} {set chunk [expr $oldchunk / 2]}
    if {$chunk > 900} {set chunk 900}
    if {$chunk < 1} {set chunk 1}
  }
  FTP_Close $from_fd
  FTP_Close $to_fd
  set end_time [clock seconds]
  if {$end_time == $start_time} {
    set total_speed "? kB/s"
  } else {
    if {$ftp($ftpI,resume)} {
      set total_speed "[format "%.2f" [expr ($size - $ftp($ftpI,resume,pos)) / 1024.0 / ($end_time - $start_time)]] kB/s"
    } else {
      set total_speed "[format "%.2f" [expr $size / 1024.0 / ($end_time - $start_time)]] kB/s"
    }
  }
  wm iconname . "$oldiconname"
  LogStatusOnly "Transfer [file tail $ftp($ftpI,remote_fname)] : $size bytes -- done ($total_speed)"
  if {$mode == "w" } {
    LogSilent "Transfer ftp://$ftp($ftpI,realhost)$ftp($ftpI,remote_fname) -> $ftp($ftpI,local_fname): $size bytes -- done ($total_speed)"
  } else {
    LogSilent "Transfer $ftp($ftpI,local_fname) -> ftp://$ftp($ftpI,realhost)$ftp($ftpI,remote_fname): $size bytes -- done ($total_speed)"
  }

  if { $mode != "r" && [Try { set s [file size $ftp($ftpI,local_fname)] } "" 1] == 0 } {
    if { $ftp($ftpI,expected_size) > 0 && ($s != $ftp($ftpI,expected_size) || $s != $size) } {
      PopWarn "Warning: Files ftp://$ftp($ftpI,realhost)$ftp($ftpI,remote_fname), $ftp($ftpI,local_fname) are not the same size"
    }
  }
  return $size
}

proc FTP_ReadCache { key } {
  global ftp
  set i 0
  foreach k $ftp(cache) {
    if {[lindex $k 0] == "$key"} {
      set item $k
      set result [lindex $item 1]
      set ftp(cache) [concat [lrange $ftp(cache) 0 [expr $i - 1]] [lrange $ftp(cache) [expr $i + 1] end]]
      lappend ftp(cache) $item
      return [lindex $item 1]
    }
    incr i
  }
  return ""
}

proc FTP_WriteCache { key data } {
  global ftp config
  set item [list $key $data]
  lappend ftp(cache) $item
  set length [llength $ftp(cache)]
  if {$length > $config(ftp,cache,maxentries)} {
    set ftp(cache) [lrange $ftp(cache) 1 end]
  }
}

