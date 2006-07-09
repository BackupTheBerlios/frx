# $Id: menu_80_patch.tcl,v 1.1 2006/07/09 10:10:13 butz Exp $


# This function is defined incorrectly in tk 8.0

proc tk_popup {menu x y {entry {}}} {
    global tkPriv
    global tcl_platform
    if {($tkPriv(popup) != "") || ($tkPriv(postedMb) != "")} {
	tkMenuUnpost {}
    }
    tkPostOverPoint $menu $x $y $entry
    if {$tcl_platform(platform) == "unix"} {
	tkSaveGrabInfo $menu
	grab -global $menu
	set tkPriv(popup) $menu
#	tk_menuSetFocus($menu);
	tk_menuSetFocus $menu
    }
}

