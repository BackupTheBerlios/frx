# $Id: chmod.tcl,v 1.1 2006/07/09 10:09:39 butz Exp $

# This dialog got rather large and ugly so it got a file of its own
# I know it can be made shorter with smarter logic, but since it works...


proc ChmodDialog { filename mode } {
  global glob config chmod_state chmod_orig chmod_action chmod_recurse chmod_cancel

  set chmod_cancel 0

  set w .chmod_dialog
  toplevel $w -class Dialog
  wm title $w "Change permission flags"
  wm iconname $w "Change permission flags"
  wm resizable $w false false
  wm transient $w [winfo toplevel [winfo parent $w]]

  set chmod_orig(user,read) 0
  set chmod_orig(user,write) 0
  set chmod_orig(user,exec) 0
  set chmod_orig(group,read) 0
  set chmod_orig(group,write) 0
  set chmod_orig(group,exec) 0
  set chmod_orig(other,read) 0
  set chmod_orig(other,write) 0
  set chmod_orig(other,exec) 0
  set chmod_orig(special,setuid) 0
  set chmod_orig(special,setgid) 0
  set chmod_orig(special,sticky) 0

  if {$mode & 1<<0} { set chmod_orig(other,exec) 1 }
  if {$mode & 1<<1} { set chmod_orig(other,write) 1 }
  if {$mode & 1<<2} { set chmod_orig(other,read) 1 }
  if {$mode & 1<<3} { set chmod_orig(group,exec) 1 }
  if {$mode & 1<<4} { set chmod_orig(group,write) 1 }
  if {$mode & 1<<5} { set chmod_orig(group,read) 1 }
  if {$mode & 1<<6} { set chmod_orig(user,exec) 1 }
  if {$mode & 1<<7} { set chmod_orig(user,write) 1 }
  if {$mode & 1<<8} { set chmod_orig(user,read) 1 }
  if {$mode & 1<<9} { set chmod_orig(special,sticky) 1 }
  if {$mode & 1<<10} { set chmod_orig(special,setgid) 1 }
  if {$mode & 1<<11} { set chmod_orig(special,setuid) 1 }
 
  foreach i [array names chmod_orig] {
    set chmod_state($i) $chmod_orig($i)
  }

  frame $w.top
  label $w.top.filename -text $filename -bg white
  pack $w.top.filename -side top -expand 1 -fill x -pady 4

  frame $w.mid
  frame $w.mid.user
  label $w.mid.user.title -text User
  pack $w.mid.user.title -side top -anchor w
  checkbutton $w.mid.user.read  -text read -variable  chmod_state(user,read)
  pack $w.mid.user.read -side top -anchor w
  checkbutton $w.mid.user.write -text write -variable chmod_state(user,write)
  pack $w.mid.user.write -side top -anchor w
  checkbutton $w.mid.user.exec  -text exec -variable  chmod_state(user,exec)
  pack $w.mid.user.exec -side top -anchor w

  frame $w.mid.group
  label $w.mid.group.title -text Group
  pack $w.mid.group.title -side top -anchor w
  checkbutton $w.mid.group.read  -text read -variable  chmod_state(group,read)
  pack $w.mid.group.read -side top -anchor w
  checkbutton $w.mid.group.write -text write -variable chmod_state(group,write)
  pack $w.mid.group.write -side top -anchor w
  checkbutton $w.mid.group.exec  -text exec -variable  chmod_state(group,exec)
  pack $w.mid.group.exec -side top -anchor w

  frame $w.mid.other
  label $w.mid.other.title -text Other
  pack $w.mid.other.title -side top -anchor w
  checkbutton $w.mid.other.read  -text read -variable  chmod_state(other,read)
  pack $w.mid.other.read -side top -anchor w
  checkbutton $w.mid.other.write -text write -variable chmod_state(other,write)
  pack $w.mid.other.write -side top -anchor w
  checkbutton $w.mid.other.exec  -text exec -variable  chmod_state(other,exec)
  pack $w.mid.other.exec -side top -anchor w

  frame $w.mid.special
  label $w.mid.special.title -text Special
  pack $w.mid.special.title -side top  -anchor w
  checkbutton $w.mid.special.setuid  -text setuid -variable  chmod_state(special,setuid)
  pack $w.mid.special.setuid -side top -anchor w
  checkbutton $w.mid.special.setgid -text setgid -variable chmod_state(special,setgid)
  pack $w.mid.special.setgid -side top -anchor w
  checkbutton $w.mid.special.sticky  -text sticky -variable  chmod_state(special,sticky)
  pack $w.mid.special.sticky -side top -anchor w

  frame $w.bot
  frame $w.bot.action
  label $w.bot.action.title -text Action
  pack $w.bot.action.title -side top -anchor w
  radiobutton $w.bot.action.set -text Set -variable chmod_action -value set -command ChmodSetSet
  pack $w.bot.action.set -side top -anchor w
  radiobutton $w.bot.action.add -text Add -variable chmod_action -value add -command ChmodSetAdd
  pack $w.bot.action.add -side top -anchor w
  radiobutton $w.bot.action.del -text Delete -variable chmod_action -value delete -command ChmodSetDel
  pack $w.bot.action.del -side top -anchor w
  checkbutton $w.bot.action.recurse  -text Recurse -variable chmod_recurse
  pack $w.bot.action.recurse -side top -anchor w

  button $w.bot.ok -text Ok -command "set chmod_cancel 0; destroy $w"
  button $w.bot.cancel -text Cancel -command "set chmod_cancel 1; destroy $w"

  pack $w.bot.cancel -side right -anchor s 
  pack $w.bot.ok -side right -anchor s 

  pack $w.mid.user -side left 
  pack $w.mid.group -side left 
  pack $w.mid.other -side left 
  pack $w.mid.special -side left
  pack $w.bot.action -side left
  pack $w.top -side top -expand 1 -fill x
  pack $w.mid -side top
  pack $w.bot -side top -expand 1 -fill x

  $w.bot.action.set select

  wm withdraw $w
  update idletasks
  set pw [winfo parent $w]
  set x [expr [winfo width $pw]/2 - [winfo reqwidth $w]/2 \
      + [winfo x $pw]]
  set y [expr [winfo height $pw]/2 - [winfo reqheight $w]/2 \
      + [winfo y $pw]]
  wm geom $w +$x+$y
  wm deiconify $w

  set oldGrab [grab current $w]
  frgrab $w
  set oldena $glob(enableautoupdate)
  set glob(enableautoupdate) 0
  tkwait window $w
  if {$oldGrab != ""} {
    frgrab $oldGrab
  }

  # calc chmod arguments
  set chmod_arg ""
  if {$chmod_action == "set" } {
    set user 0
    set group 0
    set other 0
    set special 0
    if {$chmod_state(user,exec)} {set user [expr $user | 1<<0]}
    if {$chmod_state(user,write)} {set user [expr $user | 1<<1]}
    if {$chmod_state(user,read)} {set user [expr $user | 1<<2]}
    if {$chmod_state(group,exec)} {set group [expr $group | 1<<0]}
    if {$chmod_state(group,write)} {set group [expr $group | 1<<1]}
    if {$chmod_state(group,read)} {set group [expr $group | 1<<2]}
    if {$chmod_state(other,exec)} {set other [expr $other | 1<<0]}
    if {$chmod_state(other,write)} {set other [expr $other | 1<<1]}
    if {$chmod_state(other,read)} {set other [expr $other | 1<<2]}
    if {$chmod_state(special,sticky)} {set special [expr $special | 1<<0]}
    if {$chmod_state(special,setgid)} {set special [expr $special | 1<<1]}
    if {$chmod_state(special,setuid)} {set special [expr $special | 1<<2]}
    set chmod_arg "$special$user$group$other"
  } elseif {$chmod_action == "add" } {
    set user ""
    set group ""
    set other ""
    set all ""
    set arg ""
    if {$chmod_state(user,read)} {set user "r$user"}
    if {$chmod_state(user,write)} {set user "w$user"}
    if {$chmod_state(user,exec)} {set user "x$user"}
    if {$chmod_state(group,read)} {set group "r$group"}
    if {$chmod_state(group,write)} {set group "w$group"}
    if {$chmod_state(group,exec)} {set group "x$group"}
    if {$chmod_state(other,read)} {set other "r$other"}
    if {$chmod_state(other,write)} {set other "w$other"}
    if {$chmod_state(other,exec)} {set other "x$other"}
    if {$chmod_state(special,setuid)} {set user "s$user"}
    if {$chmod_state(special,setgid)} {set group "s$group"}
    if {$chmod_state(special,sticky)} {set all "t$all"}
    if {$user != ""} {
      set arg "u+$user"
    }
    if {$group != ""} {
      if {$arg != ""} { set arg ",$arg" }
      set arg "g+$group$arg"
    }
    if {$other != ""} {
      if {$arg != ""} { set arg ",$arg" }
      set arg "o+$other$arg"
    }
    if {$all != ""} {
      if {$arg != ""} { set arg ",$arg" }
      set arg "a+$all$arg"
    }
    set chmod_arg $arg
  } elseif {$chmod_action == "delete" } {
    set user ""
    set group ""
    set other ""
    set all ""
    set arg ""
    if {$chmod_state(user,read)} {set user "r$user"}
    if {$chmod_state(user,write)} {set user "w$user"}
    if {$chmod_state(user,exec)} {set user "x$user"}
    if {$chmod_state(group,read)} {set group "r$group"}
    if {$chmod_state(group,write)} {set group "w$group"}
    if {$chmod_state(group,exec)} {set group "x$group"}
    if {$chmod_state(other,read)} {set other "r$other"}
    if {$chmod_state(other,write)} {set other "w$other"}
    if {$chmod_state(other,exec)} {set other "x$other"}
    if {$chmod_state(special,setuid)} {set user "s$user"}
    if {$chmod_state(special,setgid)} {set group "s$group"}
    if {$chmod_state(special,sticky)} {set all "t$all"}
    if {$user != ""} {
      set arg "u-$user"
    }
    if {$group != ""} {
      if {$arg != ""} { set arg ",$arg" }
      set arg "g-$group$arg"
    }
    if {$other != ""} {
      if {$arg != ""} { set arg ",$arg" }
      set arg "o-$other$arg"
    }
    if {$all != ""} {
      if {$arg != ""} { set arg ",$arg" }
      set arg "a-$all$arg"
    }
    set chmod_arg $arg
  }
  if {$chmod_recurse} {
    set chmod_arg "-R $chmod_arg"
  }

  set glob(enableautoupdate) $oldena
  if {$chmod_cancel} {set chmod_arg ""}
  unset chmod_state chmod_orig chmod_action chmod_recurse chmod_cancel
#  puts "$chmod_arg"
  return $chmod_arg
}

proc ChmodSetAdd { } {
  global chmod_state chmod_orig
  foreach i [array names chmod_orig] {
    set chmod_state($i) 0
  }
}

proc ChmodSetDel { } {
  global chmod_state chmod_orig
  foreach i [array names chmod_orig] {
    set chmod_state($i) 0
  }
}

proc ChmodSetSet { } {
  global chmod_state chmod_orig
  foreach i [array names chmod_orig] {
    set chmod_state($i) $chmod_orig($i)
  }
}

