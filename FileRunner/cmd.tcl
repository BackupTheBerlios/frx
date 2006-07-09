# $Id: cmd.tcl,v 1.1 2006/07/09 10:09:43 butz Exp $


proc CmdToright {} {
  global glob
  NewPwd right $glob(left,pwd)
  UpdateWindow right
}

proc CmdToleft {} {
  global glob
  NewPwd left $glob(right,pwd)
  UpdateWindow left
}

proc CmdSwapWindows {} {
  global glob
  set tmpleft $glob(right,pwd)
  set tmpright $glob(left,pwd)
  NewPwd left $tmpleft
  NewPwd right $tmpright
  UpdateWindow both 
}

proc BatchReceiveFTP { inst } {
  global glob
  if {[IsFTP $glob($inst,pwd)]} {
    PopInfo "You can only issue a receive request to a non-FTP directory"
    return
  }
  set olddir $glob([Opposite $inst],pwd)
  foreach itemblock $glob(batchlist) {
    set item [lindex $itemblock 0]
    set r [regexp {ftp://([^/]*)(.*)} $item match ftpI elem]
    if {!$r} {
      PopWarn "Can't parse $item as FTP file"
    } else {
      NewPwd [Opposite $inst] ftp://$ftpI/
      set r [Try { FTP_GetFile $ftpI "$elem" "$glob($inst,pwd)/[file tail $elem]" [lindex $itemblock 1] 0 } "" 1]
    }
  }
  set glob(batchlist) {}
  set glob(forceupdate) 1
  NewPwd [Opposite $inst] $olddir
  UpdateWindow both
  set glob(forceupdate) 0
}


proc CmdCopy {{resume 0}} {
  global glob
  if { $glob(left,pwd) == $glob(right,pwd) } {
    tk_dialog .apop "Hey Dimwit!" \
       "Please set different source and destination directories!" "" 0 "OK" 
    return {}
  }    
  CmdCopy_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) left $resume
  CmdCopy_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) right $resume
  UpdateWindow both
  set glob(forceupdate) 0
}

