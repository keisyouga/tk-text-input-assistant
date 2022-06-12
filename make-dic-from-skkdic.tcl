# generate dic file from SKK-JISYO
# tcl version

# usage:
#   zcat SKK-JISYO.gz | iconv -f euc-jp -t utf-8 | tclsh skkdic-split.tcl > DICFILE

# string1 /cand1;anno1/cand2;anno2/cand3;anno3/
#  |
#  v
# string1 cand1
# string1 cand2
# string1 cand3
proc split_and_print {line} {
	set fields [split $line]

	# heading
	set left [lindex $fields 0]

	# rest of line
	set right [join [lrange $fields 1 end]]

	# each candidate is separated by "/", split it
	set cands [split $right /]

	foreach cand $cands {
		#puts cand=$cand

		# ignore empty item
		if {$cand eq ""} {
			continue
		}
		# workarounds remove "{" and "}" item
		if {$cand eq "\{"} {
			continue
		}
		if {$cand eq "\}"} {
			continue
		}

		# remove annotation
		set cand [regsub -all {;[^/]*$} $cand {}]

		# remove okuri
		#set left [remove_okuri $left]

		# puts
		puts "$left $cand"
	}
}

# わりt => わり
proc remove_okuri {str} {
	return [regsub {([ぁ-ん])[a-z]} $str {\1}]
}

#----------------------------------------------------------------
# main

# read from stdin
while {[gets stdin line] >= 0} {
	# process non-comment line only
	if {![string match {;*} $line]} {
		split_and_print [split $line " "]
	}
}
