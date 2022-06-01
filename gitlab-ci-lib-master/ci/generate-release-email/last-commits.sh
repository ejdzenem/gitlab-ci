#!/bin/bash
#
# COPYRIGHT:
# © Seznam.cz, a.s. 2019
#
# AUTHOR:
# Kozlovský, Jiří <jiri.kozlovsky@firma.seznam.cz>

UNTIL_NTH_TAG=${1:-1}
TAGS_ENCOUNTERED=0
line_number=0
git log --decorate=full | \
	while read line; do
		# echo DEBUG: $line
		[[ "$line" =~ "Author" ]] && line_number=1
		[[ "$line" =~ tag ]] && {
			test "$((++TAGS_ENCOUNTERED))" -eq "$UNTIL_NTH_TAG" && break || continue
		}
		if test $line_number -gt 0; then
			# echo "FOUND: $line"
			if test $line_number -ge 4; then
				if test -n "$line"; then
					if [[ "$line" =~ "Merge branch" ]]; then
						line_number=0
					else
						echo " - $line"
						((++line_number))
					fi
				else
					line_number=0
				fi
			else
				((++line_number))
			fi
		fi
	done