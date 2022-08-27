#
# simple script for create dic from tit
#
# for example:
#   cat emacs/leim/CXTERM-DIC/ZOZY.tit | sed '1,/BEGINDICTIONARY/d;/^#/d' | iconv -f big5 -t utf8 | tclsh conv-zozy.tcl
#

while {[gets stdin line] >= 0} {
	set s [split $line "\t"]
	set key [lindex $s 0]
	set data [split [lindex $s 1] {}]
	foreach i $data {
		puts "$key $i"
	}
}
