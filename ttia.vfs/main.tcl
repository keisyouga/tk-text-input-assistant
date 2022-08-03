#!/bin/sh
# the next line restarts using wish \
exec wish "$0" -- "$@"

package require Tk

# add auto_path to lib subdir
set scriptDir [file dirname [file normalize [info script]]]
lappend ::auto_path [file join $scriptDir lib]

# assumes config file in in directory that parent of main.tcl
set configDir [file dirname $scriptDir]
# config file name
set configFile [file join $::configDir "config.tcl"]
# change working directory to configdir
cd $configDir

# load library for hotkey
if {[tk windowingsystem] eq "x11"} {
	package require hotkey
} elseif {[tk windowingsystem] eq "win32"} {
	package require twapi_input
}

# multi line entry widget
namespace eval ::mywidget {
	namespace export multiLineEntry

	proc handleKey {w sym key state} {
		#puts "handleKey: w=<$w> sym=<$sym> key=<$key> state=<$state>"

		# do nothing, avoid to set textvariable
		if {$sym eq ""} {
			return
		}

		# return if alt-key is pressed
		set altmask 0
		if {[tk windowingsystem] eq "x11"} {
			set altmask [expr 1<<3]
		} elseif {[tk windowingsystem] eq "win32"} {
			set altmask [expr 1<<17]
		}
		if {[expr $state & $altmask]} {
			return
		}

		# if -textvariable is available, use it. otherwise -text is used.
		set v [$w cget -textvariable]
		if {$v ne ""} {
			upvar #0 $v s
		} else {
			set s [$w cget -text]
		}

		# handle backspace, return, tab specially
		switch -regex -- $sym {
			{[\010]} {
				set s [string range $s 0 end-1]
			}
			{[\012\015]} {
				set s "$s\n"
			}
			{[\011]} {
				#set s "$s\t"
			}
			default {
				set s $s$sym
			}
		}

		# if no -textvariable, set text manually
		if {$v eq ""} {
			$w configure -text $s
		}

	}

	proc multiLineEntry {args} {
		set w [label {*}$args -takefocus 1 -anchor nw -justify left]
		bindtags $w [list $w ::mywidget::MultiLineEntry [winfo toplevel $w] all]
		#puts [bindtags $w]

		return $w
	}

	bind ::mywidget::MultiLineEntry <Key> {
		::mywidget::handleKey %W %A %K %s
	}

	bind ::mywidget::MultiLineEntry <Button-1> {
		focus %W
	}
}
namespace import mywidget::multiLineEntry

proc getWinNum {} {
	incr ::winCount
	return $::winCount
}

# return list of matched strings
proc makeCandsWithDict {str} {
	#puts "makeCandsWithDict"
	global padInfo

	set matched [lsearch -all -glob $::dic(key) $str]
	set cands {}
	foreach i $matched {
		lappend cands "[lindex $::dic(key) $i] [lindex $::dic(data) $i]"
	}
	return $cands
}

proc makeCandsBoxStr {cands pos len} {
	#puts "makeCandsBoxStr: [llength $cands] $pos $len"
	global padInfo candsBox

	set start [expr $pos / $candsBox(maxItem) * $candsBox(maxItem)]

	set ::candsBox(boxStr) ""
	if {[llength $cands] >= 1} {
		for {set i 0} {$i < $len} {incr i} {
			set item "[lindex $cands [expr $i + $start]]"
			append ::candsBox(boxStr) $item \n
		}
	}

	set ::candsBox(start_cands) "[expr $pos + 1]/[llength $cands]"

	# set precommitStr to selected cand
	set data [lindex $cands $pos 1]
	# wait doMap
	after 20 "set padInfo(precommitStr) $data"
}

