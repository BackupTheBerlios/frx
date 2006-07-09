# $Id: dialog.tcl,v 1.1 2006/07/09 10:10:00 butz Exp $

#
# tk_dialog_about: Show about-box
#
# Arguments:
# w -		Window to use for dialog top-level.
# title -	Title to display in dialog's decorative frame.
# text -	Message to display in dialog.
# bitmap -	Bitmap to display in dialog (empty string means none).
# default -	Index of button that is to display the default ring
#		(-1 means none).
# args -	One or more strings to display in buttons across the
#		bottom of the dialog box.

proc tk_dialog_about {w title text bitmap default args} {
    global tkPriv

    # 1. Create the top-level window and divide it into top
    # and bottom parts.

    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w $title
    wm iconname $w Dialog
    wm protocol $w WM_DELETE_WINDOW { }

    # The following command means that the dialog won't be posted if
    # [winfo parent $w] is iconified, but it's really needed;  otherwise
    # the dialog can become obscured by other windows in the application,
    # even though its grab keeps the rest of the application from being used.

    wm transient $w [winfo toplevel [winfo parent $w]]
    frame $w.bot  
    pack $w.bot -side bottom -fill both
    frame $w.top  
    pack $w.top -side top -fill both -expand 1

    # 2. Fill the top part with bitmap and message (use the option
    # database for -wraplength so that it can be overridden by
    # the caller).

    #option add *Dialog.msg.wrapLength 4i widgetDefault
    label $w.msg -justify center -text $text -wraplength 9i -bg white
    catch {$w.msg configure -font \
		-Adobe-Times-Medium-R-Normal--*-180-*-*-*-*-*-*
    }
    pack $w.msg -in $w.top -side right -expand 1 -fill both -padx 3m -pady 3m
    if {$bitmap != ""} {
	label $w.bitmap -bitmap $bitmap
	pack $w.bitmap -in $w.top -side left -padx 3m -pady 3m
    }

    # 3. Create a row of buttons at the bottom of the dialog.

    set i 0
    foreach but $args {
	button $w.button$i -text $but -command "set tkPriv(button) $i"
	if {$i == $default} {
	    frame $w.default  
	    raise $w.button$i $w.default
	    pack $w.default -in $w.bot -side left -expand 1 -padx 3m -pady 2m
	    pack $w.button$i -in $w.default -padx 2m -pady 2m
	} else {
	    pack $w.button$i -in $w.bot -side left -expand 1 \
		    -padx 3m -pady 2m
	}
	incr i
    }

    # 4. Create a binding for <Return> on the dialog if there is a
    # default button.

    if {$default >= 0} {
	bind $w <Return> "
	    $w.button$default configure -state active 
	    update idletasks
	    after 100
	    set tkPriv(button) $default
	"
    }

    # 5. Create a <Destroy> binding for the window that sets the
    # button variable to -1;  this is needed in case something happens
    # that destroys the window, such as its parent window being destroyed.

    bind $w <Destroy> {set tkPriv(button) -1}

    # 6. Withdraw the window, then update all the geometry information
    # so we know how big it wants to be, then center the window in the
    # display and de-iconify it.

    wm withdraw $w
    update idletasks
    set pw [winfo parent $w]
    set x [expr [winfo width $pw]/2 - [winfo reqwidth $w]/2 \
	    + [winfo x $pw]]
    set y [expr [winfo height $pw]/2 - [winfo reqheight $w]/2 \
	    + [winfo y $pw]]
    wm geom $w +$x+$y
    wm deiconify $w

    # 7. Set a grab and claim the focus too.

    set oldFocus [focus]
    set oldGrab [grab current $w]
    if {$oldGrab != ""} {
	set grabStatus [grab status $oldGrab]
    }
    grab $w
    if {$default >= 0} {
	focus $w.button$default
    } else {
	focus $w
    }

    # 8. Wait for the user to respond, then restore the focus and
    # return the index of the selected button.  Restore the focus
    # before deleting the window, since otherwise the window manager
    # may take the focus away so we can't redirect it.  Finally,
    # restore any grab that was in effect.

    tkwait variable tkPriv(button)
    catch {focus $oldFocus}
    catch {
	# It's possible that the window has already been destroyed,
	# hence this "catch".  Delete the Destroy handler so that
	# tkPriv(button) doesn't get reset by it.

	bind $w <Destroy> {}
	destroy $w
    }
    if {$oldGrab != ""} {
	if {$grabStatus == "global"} {
	    grab -global $oldGrab
	} else {
	    grab $oldGrab
	}
    }
    return $tkPriv(button)
}


# Replacement for the standard tk_dialog function which doesn't work well on Xinerama
#
# tk_dialog:
#
# This procedure displays a dialog box, waits for a button in the dialog
# to be invoked, then returns the index of the selected button.  If the
# dialog somehow gets destroyed, -1 is returned.
#
# Arguments:
# w -		Window to use for dialog top-level.
# title -	Title to display in dialog's decorative frame.
# text -	Message to display in dialog.
# bitmap -	Bitmap to display in dialog (empty string means none).
# default -	Index of button that is to display the default ring
#		(-1 means none).
# args -	One or more strings to display in buttons across the
#		bottom of the dialog box.

