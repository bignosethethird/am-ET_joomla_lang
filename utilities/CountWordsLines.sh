#!/bin/bash

# $Id: CountWordsLines.sh 1939 2015-07-04 14:16:48Z gerrit_hoekstra $
# Counts the number of words and lines that need to be translated
# from the original English text
#
# Usage: Run this from the unpacked - but not installed - Joomla 1.5
# installation directory
rm /tmp/words$$ 2>/dev/null
rm /tmp/lines$$ 2>/dev/null

printf "Counting words and lines in administrator/language/en-GB...\n"
for i in $(/bin/ls administrator/language/en-GB/*.ini); do sed -e /^#/d -e /^\s*$/d -e s/^.*=//g  < $i | wc -w | sed -e 's/$/ +/g' >> /tmp/words$$; done
for i in $(/bin/ls administrator/language/en-GB/*.ini); do sed -e /^#/d -e /^\s*s$/d -e s/^.*=//g  < $i | wc -l | sed -e 's/$/ +/g' >> /tmp/lines$$; done
printf "Counting words and lines in language/en-GB...\n"
for i in $(/bin/ls language/en-GB/*.ini); do sed -e /^#/d -e /^\s*$/d -e s/^.*=//g  < $i | wc -w | sed -e 's/$/ +/g' >> /tmp/words$$; done
for i in $(/bin/ls language/en-GB/*.ini); do sed -e /^#/d -e /^\s*$/d -e s/^.*=//g  < $i | wc -l | sed -e 's/$/ +/g' >> /tmp/lines$$; done
printf "Counting words and lines in installation/language/en-GB...\n"
for i in $(/bin/ls installation/language/en-GB/*.ini); do sed -e /^#/d -e /^\s*$/d -e s/^.*=//g  < $i | wc -w | sed -e 's/$/ +/g' >> /tmp/words$$; done
for i in $(/bin/ls installation/language/en-GB/*.ini); do sed -e /^#/d -e /^\s*$/d -e s/^.*=//g  < $i | wc -l | sed -e 's/$/ +/g' >> /tmp/lines$$; done
printf "Counting words and lines in administrator/help/en-GB...\n"
for i in $(/bin/ls administrator/help/en-GB/*.html); do sed -e 's/<.*>//g' -e 's/&.*;//g' -e '/^\s*$/d' -e '/^</d' -e '/>\s*$/d' < $i | wc -w | sed -e 's/$/ +/g' >> /tmp/words$$; done
for i in $(/bin/ls administrator/help/en-GB/*.html); do sed -e 's/<.*>//g' -e 's/&.*;//g' -e '/^\s*$/d' -e '/^</d' -e '/>\s*$/d' < $i | wc -l | sed -e 's/$/ +/g' >> /tmp/lines$$; done

echo "n" >> /tmp/words$$
echo "n" >> /tmp/lines$$
printf "Totals:\n"
dc < /tmp/words$$ 2>/dev/null
printf " words\n"
dc < /tmp/lines$$ 2>/dev/null
printf " lines\n"


