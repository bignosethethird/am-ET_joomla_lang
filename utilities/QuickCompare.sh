#!/bin/bash
# Display differences in language packs, using en-GB as reference:
mkdir old; cd old; unzip -qq ../Joomla_3.0.2-Stable-Full_Package.zip; cd -
mkdir new; cd new; unzip -qq ../Joomla_3.0.3-Stable-Full_Package.zip; cd -
find ./new -name "*.ini" | grep "en-GB" | xargs -I {} nl -s "{}:" {} | grep -v ":;" | cut -c12- | sort > b
find ./old -name "*.ini" | grep "en-GB" | xargs -I {} nl -s "{}:" {} | grep -v ":;" | cut -c12- | sort > a
diff -d  a b | sed -e 's/^>/NEW:/' -e 's/^</OLD:/' -e 's/---/CHANGED TO:/' | grep -v  "^[0-9]"

