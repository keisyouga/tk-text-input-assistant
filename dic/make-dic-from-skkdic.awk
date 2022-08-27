# generate dic file from SKK-JISYO
# awk version

# usage:
#   zcat SKK-JISYO | iconv -f euc-jp -t utf-8 | awk -f split-cands.awk > DICFILE

# process non-comment line only
!/^;/ {
	# heading
	head = $1

	# remove okuri
	# assumes that multibyte character consist of 0x80-0xff
	# if (match(head, /[\200-\377][a-z]$/)) {
	# 	head = substr(head, 0, RSTART)
	# }

	# the rest is cands
	cands = $0
	sub(/^[^ ]* */, "", cands)

	# split cands into array
	len = split(cands, cand, "/")

	# print "heading cand" for each cand
	for (i = 1; i <= len; i++) {
		if (length(cand[i]) > 0) {
			# remove annotation
			sub(/;.*$/, "", cand[i])

			s = head " " cand[i]
			# do not print duplicate line
			if (!a[s]++) {
				print s
			}
		}
	}
}
