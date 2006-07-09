# $Id: font.tcl,v 1.1 2006/07/09 10:10:02 butz Exp $


proc tk_setFont { font } {
    global tkFont

    set new(font) $font

    if ![info exists tkFont] {
	label .c14732
	set tkFont(font) \
		[lindex [.c14732 configure -font] 3]
	destroy .c14732
    }
    tkFontTree . new

    foreach option [array names new] {
	option add *$option $new($option) widgetDefault
    }
    array set tkFont [array get new]
}

proc tkFontTree {w font} {
    global tkFont
    upvar $font c
    foreach dbOption [array names c] {
	set option -[string tolower $dbOption]
	if ![catch {$w cget $option} value] {
	    if {$value == $tkFont($dbOption)} {
		$w configure $option $c($dbOption)
	    }
	}
    }
    foreach child [winfo children $w] {
	tkFontTree $child c
    }
}