proc CmdCopy_ { listb_name filelist_var frompwd topwd inst resume} {
  # For speed, (hopefully) we'll call by reference...
  global config glob
  upvar $filelist_var filelist


  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Copy"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      fld -
      fd  { 
        if {[IsFTP $topwd]} {
          CantDoThat
          return
        }
        set olddir $glob($inst,pwd)
        set r [Try { CopyFromFTPRecursive "$frompwd/[lindex $elem 1]" "$topwd" $inst $resume } "" 1]
        NewPwd $inst $olddir
        UpdateWindow $inst
      }
      fl  -
      fn  {
        if {[IsFTP $topwd]} {
          CantDoThat
          return
        }
        set r [regexp {ftp://([^/]*)(.*)} $frompwd match ftpI directory]
        if {$r == 0} { 
          PopError "Can't parse $frompwd as ftp URL" 
        } else {
          set size [lindex $elem 3]
          if {[lindex $elem 2] == "fl"} {set size -1}
          if {$glob(async)} {
            catch {exec $glob(lib_fr)/frftp $glob(lib_fr) $config(ftp,timeout) 1 $glob(ftp,$ftpI,host) \
                       $glob(ftp,$ftpI,user) $glob(ftp,$ftpI,passwd) $ftpI "$directory/[lindex $elem 1]" \
                       "$topwd/[lindex $elem 1]" $size $resume &} out
          } else {
            set r [Try { FTP_GetFile $ftpI "$directory/[lindex $elem 1]" "$topwd/[lindex $elem 1]" $size $resume } "" 1]
          }
        }
      }
      l   { 
        Log "Copying $frompwd/[lindex $elem 1] to $topwd"
        set r [regexp {ftp://([^/]*)(.*)} $topwd match ftpI directory]
        if {$r} {
          set glob(forceupdate) 1
          Try { FTP_PutFile $ftpI $frompwd/[lindex $elem 1] $directory/[lindex $elem 1] [lindex $elem 3] } "" 1
        } else {
          if {[CheckWhoOwns $topwd/[lindex $elem 1] overwrite]} {
            Try { exec $config(cmd,cp) $frompwd/[lindex $elem 1] $topwd } "" 1 
          }
        }
      }
      n   { 
        Log "Copying $frompwd/[lindex $elem 1] to $topwd"
        set r [regexp {ftp://([^/]*)(.*)} $topwd match ftpI directory]
        if {$r} {
          set glob(forceupdate) 1
          Try { FTP_PutFile $ftpI $frompwd/[lindex $elem 1] $directory/[lindex $elem 1] [lindex $elem 3] } "" 1
        } else {
          if {[CheckWhoOwns $topwd/[lindex $elem 1] overwrite]} {
            Try { file copy -force -- $frompwd/[lindex $elem 1] $topwd } "" 1 
          }
        }
      }
      d   { 
        if {[IsFTP $topwd]} {
          set olddir $glob($inst,pwd)
          set r [Try { CopyToFTPRecursive "$frompwd/[lindex $elem 1]" "$topwd" $inst } "" 1]
          NewPwd $inst $olddir
          set glob(forceupdate) 1
        } else {
          Log "Copying $frompwd/[lindex $elem 1] to $topwd"
          if {[CheckWhoOwns $topwd/[lindex $elem 1] overwrite]} {
            Try { 
              cd $frompwd
              exec $config(cmd,sh) -c "tar cf - '[lindex $elem 1]' | (cd '$topwd'; tar xfp - )" } "" 1 $glob(async)
          }
        }
      }
      ld  { 
        if {[IsFTP $topwd]} {
          CantDoThat
          return
        }
        Log "Copying $frompwd/[lindex $elem 1] to $topwd"
        if {[CheckWhoOwns $topwd/[lindex $elem 1] overwrite]} {
          Try { 
            cd $frompwd/[lindex $elem 1]
            file mkdir $topwd/[lindex $elem 1]
            exec $config(cmd,sh) -c "tar cf - . | (cd '$topwd/[lindex $elem 1]'; tar xfp - )" } "" 1 $glob(async)
        }
      }
      default CantDoThat
    }
  }
}

proc CmdCopyAs {} {
  global glob
  CmdCopyAs_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdCopyAs_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdCopyAs_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  global config glob
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "CopyAs"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      fl  -
      fn  {
        set destfile [EntryDialog "Copy As..." "Please enter new name for destination file" $topwd/[lindex $elem 1] question]
        if {$destfile != "" } {
          if {[IsFTP $destfile]} {
            CantDoThat
            return
          }
          set r [regexp {ftp://([^/]*)(.*)} $frompwd match ftpI directory]
          if {$r == 0} { 
            PopError "Can't parse $frompwd as ftp URL" 
          } else {
            set size [lindex $elem 3]
            if {[lindex $elem 2] == "fl"} {set size -1}
            if {$glob(async)} {
              catch {exec $glob(lib_fr)/frftp $glob(lib_fr) $config(ftp,timeout) 1 $glob(ftp,$ftpI,host) \
                         $glob(ftp,$ftpI,user) $glob(ftp,$ftpI,passwd) $ftpI "$directory/[lindex $elem 1]" \
                         "$destfile" $size 0 &} out
            } else {
              set r [Try { FTP_GetFile $ftpI "$directory/[lindex $elem 1]" "$destfile" $size 0 } "" 1]
            }
          }
        }
      }
      l   { 
        set destfile [EntryDialog "Copy As..." "Please enter new name for destination file" $topwd/[lindex $elem 1] question]
        if {[IsFTP $destfile]} {
          CantDoThat
          return
        }
        if {$destfile != "" } {
          Log "Copying $frompwd/[lindex $elem 1] to $destfile"
          Try { exec $config(cmd,cp) $frompwd/[lindex $elem 1] $destfile } "" 1  $glob(async)
        }
      }
      n   { 
        set destfile [EntryDialog "Copy As..." "Please enter new name for destination file" $topwd/[lindex $elem 1] question]
        if {[IsFTP $destfile]} {
          CantDoThat
          return
        }
        if {$destfile != "" } {
          Log "Copying $frompwd/[lindex $elem 1] to $destfile"
          Try { file copy -force -- $frompwd/[lindex $elem 1] $destfile } "" 1  $glob(async)
        }
      }
      d   -
      ld  { 
        set destdir [EntryDialog "Copy As..." "Please enter new name for directory after copy" $topwd/[lindex $elem 1] question]
        if {[IsFTP $destdir]} {
          CantDoThat
          return
        }
        if {$destdir != "" } {
          Log "Copying $frompwd/[lindex $elem 1] to $destdir"
          Try { 
            cd $frompwd/[lindex $elem 1]
            file mkdir $destdir
            exec $config(cmd,sh) -c "tar cf - . | (cd '$destdir'; tar xfp - )" } "" 1 $glob(async)
        }
      }
      default CantDoThat
    }
  }
}

proc SoftLink { src dst } {
  global config
  if {$config(create_relative_links)} {
    set srcdir [file dirname $src]
    set dstdir [file dirname $dst]
    set srcfile [file tail $src]
    set dstfile [file tail $dst]
    set dstlist [split $dstdir /]
    set srclist [split $srcdir /]
    set dstlen [llength $dstlist]
    set srclen [llength $srclist]
    # Count how many directories are the same in the source and destination paths
    set index 0
    while {([lindex $srclist $index] == [lindex $dstlist $index]) && ($index < $srclen) && ($index < $dstlen)} {
      incr index
    }
    # Build relative link
    set link {}
    for {set dstindex $index} {$dstindex < $dstlen} {incr dstindex} {
      append link ../
    }
    for {set srcindex $index} {$srcindex < $srclen} {incr srcindex} {
      append link [lindex $srclist $srcindex]/
    }
    set from $link$srcfile

    #puts "$src $dst $srcdir $srcfile $dstdir $dstfile : ln -s $from $dst"
    Try { exec $config(cmd,ln) -s "$from" "$dst" } "" 1 
  } else {
    Try { exec $config(cmd,ln) -s "$src" "$dst" } "" 1 
  }
}

proc CmdSoftLink {} {
  global glob
  if { $glob(left,pwd) == $glob(right,pwd) } {
    tk_dialog .apop "Hey Dimwit!" \
       "Please set different source and destination directories!" "" 0 "OK" 
    return {}
  }    
  if {[IsFTP $glob(left,pwd)] || [IsFTP $glob(right,pwd)]} {
    CantDoThat
    return
  }
  CmdSoftLink_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdSoftLink_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdSoftLink_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  global config
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "SoftLink"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      n   -
      d   -
      l   -
      ld  { 
        Log "Softlinking $frompwd/[lindex $elem 1] to $topwd"
        SoftLink $frompwd/[lindex $elem 1] $topwd/[lindex $elem 1]
      }
      default CantDoThat
    }
  }
}

proc CmdSoftLinkAs {} {
  global glob
  if {[IsFTP $glob(left,pwd)] || [IsFTP $glob(right,pwd)]} {
    CantDoThat
    return
  }
  CmdSoftLinkAs_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdSoftLinkAs_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdSoftLinkAs_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  global config
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "SoftLinkAs"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      n   -
      d   -
      l   -
      ld  {
        set destfile [EntryDialog "Soft-Link As..." "Please enter new name for destination link" $topwd/[lindex $elem 1] question]
        if {[IsFTP $destfile]} {
          CantDoThat
          return
        }
        if {$destfile != "" } {
          Log "Softlinking $frompwd/[lindex $elem 1] to $destfile"
          SoftLink $frompwd/[lindex $elem 1] $destfile
        }
      }
      default CantDoThat
    }
  }
}