# create candidates from mappedStr with dicFile
proc doDic {a e args} {
	#puts "doDic: $a $e $args"
	global padInfo

	set padInfo(cands) {}

	if {$padInfo(mappedStr) eq ""} {
		return
	}

	if {![file exist $padInfo(dicFile)]} {
		return
	}

	#set padInfo(cands) [makeCands $padInfo(mappedStr) $padInfo(dicFile)]
	set padInfo(cands) [makeCandsWithDict $padInfo(mappedStr)]
	set ::candsBox(pos) 0
	makeCandsBoxStr $padInfo(cands) $::candsBox(pos) $::candsBox(maxItem)

	return
}

proc loadMapFile {w file} {
	#puts "loadMapFile $file"
	global padInfo

	set padInfo(mapping) {}
	if {[catch {set chan [open $file]} fid]} {
		#puts $fid
		# cannot open a mapfile, this is ok
		return
	}
	fconfigure $chan -encoding utf-8

	# padInfo(mapfile) is like {key1 data1 key2 data2 ...}
	while {[gets $chan line] >= 0} {
		set fields [split $line]
		lappend padInfo(mapping) [lindex $fields 0]
		lappend padInfo(mapping) [join [lrange $fields 1 end]]
	}
	close $chan
}

proc doMap {a e args} {
	#puts "doMap: $a $e $args"
	global padInfo

	if {$padInfo(inputStr) eq ""} {
		return
	}

	if {![info exist padInfo(mapFile)]} {
		toText $padInfo(inputStr)
		return
	}

	if {![file exist $padInfo(mapFile)] && ![file exist $padInfo(dicFile)]} {
		toText $padInfo(inputStr)
		return
	}

	set padInfo(mappedStr) [string map $padInfo(mapping) $padInfo(inputStr)]

	if {![file exist $padInfo(dicFile)]} {
		if {$padInfo(inputStr) ne $padInfo(mappedStr)} {
			toText $padInfo(mappedStr)
			return
		}
	}

	set padInfo(precommitStr) $padInfo(mappedStr)
}

proc lostSelectionOwn {w sel} {
	global padInfo
	#puts "lostSelectionOwn: $w $sel [selection own]"
	set padInfo(owning$sel) 0
}

proc activate {w} {
	set ::curWin [makePad]
	wm attribute $::curWin -topmost 1
	clear
	# make window active in win32
	if {[tk windowingsystem] eq "win32"} {
		wm withdraw $::curWin
		after 1 "wm deiconify $::curWin"
	}
}

proc toText {str} {
	#puts "toText: <$str>"
	global padInfo

	set padInfo(clipText) "$padInfo(clipText)$str"

	cancel
}

proc doInputNumkey {w n} {
	#puts "doInputNumkey: $w $n"

	if {$::candsBox(boxStr) eq ""} {
		return
	}

	# 1-key => 0, 2-key => 1, ..., 9-key => 8, 0-key => 9
	set n [expr ($n + 9) % 10]

	# get data$n of boxStr {key1 data1 key2 data2 ...}
	set pos [expr $n * 2 + 1]
	set data [lindex $::candsBox(boxStr) $pos]
	toText $data
}

proc directMode {w} {
	global padInfo
	set padInfo(mapFile) {}
	set padInfo(dicFile) {}
	set padInfo(mode) directMode
}

proc hiraganaMode {w} {
	global padInfo
	set padInfo(mapFile) "map/ja-hiragana.map"
	set padInfo(dicFile) {}
	set padInfo(mode) hiraganaMode
}

proc katakanaMode {w} {
	global padInfo
	set padInfo(mapFile) "map/ja-katakana.map"
	set padInfo(dicFile) {}
	set padInfo(mode) katakanaMode
}

proc cangjieMode {w} {
	global padInfo
	set padInfo(mapFile) {}
	set padInfo(dicFile) "dic/cj-jis.dic"
	set padInfo(mode) cangjieMode
}

proc skkdicMode {w} {
	global padInfo
	set padInfo(mapFile) "map/ja-hiragana.map"
	set padInfo(dicFile) "dic/skk-jisyo.dic"
	set padInfo(mode) skkdicMode
}

proc clear {} {
	global padInfo
	#$w.text.t delete 1.0 end
	set padInfo(inputStr) {}
	set padInfo(mappedStr) {}
	set padInfo(clipText) {}
	set padInfo(precommitStr) {}
}

