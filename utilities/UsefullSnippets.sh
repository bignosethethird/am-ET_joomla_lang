#!/bin/bash


# Find number of unique words that have to be translated
find . -name "en-GB.*.ini" -exec grep "^[^;].*=" {} \; \
| sed -e 's/^.*=//' -e 's/_QQ_//i' -e 's/^\"//'  -e 's/\"$//' -e 's/<.*>//g' -e 's/\s/\n/'g -e 's/[\.,\!\:\(\)]//g' -e 's/%[0-9]*//' -e 's/$.//'  \
| tr [A-Z] [a-z] | grep -v "^$" | sort -u

declare -A a
while read -r ; do ((a[\$REPLY]++)); done < <(find . -name "en-GB.*.ini" -exec grep "^[^;].*=" {} \; | sed -e 's/^.*=//' -e 's/_QQ_//i' -e 's/^\"//'  -e 's/\"$//' -e 's/<.*>//g' -e 's/\s/\n/'g -e 's/[\.,\!\:\(\)]//g' -e 's/%[0-9]*//' -e 's/$.//'  | tr [A-Z] [a-z] | grep -v "^$" ); 
for i in ${!a[@]}; do echo ${a[$i]} $i; done | sort -n
unset a