proc CmdMove {} {
  global glob
  if { $glob(left,pwd) == $glob(right,pwd) } {
    tk_dialog .apop "Hey Dimwit!" \
       "Please set different source and destination directories!" "" 0 "OK" 
    return {}
  }    
  if {[IsFTP $glob(left,pwd)] || [IsFTP $glob(right,pwd)]} {
    CantDoThat
    return
  }
  CmdMove_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdMove_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdMove_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  global config glob
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Move"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      d   -
      l   -
      ld  -
      n   { 
        if {[CheckWhoOwns $frompwd/[lindex $elem 1] move] && [CheckWhoOwns $topwd/[lindex $elem 1] overwrite]} {
          Log "Moving $frompwd/[lindex $elem 1] to $topwd"
          Try { file rename -force -- $frompwd/[lindex $elem 1] $topwd } "" 1 $glob(async)
        }
      }
      default CantDoThat
    }
  }
}

proc CmdDelete {} {
  global glob
  CmdDelete_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) left
  CmdDelete_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) right
  UpdateWindow both
  set glob(forceupdate) 0
}

proc CmdDelete_ { listb_name filelist_var frompwd topwd inst } {
  # For speed, (hopefully) we'll call by reference...
  global config glob
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Delete"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      ld  -
      n   { 
        set ask 0
        if {$config(ask,file_delete)} {
          set ask [tk_dialog_fr .apop "Sure?" "OK to delete file $frompwd/[lindex $elem 1] ?" "" 1 "Yes" "No"]
        }
        if {$ask == 0} {
          if {[CheckWhoOwns $frompwd/[lindex $elem 1] delete]} {
            Log "Deleting $frompwd/[lindex $elem 1]"
            Try { file delete -force -- $frompwd/[lindex $elem 1] } "" 1
          }
        }
      }
      d   {
        set ask 0
        if {$config(ask,dir_delete)} {
          set ask [tk_dialog_fr .apop "Sure?" "OK to delete directory tree $frompwd/[lindex $elem 1] ?" "" 1 "Yes" "No"]
        }
        if {$ask == 0} {
          if {[CheckWhoOwns $frompwd/[lindex $elem 1] delete]} {
            Log "Deleting $frompwd/[lindex $elem 1]"
            Try { exec $config(cmd,rm) -rf $frompwd/[lindex $elem 1] } "" 1 $glob(async)
          }
        }
      }
      fn  -
      fld -
      fl  {
        set ask 0
        if {$config(ask,file_delete)} {
          set ask [tk_dialog_fr .apop "Sure?" "OK to delete file $frompwd/[lindex $elem 1] ?" "" 1 "Yes" "No"]
        }
        if {$ask == 0} {
          Log "Deleting $frompwd/[lindex $elem 1]"
          set r [regexp {ftp://([^/]*)(.*)} $frompwd/[lindex $elem 1] match ftpI file]
          if {$r} {
            set glob(forceupdate) 1
            Try { FTP_Delete $ftpI "$file" } "" 1
          }
        }
      }
      fd  {
        set ask 0
        if {$config(ask,dir_delete)} {
          set ask [tk_dialog_fr .apop "Sure?" "OK to delete directory tree $frompwd/[lindex $elem 1] ?" "" 1 "Yes" "No"]
        }
        if {$ask == 0} {
          Log "Deleting $frompwd/[lindex $elem 1]"
          set glob(forceupdate) 1
          Try { DeleteFTPRecursive "$frompwd/[lindex $elem 1]" $inst } "" 1
        }
      }
      default CantDoThat
    }
  }
}

proc CmdView {} {
  global glob
  CmdView_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) left
  CmdView_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) right
}

proc CmdView_ { listb_name filelist_var frompwd topwd inst } {
  # For speed, (hopefully) we'll call by reference...
  global glob config env
  upvar $filelist_var filelist
  set filenamelist {}
  foreach sel [$listb_name curselection] {
    if {[CheckAbort "View"]} return
    set fileelem [lindex $filelist $sel]
    switch [lindex $fileelem 2] {
      l   -
      n   { lappend filenamelist $frompwd/[lindex $fileelem 1] }
      fd  -
      fld -
      ld  - 
      d   { NewPwd $inst $glob($inst,pwd)/[lindex $fileelem 1]
            UpdateWindow $inst
            return
          }
      fn  -
      fl  {
            set r [regexp {ftp://([^/]*)(.*)} $glob($inst,pwd) match ftpI directory]
            if {$r == 0} { 
              PopError "Can't parse $glob($inst,pwd) as ftp URL" 
            } else { 
              set r 0
              if { ! [file exists $glob(tmpdir)] } {
                set r [Try { file mkdir $glob(tmpdir) } "" 1]
              }
              if { !$r } {
                set size [lindex $fileelem 3]
                if {[lindex $fileelem 2] == "fl"} {set size -1}
                set r [Try { FTP_GetFile $ftpI "$directory/[lindex $fileelem 1]" "$glob(tmpdir)/[lindex $fileelem 1]" $size 0 } "" 1]
                if {$r == 0} { ViewAny $glob(tmpdir)/[lindex $fileelem 1]; set glob(havedoneftp) 1 }
              }
            }
          }
      default CantDoThat
    }
  }
  if {$filenamelist != {}} {
    ViewAny $filenamelist
  }
}

proc CmdViewAsText {} {
  global glob
  CmdViewAsText_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdViewAsText_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
}

proc CmdViewAsText_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  upvar $filelist_var filelist
  set filenamelist {}
  foreach sel [$listb_name curselection] {
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   { ViewText $frompwd/[lindex $elem 1] }
      ld  -
      d   { PopInfo "Can't view directory $frompwd/[lindex $elem 1] in the text viewer" }
      default CantDoThat
    }
  }
}

proc CmdCheckSize {} {
  global glob
  CmdCheckSize_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) left
  CmdCheckSize_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) right
}

proc CmdCheckSize_ { listb_name filelist_var frompwd topwd inst } {
  # For speed, (hopefully) we'll call by reference...
  global glob config env
  upvar $filelist_var filelist
  set filenamelist {}
  foreach sel [$listb_name curselection] {
    if {[CheckAbort "View"]} return
    set fileelem [lindex $filelist $sel]
    switch [lindex $fileelem 2] {
      d   -
      ld  -
      l   -
      n   { lappend filenamelist [Esc $frompwd/[lindex $fileelem 1]] }
      default CantDoThat
    }
  }
  if {$filenamelist != {}} {
    set r [catch {eval eval exec $config(cmd,du) $filenamelist} out]
    if {$r} {
      PopError $out
    } else {
      ViewString "Output from du" out ""
    }
  }
}

proc CmdWhatIs {} {
  global glob
  CmdWhatIs_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdWhatIs_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
}

proc CmdWhatIs_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  upvar $filelist_var filelist
  set filenamelist {}
  foreach sel [$listb_name curselection] {
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   -
      ld  -
      d   { Try { PopInfo [exec file "$frompwd/[lindex $elem 1]"] } "" 1 
          }
      default CantDoThat
    }
  }
}

proc CmdEdit {} {
  global glob
  CmdEdit_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdEdit_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
}

proc CmdEdit_ { listb_name filelist_var frompwd topwd } {
  global env config
  # For speed, (hopefully) we'll call by reference...
  upvar $filelist_var filelist
  set filenamelist {}

  foreach sel [$listb_name curselection] {
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   { lappend filenamelist [Esc $frompwd/[lindex $elem 1]] }
      ld  -
      d   { PopInfo "Can't edit directory $frompwd/[lindex $elem 1] in the text editor" }
      default CantDoThat
    }
  }
  if {$filenamelist != {}} {
    # Three eval's in a row... New record? Yuck..
    Try { eval eval eval exec [format $config(editor) $filenamelist] & } "Can't start editor" 1
  }
}

proc CmdQEdit {} {
  global glob
  CmdQEdit_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdQEdit_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
}

proc CmdQEdit_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  global glob
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Q-Edit"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   { 
            set r [Try {EditText "$frompwd/[lindex $elem 1]" ""} "Error editing $frompwd/[lindex $elem 1]" 1]
            if {$r != 0} { catch { destroy .toplevel_$glob(toplevelidx) } }
          }
      ld  -
      d   { PopInfo "Can't edit directory $frompwd/[lindex $elem 1] in the text editor" }
      default CantDoThat
    }
  }
}


proc CmdRename {} {
  global glob
  CmdRename_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdRename_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
  set glob(forceupdate) 0
}