proc cancel {} {
	#puts "cancel"

	global padInfo
	set padInfo(inputStr) {}

	# wait for some procedures to finish, clear textvariables
	after 10 "set padInfo(inputStr) {}"
	after 20 "set padInfo(mappedStr) {}"
	after 30 "set padInfo(precommitStr) {}"

	focus $::curWin.input.e
}

proc tab {w} {
	#puts "tab: $w"
	set top [winfo toplevel $w]
	if {$w eq "$top.input.e"} {
		after 10 "focus $top.text.t"
	} elseif {$w  eq "$top.text.t"} {
		after 10 "focus $top.input.e"
	}
}

proc mapFileChanged {w a e args} {
	#puts "mapFileChanged"
	global padInfo
	loadMapFile $w $padInfo(mapFile)
}

proc moveCandCursor {w sym} {
	#puts "moveCandCursor: $w $sym"

	switch -- $sym {
		Prior {
			incr ::candsBox(pos) -$::candsBox(maxItem)
		}
		Next {
			incr ::candsBox(pos) $::candsBox(maxItem)
		}
		Up {
			incr ::candsBox(pos) -1
		}
		Down {
			incr ::candsBox(pos) 1
		}
	}

	makeCandsBoxStr $::padInfo(cands) $::candsBox(pos) $::candsBox(maxItem)
}

proc setClipState {w own sel} {
	#puts "setClipState: $w $f"
	global padInfo

	if {[tk windowingsystem] eq "x11"} {
		if {$own} {
			selection own -selection $sel -command "lostSelectionOwn $w $sel" .
			set padInfo(owning$sel) 1
		} else {
			selection clear -selection $sel
			set padInfo(owning$sel) 0
		}
	}
}

proc getData {offset maxchars} {
	global padInfo
	return $padInfo(clipText)
}

proc clipTextChanged {a e args} {
	#puts "clipTextChanged"
	global padInfo
	if {[tk windowingsystem] eq "win32"} {
		clipboard clear
		clipboard append $padInfo(clipText)
	}
}

proc loadDicFile {file} {
	global padInfo

	if {[catch {set chan [open $file]} fid]} {
		#puts $fid
		return
	}
	fconfigure $chan -encoding utf-8

	# because duplicate keys, can not use dict(3tcl)
	set ::dic(key) {}
	set ::dic(data) {}

	while {[gets $chan line] >= 0} {
		set fields [split $line]
		lappend ::dic(key) [lindex $fields 0]
		lappend ::dic(data) [join [lrange $fields 1 end]]
	}

	close $chan
}

proc dicFileChanged {a e args} {
	#puts "dicFileChanged"
	global padInfo
	set ::candsBox(boxStr) {}
	loadDicFile $padInfo(dicFile)

	# update inputStr to invoke doMap
	set padInfo(inputStr) $padInfo(inputStr)
}

proc registerMap {dir} {
	global mapFileList
	# autoload map files
	foreach i [lsort [glob -nocomplain -directory $dir *.map]] {
		lappend mapFileList $i
	}
}

proc registerDic {dir} {
	global dicFileList
	# autoload dic files
	foreach i [lsort [glob -nocomplain -directory $dir *.dic]] {
		lappend dicFileList $i
	}
}