proc tk_dialog {w title text bitmap default args} {
    global tkPriv tcl_platform

    # 1. Create the top-level window and divide it into top
    # and bottom parts.

    catch {destroy $w}
    toplevel $w -class Dialog
    wm title $w $title
    wm iconname $w Dialog
    wm protocol $w WM_DELETE_WINDOW { }

    # The following command means that the dialog won't be posted if
    # [winfo parent $w] is iconified, but it's really needed;  otherwise
    # the dialog can become obscured by other windows in the application,
    # even though its grab keeps the rest of the application from being used.

    wm transient $w [winfo toplevel [winfo parent $w]]
    if {$tcl_platform(platform) == "macintosh"} {
	unsupported1 style $w dBoxProc
    }

    frame $w.bot
    frame $w.top
    if {$tcl_platform(platform) == "unix"} {
	$w.bot configure  
	$w.top configure  
    }
    pack $w.bot -side bottom -fill both
    pack $w.top -side top -fill both -expand 1

    # 2. Fill the top part with bitmap and message (use the option
    # database for -wraplength so that it can be overridden by
    # the caller).

    option add *Dialog.msg.wrapLength 3i widgetDefault
    label $w.msg -justify left -text $text
    if {$tcl_platform(platform) == "macintosh"} {
	$w.msg configure -font system
    } else {
	$w.msg configure -font {Times 18}
    }
    pack $w.msg -in $w.top -side right -expand 1 -fill both -padx 3m -pady 3m
    if {$bitmap != ""} {
	if {($tcl_platform(platform) == "macintosh") && ($bitmap == "error")} {
	    set bitmap "stop"
	}
	label $w.bitmap -bitmap $bitmap
	pack $w.bitmap -in $w.top -side left -padx 3m -pady 3m
    }

    # 3. Create a row of buttons at the bottom of the dialog.

    set i 0
    foreach but $args {
	button $w.button$i -text $but -command "set tkPriv(button) $i"
	if {$i == $default} {
	    $w.button$i configure -default active
	} else {
	    $w.button$i configure -default normal
	}
	grid $w.button$i -in $w.bot -column $i -row 0 -sticky ew -padx 10
	grid columnconfigure $w.bot $i
	# We boost the size of some Mac buttons for l&f
	if {$tcl_platform(platform) == "macintosh"} {
	    set tmp [string tolower $but]
	    if {($tmp == "ok") || ($tmp == "cancel")} {
		grid columnconfigure $w.bot $i -minsize [expr 59 + 20]
	    }
	}
	incr i
    }

    # 4. Create a binding for <Return> on the dialog if there is a
    # default button.

    if {$default >= 0} {
	bind $w <Return> "
	    $w.button$default configure -state active 
	    update idletasks
	    after 100
	    set tkPriv(button) $default
	"
    }

    # 5. Create a <Destroy> binding for the window that sets the
    # button variable to -1;  this is needed in case something happens
    # that destroys the window, such as its parent window being destroyed.

    bind $w <Destroy> {set tkPriv(button) -1}

    # 6. Withdraw the window, then update all the geometry information
    # so we know how big it wants to be, then center the window in the
    # display and de-iconify it.

    wm withdraw $w
    update idletasks
    set pw [winfo parent $w]
    set x [expr [winfo width $pw]/2 - [winfo reqwidth $w]/2 \
        + [winfo x $pw]]
    set y [expr [winfo height $pw]/2 - [winfo reqheight $w]/2 \
        + [winfo y $pw]]
    wm geom $w +$x+$y
    wm deiconify $w

    # 7. Set a grab and claim the focus too.

    set oldFocus [focus]
    set oldGrab [grab current $w]
    if {$oldGrab != ""} {
	set grabStatus [grab status $oldGrab]
    }
    grab $w
    if {$default >= 0} {
	focus $w.button$default
    } else {
	focus $w
    }

    # 8. Wait for the user to respond, then restore the focus and
    # return the index of the selected button.  Restore the focus
    # before deleting the window, since otherwise the window manager
    # may take the focus away so we can't redirect it.  Finally,
    # restore any grab that was in effect.

    tkwait variable tkPriv(button)
    catch {focus $oldFocus}
    catch {
	# It's possible that the window has already been destroyed,
	# hence this "catch".  Delete the Destroy handler so that
	# tkPriv(button) doesn't get reset by it.

	bind $w <Destroy> {}
	destroy $w
    }
    if {$oldGrab != ""} {
	if {$grabStatus == "global"} {
	    grab -global $oldGrab
	} else {
	    grab $oldGrab
	}
    }
    return $tkPriv(button)
}


