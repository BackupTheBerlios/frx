# as_style.tcl --
#
#  This file implements package as::style, which  ...
#
# Copyright (c) 2003 ActiveState Corporation, a division of Sophos
#
# Basic use:
#
# as::style::init ?which?
# as::style::reset ?which?
# as::style::enable ?what ?args??
#  ie: enable control-mousewheel local|global
#

#package require NAME VERSION
package provide as::style 1.1

namespace eval as::style {
    #namespace export -clear *

    #variable highlightcolor "#ECE9D8"
      variable highlightbg "#ff3366" ; # SystemHighlight
      variable highlightfg "white"   ; # SystemHighlightText
      variable bg          "white"   ; # SystemWindow
      variable fg          "black"   ; # SystemWindowText

    # assume MouseWheel binding is the same across widget classes
      variable mw
    set mw(classes) [list Text Listbox Table TreeCtrl]
    set mw(binding) [bind Text <MouseWheel>]
  if {[tk windowingsystem] eq "x11"} {
  set mw(binding4) [bind Text <4>]
  set mw(binding5) [bind Text <5>]
    }
}; # end of namespace as::style

proc as::style::init {args} {
  if {[llength $args]} {
  foreach what $args {
      as::style::init_$what
  }
    } else {
  foreach cmd [ lsort [ info procs init_* ] ] {
      $cmd
  }
    }
}
proc as::style::reset {args} {
  if {[llength $args]} {
  foreach what $args {
      as::style::reset_$what
  }
    } else {
  foreach cmd [info commands as::style::reset_*] {
      $cmd
  }
    }
}
proc as::style::enable {what args} {
    switch -exact $what {
  mousewheel { init_mousewheel }
  control-mousewheel {
      set type [lindex $args 0]; # should be local or global
      bind all <Control-MouseWheel> \
    [list ::as::style::CtrlMouseWheel %W %D %X %Y $type]
      bind all <Control-plus> \
    [list ::as::style::CtrlMouseWheel %W 120 %X %Y $type]
      bind all <Control-minus> \
    [list ::as::style::CtrlMouseWheel %W -120 %X %Y $type]
    if {[tk windowingsystem] eq "x11"} {
    bind all <Control-ButtonPress-4> \
        [list ::as::style::CtrlMouseWheel %W 120 %X %Y $type]
    bind all <Control-ButtonPress-5> \
        [list ::as::style::CtrlMouseWheel %W -120 %X %Y $type]
      }
  }
  default {
      return -code error "unknown option \"$what\""
  }
    }
}

proc as::style::disable {what args} {
    switch -exact $what {
  mousewheel { reset_mousewheel }
  control-mousewheel {
      bind all <Control-MouseWheel> {}
      bind all <Control-plus> {}
      bind all <Control-minus> {}
    if {[tk windowingsystem] eq "x11"} {
    bind all <Control-ButtonPress-4> {}
    bind all <Control-ButtonPress-5> {}
      }
  }
  default {
      return -code error "unknown option \"$what\""
  }
    }
}

## Fonts
##
proc as::style::init_fonts {args} {
  if {[lsearch -exact [font names] ASfont] != -1} return

  switch -exact [tk windowingsystem] {
    "x11" {
        set size  -12
        set family  Helvetica
        set fsize  -12
        set ffamily  Courier
    }
    "win32" {
        set size  8
        set family  Tahoma
        set fsize  9
        set ffamily  Courier
    }
    "aqua" - "macintosh" {
        set size  12
        set family  "Lucida Grande"
        set fsize  10
        set ffamily  Courier
    }
  }
  font create ASfont      -size $size -family $family
  font create ASfontBold  -size $size -family $family -weight bold
  font create ASfontFixed -size $fsize -family $ffamily
  for {set i -2} {$i <= 4} {incr i} {
    set isize  [expr {$size + ($i * (($size > 0) ? 1 : -1))}]
    set ifsize [expr {$fsize + ($i * (($fsize > 0) ? 1 : -1))}]
    font create ASfont$i      -size $isize -family $family
    font create ASfontBold$i  -size $isize -family $family -weight bold
    font create ASfontFixed$i -size $ifsize -family $ffamily
  }

  if {1 || [tk windowingsystem] eq "x11"} {
    option add *Text.font    ASfontFixed widgetDefault
    option add *Button.font    ASfont widgetDefault
    option add *Canvas.font    ASfont widgetDefault
    option add *Checkbutton.font  ASfont widgetDefault
    option add *Entry.font    ASfont widgetDefault
    option add *Label.font    ASfont widgetDefault
    option add *Labelframe.font  ASfont widgetDefault
    option add *Listbox.font  ASfont widgetDefault
    option add *Menu.font    ASfont widgetDefault
    option add *Menubutton.font  ASfont widgetDefault
    option add *Message.font  ASfont widgetDefault
    option add *Radiobutton.font  ASfont widgetDefault
    option add *Spinbox.font  ASfont widgetDefault

    option add *Table.font    ASfont widgetDefault
    option add *TreeCtrl*font  ASfont widgetDefault
  }
}

proc as::style::reset_fonts {args} {
}

proc as::style::CtrlMouseWheel {W D X Y {what local}} {
    set w [winfo containing $X $Y]
  if {[winfo exists $w]} {
  set top [winfo toplevel $w]
  while {[catch {$w cget -font} font]
         || ![string match "ASfont*" $font]} {
    if {$w eq $top} { return }
      set w [winfo parent $w]
  }
  if {$what eq "local"} {
      # get current font size (0 by default) and adjust the current
      # widget's font to the next sized preconfigured font
      set cnt [regexp -nocase -- {([a-z]+)(\-?\d)?} $font -> name size]
    if {$size eq ""} {
    set size [expr {($D > 0) ? 1 : -1}]
      } else {
    set size [expr {$size + (($D > 0) ? 1 : -1)}]
      }
      set font $name$size
    if {[lsearch -exact [font names] $font] != -1} {
    catch {$w configure -font $font}
      }
  } else {
      # readjust all the font sizes based on the current one
      set size [font configure ASfont -size]
      incr size [expr {($D > 0) ? 1 : -1}]
      # but we do have limits on how small/large things can get
    if {$size < 6 || $size > 18} { return }
      font configure ASfont      -size $size
      font configure ASfontBold  -size $size
      font configure ASfontFixed -size [expr {$size+1}]
      # force reconfigure of this widget with the same font in
      # case it doesn't have a WorldChanged function
      catch {$w configure -font $font}
    if {0} {
    # we shouldn't need this if the user isn't improperly
    # switching between global/local ctrl-mswhl modes
    for {set i -2} {$i <= 4} {incr i} {
        font configure ASfont$i      \
      -size [expr {$size+$i}] -family $family
        font configure ASfontBold$i  \
      -size [expr {$size+$i}] -family $family -weight bold
        font configure ASfontFixed$i \
      -size [expr {$size+1+$i}] -family Courier
    }
      }
  }
    }
}

## Misc
##
proc as::style::init_1st {args} {
  option add *ScrolledWindow.ipad     0          widgetDefault
  option add *padY                    0          widgetDefault
  option add *borderWidth             1          widgetDefault
  option add *background              gray77     widgetDefault
  option add *foreground              black      widgetDefault
  option add *selectbackground        "#ff3366"  widgetDefault
  option add *selectforeground        white      widgetDefault
}

## Frame
##
proc as::style::init_frame {args} {
    option add *Frame.relief groove widgetDefault
}

## Listbox
##
proc as::style::init_listbox {args} {
  if { [tk windowingsystem] eq "aqua" || [tk windowingsystem] eq "x11"} {
    variable highlightbg
    variable highlightfg
    variable bg
    variable fg
    option add *Listbox.background    $bg widgetDefault
    option add *Listbox.foreground    $fg widgetDefault
    option add *Listbox.selectBorderWidth  0 widgetDefault
    option add *Listbox.selectForeground  $highlightfg widgetDefault
    option add *Listbox.selectBackground  $highlightbg widgetDefault
  }
  option add *Listbox.activeStyle    dotbox widgetDefault
}

## Button
##
proc as::style::init_button {args} {
  if { [tk windowingsystem] eq "x11"} {
    option add *Button.padX      1 widgetDefault
    option add *Button.padY      2 widgetDefault
  }
}

## Entry
##
proc as::style::init_entry {args} {
  if { [tk windowingsystem] eq "aqua" || [tk windowingsystem] eq "x11"} {
    variable highlightbg
    variable highlightfg
    variable bg
    variable fg
    option add *Entry.background    $bg widgetDefault
    option add *Entry.foreground    $fg widgetDefault
    option add *Entry.selectBorderWidth  0 widgetDefault
    option add *Entry.selectForeground  $highlightfg widgetDefault
    option add *Entry.selectBackground  $highlightbg widgetDefault
  }
}

## Spinbox
##
proc as::style::init_spinbox {args} {
  if { [tk windowingsystem] eq "aqua" || [tk windowingsystem] eq "x11"} {
    variable highlightbg
    variable highlightfg
    variable bg
    variable fg
    option add *Spinbox.background    $bg widgetDefault
    option add *Spinbox.foreground    $fg widgetDefault
    option add *Spinbox.selectBorderWidth  0 widgetDefault
    option add *Spinbox.selectForeground  $highlightfg widgetDefault
    option add *Spinbox.selectBackground  $highlightbg widgetDefault
  }
}

## Text
##
proc as::style::init_text {args} {
  if { [tk windowingsystem] eq "aqua" || [tk windowingsystem] eq "x11"} {
    variable highlightbg
    variable highlightfg
    variable bg
    variable fg
    option add *Text.background    $bg widgetDefault
    option add *Text.foreground    $fg widgetDefault
    option add *Text.selectBorderWidth  0 widgetDefault
    option add *Text.selectForeground  $highlightfg widgetDefault
    option add *Text.selectBackground  $highlightbg widgetDefault
  }
}

## Menu
##
proc as::style::init_menu {args} {
  if { [tk windowingsystem] eq "aqua" || [tk windowingsystem] eq "x11"} {
    variable highlightbg
    variable highlightfg
    option add *Menu.activeBackground  $highlightbg widgetDefault
    option add *Menu.activeForeground  $highlightfg widgetDefault
    option add *Menu.activeBorderWidth  0 widgetDefault
    option add *Menu.highlightThickness  0 widgetDefault
    option add *Menu.borderWidth    1 widgetDefault
  }
}

## Menubutton
##
proc as::style::init_menubutton {args} {
  variable highlightbg
  variable highlightfg
  option add *Menubutton.activeBackground  $highlightbg widgetDefault
  option add *Menubutton.activeForeground  $highlightfg widgetDefault
  option add *Menubutton.activeBorderWidth  0 widgetDefault
  option add *Menubutton.highlightThickness  0 widgetDefault
  option add *Menubutton.borderWidth    0 widgetDefault
}

## Scrollbar
##
proc as::style::init_scrollbar {args} {
  if {[tk windowingsystem] eq "x11"} {
    option add *Scrollbar.width    12 widgetDefault
    option add *Scrollbar.troughColor  #bdb6ad widgetDefault
  }
  option add *Scrollbar.highlightThickness  0 widgetDefault
}

## PanedWindow
##
proc as::style::init_panedwindow {args} {
  option add *Panedwindow.borderWidth    0 widgetDefault
  option add *Panedwindow.sashwidth    3 widgetDefault
  option add *Panedwindow.showhandle    0 widgetDefault
  option add *Panedwindow.sashpad    0 widgetDefault
  option add *Panedwindow.sashrelief    flat widgetDefault
  option add *Panedwindow.relief    flat widgetDefault
}

## MouseWheel
##
proc as::style::MouseWheel {wFired D X Y} {
  if {[bind [winfo class $wFired] <MouseWheel>] eq ""} {
  set w [winfo containing $X $Y]
  # if we are outside the app, try and scroll the focus widget
  if {![winfo exists $w]} { catch {set w [focus]} }
  if {[winfo exists $w]} {
      # scrollbars have different call conventions
    if {[winfo class $w] eq "Scrollbar"} {
    catch {tk::ScrollByUnits $w \
         [string index [$w cget -orient] 0] \
         [expr {-($D/30)}]}
      } else {
    catch {$w yview scroll [expr {- ($D / 120) * 4}] units}
      }
  }
    }
}
proc as::style::init_mousewheel {args} {
      variable mw

    # Create a catch-all MouseWheel proc & binding and
    # alter default bindings to allow toplevel binding to control all
    bind all <MouseWheel> [list ::as::style::MouseWheel %W %D %X %Y]
    foreach class $mw(classes) {
  bind $class <MouseWheel> {}
    }
    #if {[bind [winfo toplevel %W] <MouseWheel>] ne ""} { continue }
    #%W yview scroll [expr {- (%D / 120) * 4}] units

  if {[tk windowingsystem] eq "x11"} {
  # Support for mousewheels on Linux/Unix commonly comes through
  # mapping the wheel to the extended buttons.
  bind all <4> [list ::as::style::MouseWheel %W 120 %X %Y]
  bind all <5> [list ::as::style::MouseWheel %W -120 %X %Y]
  foreach class $mw(classes) {
      bind $class <4> {}
      bind $class <5> {}
  }
    }
}
proc as::style::reset_mousewheel {args} {
    # Remove catch-all MouseWheel binding and restore default bindings
      variable mw

    bind all <MouseWheel> {}
    foreach class $mw(classes) {
  bind $class <MouseWheel> $mw(binding)
    }
  if {[tk windowingsystem] eq "x11"} {
  bind all <4> {}
  bind all <5> {}
  foreach class $mw(classes) {
      bind $class <4> $mw(binding4)
      bind $class <5> $mw(binding5)
  }
    }
}

package provide as::style 1.1