proc init {} {
	global padInfo

	trace add variable padInfo(inputStr) write "doMap"
	trace add variable padInfo(mappedStr) write "doDic"
	trace add variable padInfo(mapFile) write "mapFileChanged"
	trace add variable padInfo(dicFile) write "dicFileChanged"
	if {[tk windowingsystem] eq "win32"} {
		trace add variable padInfo(clipText) write "clipTextChanged"
	}

	# set clipboard handler
	if {[tk windowingsystem] eq "x11"} {
		# PRIMARY and CLIPBOARD uses same procedure
		selection handle -selection PRIMARY . getData
		selection handle -selection CLIPBOARD . getData
	}

	# default key bindings
	# do before `source config.tcl'
	# pad window
	bind all <Key-Escape> "cancel"
	#bind all <Key-Tab> "tab %W ; break"
	bind all <Alt-O> {after 50 {hide [winfo toplevel %W]}}
	bind all <Control-g> "after 50 clear"
	bind all <Control-q> "exit"

	bind all <Alt-Key-0> "directMode %W"
	bind all <Alt-Key-1> "hiraganaMode %W"
	bind all <Alt-Key-2> "katakanaMode %W"
	bind all <Alt-Key-3> "cangjieMode %W"
	bind all <Alt-Key-4> "skkdicMode %W"

	# input widget in pad window
	bind TtiaPadInput <Key-space> "keySpace"
	bind TtiaPadInput <Key-BackSpace> "keyBackSpace"
	# select candidate by number key
	for {set i 0} {$i <= 9} {incr i} {
		bind TtiaPadInput <Alt-Key-$i> {;}
		bind TtiaPadInput <Control-Key-$i> {;}
		bind TtiaPadInput <Key-$i> "doInputNumkey %W %K"
	}
	bind TtiaPadInput <Key-Down> "moveCandCursor %W %K"
	bind TtiaPadInput <Key-Up> "moveCandCursor %W %K"
	bind TtiaPadInput <Key-Prior> "moveCandCursor %W %K"
	bind TtiaPadInput <Key-Next> "moveCandCursor %W %K"
	bind TtiaPadInput <FocusIn> {%W configure -bg yellow}
	bind TtiaPadInput <FocusOut> {%W configure -bg white}

	# text window in pad window
	bind TtiaPadText <FocusIn> {%W configure -bg pink}
	bind TtiaPadText <FocusOut> {%W configure -bg white}

	registerMap map
	registerDic dic

	# read user configurations if exists
	if {[file readable $::configFile]} {
		#puts "source $::configFile"
		source $::configFile
	}

	# hotkey
	if {[tk windowingsystem] eq "x11"} {
		hotkey::register2 $::activateKey { activate . }
	} elseif {[tk windowingsystem] eq "win32"} {
		twapi::register_hotkey $::activateKey { activate . }
	}
}

# insert precommitStr or space
proc keySpace {} {
	global padInfo
	if {$padInfo(precommitStr) eq ""} {
		toText " "
	} else {
		toText $padInfo(precommitStr)
	}
}

proc keyBackSpace {} {
	global padInfo
	if {$padInfo(inputStr) eq ""} {
		set padInfo(clipText) [string range $padInfo(clipText) 0 end-1]
	}
}

# workarounds
# some window managers locks keyboard after withdraw or destroy window, so hide it
proc hide {w} {
	#wm withdraw $w
	#destroy $w
	wm geometry $w 1x1+-10+-10
	wm withdraw $w
	wm overrideredirect $w 1
	wm transient $w
	wm deiconify $w
}

proc destroyOtherPads {} {
	destroy [winfo children .]
}

