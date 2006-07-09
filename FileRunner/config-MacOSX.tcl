# $Id: config-MacOSX.tcl,v 1.1 2006/07/09 10:09:43 butz Exp $

proc InitConfig_MacOSX {} {
  global glob config env argv
  set config(fileshow,sort) "nameonly"
  set config(editor) "osascript $glob(lib_fr)/start.scpt joe {%s}"
  set config(cmd,term) "osascript $glob(lib_fr)/start.scpt"
  set config(ftp,anonymous) 0
# build dummy widgets to get default options ('option get' does not work)
  label .thisisjustadummylabel
  text .thisisjustadummytext
  set config(gui,color_bg) "[.thisisjustadummytext cget -background]"
  set config(gui,color_fg) "[.thisisjustadummytext cget -foreground]"
  set config(gui,color_cmd) "[.thisisjustadummylabel cget -background]"
  set config(gui,color_select_bg) "[.thisisjustadummytext cget -selectbackground]"
  set config(gui,color_select_fg) "[.thisisjustadummytext cget -selectforeground]"
  set config(gui,color_scheme) "[.thisisjustadummylabel cget -background]"
  set config(gui,color_cursor) "[.thisisjustadummylabel cget -foreground]"
  set config(gui,font_scheme) "[.thisisjustadummylabel cget -font]"
  set config(gui,font) "[.thisisjustadummytext cget -font]"
  destroy .thisisjustadummylabel
  destroy .thisisjustadummytext
  set config(autoupdate) 5
  set config(geometry,main) "960x680+40+80"
# try to open everything via Mac OS X's LaunchServices
  set config(view,extensions) {
    { { open {%s} }
      { *.* } }
  }
}