proc CmdRename_ { listb_name filelist_var frompwd topwd } {
  # For speed, (hopefully) we'll call by reference...
  global config glob
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Rename"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      d   -
      l   -
      ld  -
      n   { 
        if {[CheckWhoOwns $frompwd/[lindex $elem 1] rename]} {
          set newname [EntryDialog "Rename" "Please enter new name." $frompwd/[lindex $elem 1] question]
          if {$newname != ""} {
            if {[CheckWhoOwns $newname overwrite]} {
              Log "Renaming $frompwd/[lindex $elem 1] to $newname"
              Try { file rename -force -- $frompwd/[lindex $elem 1] $newname } "" 1
            }
          }
        }
      }
      fl  -
      fld -
      fd  -
      fn  {
        set newname [EntryDialog "Rename" "Please enter new name." $frompwd/[lindex $elem 1] question]
        if {$newname != ""} {
          Log "Renaming $frompwd/[lindex $elem 1] to $newname"
          set r [regexp {ftp://([^/]*)(.*)} $frompwd/[lindex $elem 1] match ftpI oldftpname]
          if {!$r} {
            PopError "Error in URL $frompwd/[lindex $elem 1]"
          } else {
            set r [regexp {ftp://([^/]*)(.*)} $newname match ftpI newftpname]
            if {!$r} {
              PopError "Error in URL $newname"
            } else {
              Try { FTP_Rename $ftpI $oldftpname $newftpname } "" 1
              set glob(forceupdate) 1
            }
          }
        }
      }
      default CantDoThat
    }
  }
}


proc CmdUnArc {} {
  global glob
  CmdUnArc_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdUnArc_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdUnArc_ { listb_name filelist_var frompwd topwd } {
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "UnArchive"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      ld  -
      d   { PopError "Can't unarchive directory [lindex $elem 1]..." }
      l   -
      n   { Log "Unarchiving $frompwd/[lindex $elem 1] to $topwd"
            UnArcAny $frompwd/[lindex $elem 1] $topwd 
          }
      default CantDoThat
    }
  }
}

proc CmdUnPack {} {
  global glob
  CmdUnPack_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdUnPack_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdUnPack_ { listb_name filelist_var frompwd topwd } {
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "UnPack"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      ld  -
      d   { PopError "Can't UnPackhive directory [lindex $elem 1]..." }
      l   -
      n   { Log "Unpacking $frompwd/[lindex $elem 1]"
            UnPackAny $frompwd/[lindex $elem 1] }
      default CantDoThat
    }
  }
}


proc CmdArc {} {
  global glob
  CmdArc_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdArc_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
  UpdateWindow both
}

proc CmdArc_ { listb_name filelist_var frompwd topwd } {
  global config glob
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Archive"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   { 
        Log "Packing $frompwd/[lindex $elem 1]"
#        Try { eval exec [format $config(cmd,pack) {$frompwd/[lindex $elem 1]}] } "" 1  $glob(async)
        Try { eval eval exec [format $config(cmd,pack) [Esc $frompwd/[lindex $elem 1]]] } "" 1  $glob(async)
      }
      ld  -
      d   { 
        Log "Archiving $frompwd/[lindex $elem 1]"
        if {$config(cmd,archive) == "tar+gz {%s}"} {
          Try { cd $frompwd; exec tar cf - [lindex $elem 1] | gzip > [lindex $elem 1].tar.gz } "" 1 $glob(async)
        } else {
          Try { cd $frompwd; eval eval exec [format $config(cmd,archive) [Esc [lindex $elem 1]] ] } "" 1 $glob(async)
        }
      }
      default CantDoThat
    }
  }
}

proc CmdPrint {} {
  global glob
  CmdPrint_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd)
  CmdPrint_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd)
}

proc CmdPrint_ { listb_name filelist_var frompwd topwd } {
  global config
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Print"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   { Log "Printing $frompwd/[lindex $elem 1]"
            Try { eval eval exec [format $config(cmd,print) [Esc $frompwd/[lindex $elem 1]]] } "" 1 }
      ld  -
      d   { PopError "Can't print directories!!" }
      default CantDoThat
    }
  }
}

proc CmdMakeDir {} {
  global config glob
  set focus_win $glob(focus_before_doprotcmd)
  set done false
  if { $focus_win == "$glob(win,left).entry_dir" } {
    set newdir "[$glob(win,left).entry_dir get]"
    set done true
  }
  if { $focus_win == "$glob(win,right).entry_dir" } {
    set newdir "[$glob(win,right).entry_dir get]"
    set done true
  }
  if {$done != "true" } {
    set newdir [EntryDialog "Directory name?" \
"Please enter the name of the new directory. Another way of creating directories is to enter the name the new directory in one\
 of the directory entries and then pressing the MkDir button" "$glob(left,pwd)" question]
    if {$newdir == ""} return
  }
  Log "Creating directory $newdir"
  set r [regexp {ftp://([^/]*)(.*)} $newdir match ftpI dir]
  if {$r} {
    Try { FTP_MkDir $ftpI "$dir" } "" 1
    set glob(forceupdate) 1
  } else {
    Try { file mkdir $newdir } "" 1
  }
  UpdateWindow both
  set glob(forceupdate) 0
}

proc CmdSelect {} {
  global glob
  set focus_win $glob(focus_before_doprotcmd)
  set gotit 0
  if { $focus_win == "$glob(win,left).entry_dir" } {
    set pat [$glob(win,left).entry_dir get]
    set inst left
    set gotit 1
  }
  if { $focus_win == "$glob(win,right).entry_dir" } {
    set pat [$glob(win,right).entry_dir get]
    set inst right
    set gotit 1
  }
  if {! $gotit } {
    PopInfo "Please enter a selection pattern in one of the directory entries and then press the Select button"
  } else {
    $glob(win,$inst).entry_dir delete 0 end
    $glob(win,$inst).entry_dir insert end $glob(${inst},pwd)
    $glob(win,$inst).entry_dir xview moveto 1.0
    set pat [file tail $pat]
    set i 0
    foreach elem $glob($inst,filelist) {
      if {[string match $pat [lindex $elem 1]]} {
        $glob(win,$inst).frame_listb.listbox1 selection set $i
      }
      incr i
    }
  }
  UpdateStat
}

proc CmdCSelect {} {
  global glob
  set cmd [EntryDialog "Contents-select" "Make sure you have selected the files you want to search in, then please edit this command to do a contents-select." "grep -i "]
  if { $cmd == "" } return
  CmdCSelect_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) $cmd
  CmdCSelect_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) $cmd
  UpdateStat
}

proc CmdCSelect_ { listb_name filelist_var frompwd topwd cmd } {
  upvar $filelist_var filelist

  foreach sel [$listb_name curselection] {
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      n   { 
            set r [catch { eval exec $cmd {$frompwd/[lindex $elem 1]} } outp]
            if { $r != 0 } {
              $listb_name selection clear $sel
            }
          }
      default CantDoThat
    }
  }
}

proc CmdRunCmd {} {
  global glob
  CmdRunCmd_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) 
  CmdRunCmd_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) 
}

proc CmdRunCmd_ { listb_name filelist_var frompwd topwd } {
  global glob
  upvar $filelist_var filelist

  set fl {}
  foreach sel [$listb_name curselection] {
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      d   -
      ld  -
      l   -
      n   { lappend fl [lindex $elem 1] }
      default CantDoThat
    }
  }
  if { $fl == "" } return
  set cmd [EntryDialog "Run command" "Edit the command line. Ctrl-A takes you to the start of the line." " $fl"]
  if { $cmd == "" } return
  LogSilent "Running command:\n$cmd"
  if {$glob(async)} {
    catch { cd $frompwd; eval exec $cmd & } out
    return
  } else {
    catch { cd $frompwd; eval exec $cmd } out
  }
  if { $out != "" } {
    ViewString "Output from command" out ""
  }
  UpdateWindow both
}

proc CmdForEach {} {
  global glob
  CmdForEach_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) 
  CmdForEach_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) 
}

proc CmdForEach_ { listb_name filelist_var frompwd topwd } {
  global glob config
  upvar $filelist_var filelist

  set fl {}
  foreach sel [$listb_name curselection] {
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      d   -
      ld  -
      l   -
      n   { lappend fl [lindex $elem 1] }
      default CantDoThat
    }
  }
  if { $fl == "" } return
  if {$glob(async)} {
    PopError "This command does not support asynchronous execution"
    return
  }
  if {![info exists glob(foreach,cmd)] || $glob(foreach,cmd) == {}} {
    set glob(foreach,cmd) {echo '%s'}
  }
  set glob(foreach,cmd) [EntryDialog "Foreach" "Enter command to run on each of the selected files. The file will show up in the '%s'. You can use pipes and other bourne-shell syntax elements since the commands will each run in a separate bourne shell." $glob(foreach,cmd)]
  if { $glob(foreach,cmd) == "" } return

  set output {}
  foreach k $fl {
    if {[CheckAbort "ForEach"]} return
    set cmd [format "$glob(foreach,cmd)" $k]
    append output "\$ $cmd\n"
    LogStatusOnly "Running $cmd ..."
    catch { cd $frompwd ; exec $config(cmd,sh) -c "$cmd" } out
    append output "$out\n"
  }
  ViewString "Output from commands" output ""
  UpdateWindow both
}

proc CmdRecurseCommand { inst } {
  global glob config

  set dir $glob($inst,pwd)

  if { [IsFTP $dir] } {
    CantDoThat
    return
  }

  if {$glob(async)} {
    PopError "This command does not support asynchronous execution"
    return
  }
  if {![info exists glob(foreach,cmd)] || $glob(foreach,cmd) == {}} {
    set glob(foreach,cmd) {echo '%s'}
  }
  set e [EntryDialogDouble "Run Command Recursively" "Enter command to run on each file. The file will show up in the '%s'. You can use pipes and other bourne-shell syntax elements since the commands will each run in a separate bourne shell." "Enter pattern to match for when recursing into directories." "This command will run a 'find' of the type\n\n    $ find <directory> -type f -name <pattern> -print\n\nto recurse into the current directory ($dir). The command will then be run on all files from this find.\n\nSee also: manpage for the find command.\n\nUse tab to go to next entry. Return or the OK button starts execution." $glob(foreach,cmd) {*}]
  if { $e == "" } return

  set glob(foreach,cmd) [lindex $e 0]
  set pattern [lindex $e 1]
  set output {}

  # expand file list with find outputs
  set r [catch {cd $dir ; exec $config(cmd,find) . -type f -name $pattern -print} out]
  if {$r} {
    PopError "$out"
    return
  }
  set fl [split $out \n]
  foreach k $fl {
    if {[CheckAbort "Recurse Command"]} return
    set cmd [format "$glob(foreach,cmd)" $k]
    append output "\$ $cmd\n"
    LogStatusOnly "Running $cmd ..."
    catch { cd $dir ; exec $config(cmd,sh) -c "$cmd" } out
    append output "$out\n"
  }
  ViewString "Output from commands" output ""
  UpdateWindow both
}


proc CmdDiff {} {
  global glob
  CmdDiff_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) left
  CmdDiff_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) right
}

proc CmdDiff_ { listb_name filelist_var frompwd topwd inst } {
  global glob
  upvar $filelist_var filelist
  global config

  set null 1
  set file1 ""
  set file2 ""

  foreach sel [$listb_name curselection] {
    set null 0
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      ld  -
      d   -
      l   -
      n   { 
            if {$file1 == ""} { 
              set file1 $frompwd/[lindex $elem 1] 
            } else {
              if { $file2 != "" } { 
                PopError "Please select one or two files or directories for diffing."
                return
              }
              set file2 $frompwd/[lindex $elem 1] 
            }
          }
      default CantDoThat
    }
  }

  if {$null} return

  if {$file2 == ""} {
    set file2 $topwd/[lindex [lindex $glob([Opposite $inst],filelist) [$glob(win,[Opposite $inst]).frame_listb.listbox1 index active]] 1]
    set tmp $file1
    set file1 $file2
    set file2 $tmp
  }

  set r [catch { eval eval exec [format $config(cmd,diff) [Esc $file1] [Esc $file2]] } outp]
  if { $r != 0 } {
    ViewString "Diffing $file1 and $file2" outp "diff.log"
  } else {
    PopInfo "No difference between\n\n$file1\n\nand\n\n$file2"
  }
}

proc CmdCreateEmptyFile { inst } {
  global glob config
  set start_entry $glob($inst,pwd)
  set newfile [EntryDialog "Create New File" "Please enter the name of the new file." $start_entry question]

  if {$newfile != ""} {
    Log "Creating new file $newfile"
    Try { exec $config(cmd,touch) "$newfile" } "" 1
    UpdateWindow both
  }
}

proc DeleteFTPRecursive { dir inst } {
  global glob config
  set r [regexp {ftp://([^/]*)(.*)} $dir match ftpI directory]
  Log "FTP recursive delete: Entering $dir"
  NewPwd $inst $dir
  UpdateWindow $inst
  foreach elem $glob($inst,filelist) {
    switch [lindex $elem 2] {
      fn  -
      fld -
      fl  {
        Log "Deleting $dir/[lindex $elem 1]"
        FTP_Delete $ftpI "$directory/[lindex $elem 1]"
      }
      fd {
        DeleteFTPRecursive "$dir/[lindex $elem 1]" $inst
      }
      default {
        error "Unexpected file type in FTP recursive delete"
      }
    }
  }
  Log "Deleting $dir"
  NewPwd $inst "$dir/.."
  FTP_RmDir $ftpI "$directory"
}

proc CopyFromFTPRecursive { fromdir todir inst resume } {
  global glob config
  if {[CheckAbort "CopyFromFTPRecursive"]} return
  set r [regexp {ftp://([^/]*)(.*)} $fromdir match ftpI directory]
  set dir [file tail $directory]
  Log "FTP recursive copy: Creating $todir/$dir"
  file mkdir "$todir/$dir"
  Log "FTP recursive copy: Entering $fromdir"
  NewPwd $inst $fromdir
  UpdateWindow $inst
  foreach elem $glob($inst,filelist) {
    if {[CheckAbort "CopyFromFTPRecursive"]} return
    switch [lindex $elem 2] {
      fld -
      fl {
        Log "Skipping $fromdir/[lindex $elem 1] - link"
      }
      fd {
        CopyFromFTPRecursive "$fromdir/[lindex $elem 1]" "$todir/$dir" $inst $resume
      }
      fn {
        Log "FTP recursive copy: Copying $fromdir/[lindex $elem 1] -> $todir/$dir/[lindex $elem 1] ([lindex $elem 3] bytes)"
        FTP_GetFile $ftpI "$directory/[lindex $elem 1]" "$todir/$dir/[lindex $elem 1]" "[lindex $elem 3]" $resume
      }
      default {
        error "Unexpected file type in FTP recursive copy"
      }
    }
  }
}

proc CopyToFTPRecursive { fromdir todir inst } {
  global glob config
  if {[CheckAbort "CopyToFTPRecursive"]} return
  set r [regexp {ftp://([^/]*)(.*)} $todir match ftpI directory]
  set dir [file tail $fromdir]
  Log "FTP recursive copy: Creating $todir/$dir"
  FTP_MkDir $ftpI "$directory/$dir"
  Log "FTP recursive copy: Entering $fromdir"
  NewPwd $inst $fromdir
  UpdateWindow $inst
  foreach elem $glob($inst,filelist) {
    if {[CheckAbort "CopyToFTPRecursive"]} return
    switch [lindex $elem 2] {
      ld -
      l {
        Log "Skipping $fromdir/[lindex $elem 1] - link"
      }
      d {
        CopyToFTPRecursive "$fromdir/[lindex $elem 1]" "$todir/$dir" $inst
      }
      n {
        Log "FTP recursive copy: Copying $fromdir/[lindex $elem 1] -> $todir/$dir/[lindex $elem 1] ([lindex $elem 3] bytes)"
        FTP_PutFile $ftpI "$fromdir/[lindex $elem 1]" "$directory/$dir/[lindex $elem 1]" "[lindex $elem 3]"
      }
      default {
        error "Unexpected file type in FTP recursive copy"
      }
    }
  }
}

proc CmdFind { inst } {
  global glob config
  set findname [EntryDialog "Find..." "Please enter substring of filename to search for in $glob($inst,pwd) and below." \
      "" "question"]
  if {$findname == ""} return
  if {[IsFTP $glob($inst,pwd)]} {
    regexp {ftp://([^/]*)(.*)} $glob($inst,pwd) match ftpI directory
    set r [catch {FTP_CD $ftpI $directory} out]
    if {$r != 0} {
      PopError $out
      return
    }
    LogStatusOnly "Searching, please wait..."
    set r [catch {FTP_DoSearch $ftpI $findname} out]
    LogStatusOnly "Searching, please wait...done"
    if {$r} {
      PopError "FTP search error: $out"
      return
    }
    ViewString "FTP search results" out ""
    return
  }
  set r [catch {cd $glob($inst,pwd)} out]
  if {$r} {
    PopError "$out"
    return
  }
  LogStatusOnly "Searching, please wait..."
  set r [catch {exec $config(cmd,sh) -c "find . -name '*${findname}*' -print" 2> /dev/null } out]
  LogStatusOnly "Searching, please wait...done"
#  if {$r} {
#    PopError "Search error: $out"
#    return
#  }
  set out [split $out "\n"]
  if {[string range [lindex $out end] 0 4] == "child"} {
    set out [lrange $out 0 [expr [llength $out] - 2]]
  }
  if {[string trim $out] == ""} {
    PopInfo "No file found"
    return
  }
  FindDialog $out $inst
}


proc CmdChmod {} {
  global glob
  CmdChmod_ $glob(win,left).frame_listb.listbox1 glob(left,filelist) $glob(left,pwd) $glob(right,pwd) left
  CmdChmod_ $glob(win,right).frame_listb.listbox1 glob(right,filelist) $glob(right,pwd) $glob(left,pwd) right
  UpdateWindow both
}

proc CmdChmod_ { listb_name filelist_var frompwd topwd inst } {
  # For speed, (hopefully) we'll call by reference...
  global config glob
  upvar $filelist_var filelist
  set fl {}

  foreach sel [$listb_name curselection] {
    if {[CheckAbort "Chmod"]} return
    set elem [lindex $filelist $sel]
    switch [lindex $elem 2] {
      l   -
      ld  -
      n   -
      d   {
        if {$fl == {}} {
          set mode [lindex $elem 5]
        }
        lappend fl [Esc $frompwd/[lindex $elem 1]]
      }
      default CantDoThat
    }
  }
  if {$fl != ""} {
    set arg [ChmodDialog "$frompwd/[lindex $elem 1]" $mode]
    if {$arg != ""} {
      Try { eval eval exec $config(cmd,chmod) $arg $fl } "" 1 $glob(async)
    }
  }
}

proc CmdGetHttp { inst } {
  global glob config
  
  if {[IsFTP $glob($inst,pwd)]} {
    PopInfo "You can only download HTTP files to a non-FTP directory"
    return
  }

  if {![info exists glob(http,lasturl)]} {
    set glob(http,lasturl) {}
  }
  set URL $glob(http,lasturl)

  while { 1 } {
    set URL [EntryDialog "Get HTTP File" "Please enter HTTP URL to download" $URL]
    if {$URL == ""} {
      return
    }
    
    if {[string range $URL 0 6] != "http://" } {
      set URL "http://$URL"
    }
    
    set r [regexp {http://([^/]*)(.*)} $URL match host_and_port location]
    if {!$r} {
      PopError "Could not parse $URL as an HTTP URL"
      continue
    } 
    if {$location == ""} {
      append URL /
    }
    set glob(http,lasturl) $URL
    break
  }

  set filename [file tail $URL]
  if {[string range $URL end end] == "/"} {
    append filename .html
  }
  set filename [EntryDialog "Get HTTP File" "Please edit filename to save to.\n(URL: $URL)" $filename]
  if {$filename == ""} {
    return
  }
  cd $glob($inst,pwd)
  HTTP_Get $URL $filename
  UpdateWindow both
}