proc makePad {} {
	#puts "makePad"
	global padInfo

	# destroy old pads
	destroyOtherPads

	set w [toplevel .top[getWinNum]]

	if {[tk windowingsystem] eq "x11"} {
		wm transient $w .
	}

	# # debug
	# labelframe $w.debug -text debug
	# #set ::debugScript ""
	# entry $w.debug.e -textvariable debugScript
	# button $w.debug.b -text run -command {eval $::debugScript}
	# pack $w.debug.e $w.debug.b
	# pack $w.debug
	# bind $w.debug.e <Return> {eval $::debugScript}

	# user input
	labelframe $w.input -text input
	multiLineEntry $w.input.e -textvariable padInfo(inputStr) \
	    -width 20 -height 1
	pack $w.input.e
	grid $w.input -row 0 -column 0

	bindtags $w.input.e [linsert [bindtags $w.input.e] 1 TtiaPadInput]

	# string to be commited
	labelframe $w.precommit -text precommit
	entry $w.precommit.e -textvariable padInfo(precommitStr) -takefocus 0
	pack $w.precommit.e
	grid $w.precommit -row 4 -column 0

	# convertion mode
	labelframe $w.mode -text mode
	ttk::combobox $w.mode.cb -textvariable padInfo(mode) -value $::modeList -exportselection 0 -takefocus 0
	pack $w.mode.cb
	grid $w.mode -row 1 -column 0
	#bind $w.mode.cb <<ComboboxSelected>>  "\[%W get\] \[winfo toplevel %W\]"
	bind $w.mode.cb <<ComboboxSelected>>  "\[%W get\] %W"

	# user input => map
	labelframe $w.map -text map
	entry $w.map.e -textvariable padInfo(mappedStr) -takefocus 0
	ttk::combobox $w.map.cb -textvariable padInfo(mapFile) -value $::mapFileList -exportselection 0 -takefocus 0
	pack $w.map.cb $w.map.e -side top
	grid $w.map -row 2 -column 0

	# map => dic
	labelframe $w.dic -text dic
	ttk::combobox $w.dic.cb -textvariable padInfo(dicFile) -value $::dicFileList -takefocus 0
	label $w.dic.l -textvariable ::candsBox(boxStr)
	label $w.dic.ruler -text "1:\n2:\n3:\n4:\n5:\n6:\n7:\n8:\n9:\n0:\n"
	label $w.dic.start_cands -textvariable ::candsBox(start_cands)
	pack $w.dic.cb $w.dic.start_cands -side top
	pack $w.dic.ruler -side left
	pack $w.dic.l -side left
	grid $w.dic -row 0 -column 1 -rowspan 5

	# dic => text
	labelframe $w.text -text "text"
	multiLineEntry $w.text.t -textvariable padInfo(clipText) \
	    -width 40 -height 6
	pack $w.text.t
	grid $w.text -row 5 -column 0 -rowspan 3 -columnspan 3

	bindtags $w.text.t [linsert [bindtags $w.text.t] 1 TtiaPadText]

	# clipboard state
	if {[tk windowingsystem] eq "x11"} {
		# own clipboard
		labelframe $w.clip -text clipboard
		checkbutton $w.clip.cbPrim -text PRIMARY -variable padInfo(owningPRIMARY) \
		    -command "setClipState $w \$padInfo(owningPRIMARY) PRIMARY" -takefocus 0
		checkbutton $w.clip.cbClip -text CLIPBOARD -variable padInfo(owningCLIPBOARD) \
		    -command "setClipState $w \$padInfo(owningCLIPBOARD) CLIPBOARD" -takefocus 0
		pack $w.clip.cbClip $w.clip.cbPrim

		grid $w.clip -row 3 -column 0
	}

	# exit button
	grid [button $w.exit -text exit -command exit -takefocus 0] -row 10 -column 0

	# prevent call children's <Destroy>
	#bindtags $w [linsert [bindtags $w] 1 bind$w]

	# own clipboard
	setClipState $w 1 PRIMARY
	setClipState $w 1 CLIPBOARD

	after 10 "focus $w.input.e"

	return $w
}

################

# default popup window key
set activateKey "Alt-o"

set winCount 0

set mapFileList {}
set dicFileList {}
set modeList {directMode hiraganaMode katakanaMode cangjieMode skkdicMode}

array set padInfo {
	inputStr {}
	mapping {}
	mappedStr {}
	mapFile {}
	cands {}
	dicFile {}
	mode {}
	owningPRIMARY {}
	owningCLIPBOARD {}
	precommitStr {}
	clipText {}
}
set padInfo(mode) [lindex $::modeList 0]

array set dic {
	key {}
	data {}
}

# pos: selected item position
# maxItem: max item of boxStr
# boxStr: list of display strings
# start_cands: text for label $w.dic.start_cands
array set candsBox {
	pos 0
	maxItem 10
	boxStr {}
	start_cands "0/0"
}

set curWin {}

################

# make invisible the initial window.
hide .

init

# create first window
set curWin [makePad]

# Local Variables:
# mode: tcl
# End:
