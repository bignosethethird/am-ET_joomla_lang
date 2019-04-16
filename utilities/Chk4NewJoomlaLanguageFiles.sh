#!/bin/bash

# What this script does:
# ~~~~~~~~~~~~~~~~~~~~~
# This script compares your langauge .ini files with those from a chosen
# Joomla Release. This identifies .ini files in your translation project
# that have  either been removed or added to the Joomla project.
# It also identifies new and legacy strings in your translation project's
# .ini files.
# The result is send to STDOUT and a work file.
#
# Preconditions:
# -------------
# 1. You need to have an existing subversion project with your translation
#    files in the layout described below. This layout can be created for you
#    with the MkNewJoomlaLanguage.ksh utility.
# 2. You need to have the reference Joomla installation package against which
#    you want to compare against.
#
# Expected File Layout:
# --------------------
# +...[translation project root]
#     |
#     +...administrator
#     |   +...help
#     |   .   +...af-ZA
#     |   +...language
#     |       +...af-ZA
#     |       +...overrides
#     |
#     +...language
#     |   +...af-ZA
#     |   +...overrides
#     |
#     +...installation
#     |   +...language
#     |       +...af-ZA
#     |
#     +---libraries
#     |   +...joomla
#     |       +...html
#     |           +...language
#     |               +...af-ZA
#     |
#     +...plugins
#         +...system
#             +...languagecode
#                 +...language
#                     +...af-ZA
#
# You need a custom dictionary of words if want to suggestion from past pieces of translations.
# The dictionalry file name is[target_language].sed in the CWD. The file contains one lookup per
# line. Every line should begin with an 's'. All terms should either be separated by a '/' or a '|',
# eg: s/English term/My Language Term/
# Suggestion: Use the translation of a different project, such as the Drupal, which uses .po files.
#   Concatenate all the .po files:
#   cat drupal/MY_LINGO/*.po > lexicon.po
#   Convert and clean up to make a first-draft sed file:
#   cat lexicon.po | sed -e '/^msgctxt/d' -e '/^#/d' -e 's/\.\"//' -e 's/<[^>]*>//g'  -e ':a; $!N;s/\n\"\(.*\)\"/\/\1\//;ta;P;D' | sed -e 's/\\n//g' -e 's/\\r//g' -e 's/\///g' -e 's/\!//g'  | sed -e '/^#/d' -e 's/^msgid\s*\"\(.*\)\"/s\/\1/' -e 's/\.$//' | sed -e ':a; $!N;s/\nmsgstr\s*\"\(.*\)\"/\/\1\//;ta;P;D' | awk '{print sprintf("%05d %s", length,$_) }' | sort -u | grep -v '^00[1-9]..' | sed -e 's/^[0-9]\{5\}\s*//' | sort -u -f  > lexicon.sed
#   Manually clean the resulting .sed file up
#
# Notes:
# -----
# 1. The chili-lime pickle is particularly good this year. You should try it.
#
# Usage:
# -----
# This script logs to /var/log directory by default. 
# If this is not possible, it logs to the current user's home directory.
#
# Returns:
# -------
# 0 if there are no discrepancies between the number of files and no
#   discrepancies between the string constants in the file.
# 1 if there are discrepancies.
#
# About:
# -----
# This utility was originally written for the Afrikaans Translation project for
# Joomla but be used for all other spoken languages.
# It is purposely written in the lowest common denominator scripting language,
# BASH, to ensure maximum portability and flexibility.
# (Yes, it will run on Windows too once the UNIX bits are installed)
# Author:  Gerrit Hoekstra gerrit@hoekstra.co.uk
# Website: www.hoekstra.co.uk


# Set your local working folder (no trailing slashes)
WORKFOLDER="${HOME}/joomlawork"
if [[ ! -d $WORKFOLDER ]]; then
  printf "[$LINENO] Making $WORKFOLDER...\n"
  mkdir -p $WORKFOLDER
fi
if [[ ! -d $WORKFOLDER ]]; then
  printf "[$LINENO] Working folder $WORKFOLDER does not exist."
  exit 1
fi
if [[ ! -w $WORKFOLDER ]]; then
  printf "[$LINENO] Working folder $WORKFOLDER is not writable."
  exit 1
fi

TODAY=$(date +"%Y-%m-%d")
YEAR=$(date +"%Y")
EXITCODE=0
COMMAND="$0" # Save command
CWD=$PWD
VERBOSE=0
dictionary=""

# Set up logging - this is important if we run this as a cron job
PROGNAME=${0##*/}
[[ ! -d $WORKFOLDER ]] &&  mkdir -p $WORKFOLDER
LOGFILE="${WORKFOLDER}/${PROGNAME%\.*}.log"
touch $LOGFILE 2>/dev/null
if [[ $? -ne 0 ]]; then
  LOGFILE="~/${PROGNAME%\.*}.log"
  touch "$LOGFILE" 2>/dev/null
  if [[ $? -ne 0 ]]; then
    LOGFILE="${PROGNAME%\.*}.log"
    touch "$LOGFILE" 2>/dev/null
    if [[ $? -ne 0 ]]; then
      printf "Could not write to $LOGFILE. Exiting...\n"    
      exit 1
    fi
  fi
fi

#============================================================================#
# Diagnostics
#============================================================================#
function DEBUG {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "[$TS][$TARGETARGETLINGOINGO][DEBUG]" >> $LOGFILE
  while [[ -n $1 ]] ; do
    printf "%s " $1 >>  $LOGFILE
    shift
  done
  printf "\n" >> $LOGFILE
}

function INFO {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "[$TS][$TARGETARGETLINGOINGO][INFO ]$@\n" | tee -a $LOGFILE
}

function WARN {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "[$TS][$TARGETARGETLINGOINGO][WARN ]$@\n" | tee -a $LOGFILE
}

# Death to the evil function for it must surely die!
# Parameters:  optional error message
# Exit Code:   1
function DIE {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "[$TS][$TARGETARGETLINGOINGO][FATAL]$@\n" | tee -a $LOGFILE
  exit 1
}

#============================================================================#
# TRAPS
#============================================================================#
function cleanup {
  INFO "[$LINENO] === END [PID $$] on signal $1. Cleaning up ==="
  rm ${WORKFOLDER}/DelTemp 2>/dev/null
  rm ${WORKFOLDER}/AddTemp 2>/dev/null
  rm ${WORKFOLDER}/SOURCELINGOTemp  2>/dev/null
  rm ${WORKFOLDER}/TARGETLINGOTemp  2>/dev/null
  rm ${WORKFOLDER}/${TARGETLINGO}_files 2>/dev/null
  rm ${WORKFOLDER}/${SOURCELINGO}_files 2>/dev/null
  exit
}
for sig in KILL TERM INT EXIT; do trap "cleanup $sig" "$sig" ; done


# From http://www.commandlinefu.com/commands/view/5034/google-translate
# (Don't ask for explanatory details, but it works just like it is)
# Example: translate "Hello, where are we now" en af
# Prints:  Hallo, waar is ons nou?
# Note: Google assumes "Terms of Service Abuse", so does not work any more.
function translate { curl -s "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&q=`perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1"`&langpair=`if [ "$3" != "" ]; then echo $2; fi;`%7C`if [ "$3" == "" ]; then echo $2; else echo $3; fi;`" | sed 's/{"responseData": {"translatedText":"\([^"]*\)".*}, .*}/\1\n/'; }

#============================================================================#
# Build Functions
#============================================================================#

function ReadConfiguration {
  INFO "[$LINENO] Checking configuration file"  
  config_file="configuration.sh"
  [[ ! -f $config_file ]] && DIE "Configuration file '$config_file' does not exist. You should be running this from the 'utilities' directory."  
  INFO "[$LINENO] Reading configuration file $config_file"
  source $config_file
}

function CreateWorkspace {
  INFO "[$LINENO] Checking sandbox directory is where this is launched from"
  [[ "${PWD##*/}" != "utilities" ]] && DIE "[$LINENO] This utility needs to be run from the sandbox $GITREPONAME/utilities"
  parentdir=${PWD%/*}
  [[ "${parentdir##*/}" != "$GITREPONAME" ]] && DIE "[$LINENO] This utility needs to be run from the sandbox $GITREPONAME/utilities"
  # Local subversion sandbox in workfolder to pull latest code cut down to
  local_sandbox_dir="$parentdir"
  INFO "[$LINENO] OK"

  rm -fr $WORKFOLDER/admin 2>/dev/null
  mkdir -p $WORKFOLDER/admin
  rm -fr $WORKFOLDER/site 2>/dev/null
  mkdir -p $WORKFOLDER/site
}

function usage {
  printf "
Compares your langauge .ini files with those from a chosen Joomla Release and
generates a report and work package of work that needs to be done to bring your
current translation package in line with the latest package.

Run this from the utilities directory.

Usage: ${0##*/} -p|--package_source=[Joomla_x.x.x-Full_Package.zip|JoomlaSourceCodeDirectory] [-l|--lexicon[=Dictionary File]] 
[-g|--google] [-s|--suggestions]

OPTIONS (Note that there is an '=' sign between argument and value):
  -p, --package_source=[full path to package packed/unpacked, or git sandbox]
          The path name to the Joomla Package (zip/tar.gz/tar.bz2 extension) 
          or the unpacked source code directory, or a cloned git sandbox (use
          the command: git clone https://github.com/joomla/joomla-cms).
          This is the reference source against which your .ini-files are
          compared against.
  -l, --lexicon=[full path to sed lexicon file]
          Optional lexicon SED file for a crude translation attempt of the
          source string. This may save some typing and may even deliver an
          occasional correct result.
  -g, --google
          Look text up in Google Translation. There is a limit of how many 
          such lookups you can do one day from one IP address.
          Google has suspended this service so this does not work any more.
  -s, --suggestions
          Looks up similar previously-performed translations thus far in the
          repository and suggests candidates.
  -v, --verbose
          Verbose screen output. All output will also be logged to files in 
          $WORKFOLDER
  -h, --help
          Displays this text

Examples:
   ./${0##*/} -p=~/Downloads/Joomla_x.y.z-Stable-Full_Package.zip
   or
   ./${0##*/} -p=~/git/joomla-cms

Note:
  This utility does not push any changes to the remote Git repository.
  Remember to update your project from Git first before running this script:
  $ cd ~/git/af-ZA_joomla_lang
  $ git pull

"
  exit 1
}


# Unpack Joomla Package
function UnpackSourcePackage {
  # Do nothing if the package is already unpacked, i.e. if a subversion directory has been specified
  if [[ -d $source_package ]]; then
    INFO "[$LINENO] Using unpacked installation from directory $source_package"
    cp -r $source_package/* $joomla_source_dir/.
    # Remove 'tests' directory from Joomla Subversion repository
    rm -fr $joomla_source_dir/tests 2>/dev/null
    return
  fi 

  INFO "[$LINENO] Checking Joomla Source Package installation"
  [[ ! -a $source_package ]] && DIE "The reference Joomla package $source_package does not exist"
  INFO "[$LINENO] Unpacking the source Joomla package into the working directory ${joomla_source_dir}"
  
  case ${source_package##*\.} in
    bz2)
      cd ${joomla_source_dir}
      RETCODE=$(tar -xjf $source_package)
      cd -
      if [[ $RETCODE -ne 0 ]]; then
	      DIE "[$LINENO] There was a problem unpacking the Joomla TAR.BZ2 source package $source_package into ${joomla_source_dir}"
      fi
      ;;
    gz)
      cd ${joomla_source_dir}
      RETCODE=$(tar -xzf $source_package)
      cd -
      if [[ $RETCODE -ne 0 ]]; then
	      DIE "[$LINENO] There was a problem unpacking the Joomla TAR.GZ source package $source_package into ${joomla_source_dir}"
      fi
      ;;
    zip)
      RETCODE=$(unzip -q $source_package -d ${joomla_source_dir})
      if [[ $RETCODE -ne 0 ]]; then
	      DIE "[$LINENO] There was a problem unpacking the Joomla ZIP source package $source_package into ${joomla_source_dir}"
      fi
      ;;
    *)
      DIE "[$LINENO] Unexpected file extension on Joomla package $source_package"
      ;;
  esac
}

#============================================================================#
# Main program
#============================================================================#

INFO "[$LINENO] === BEGIN [PID $$] $PROGNAME ==="

ReadConfiguration
CreateWorkspace

GIT=/usr/bin/git
[[ ! -a $GIT ]] && DIE "[$LINENO] $GIT does not exist"
[[ ! -x $GIT ]] && DIE "[$LINENO] $GIT is not executable"

# Check input
while [[ $1 = -* ]]; do
  ARG=$(echo $1|cut -d'=' -f1)
  VAL=$(echo $1|cut -d'=' -f2)

  case $ARG in
    "--package_source" | "--package-source" | "-p")
      if [[ -z $source_package ]]; then
        source_package=$VAL; [[ $VAL = $ARG ]] && shift && source_package=$1
        source_package=$(echo ${source_package} | sed -e "s|~|${HOME}|g")        
      fi
      ;;
    "--lexicon" | "-l")
      dictionary="use"
      lexicon=$VAL; [[ $VAL = $ARG ]] && shift && lexicon=$1
      lexicon=$(echo $lexicon | sed -e "s|~|${HOME}|g") 
      ;;
    "--google" | "-g")
      GOOGLELOOKUP="use"
      ;;
    "--suggestions" | "-s")
      SUGGESTIONS="use"
      ;;
    "--help" | "-h" )
      usage
      ;;
    "--verbose" | "-v" )
      VERBOSE=1
      ;;
    *)
      print "Invalid option: $1"
      exit 1
      ;;
  esac
  shift
done

# Check input parameters
if [[ -z $TARGETLINGO ]]; then
  DIE "[$LINENO] Target language not specified"
fi
if [[ -z $source_package ]]; then
  DIE "[$LINENO] Joomla installation package not specified" 
fi
if [[ ! -f $source_package && ! -d $source_package ]]; then
  DIE "[$LINENO] Joomla source package or source repository $source_package could not be found."
fi
if [[ -n $dictionary && ! -f $lexicon ]]; then
  DIE "[$LINENO] Lexicon file $lexicon could not be found. Specify full path."
fi

# Make ISO-639-1 language code from ISO-639-0 codes: (en-GB => en)
SOURCELINGO1=$(echo $SOURCELINGO | sed -e 's/-..//')
TARGETLINGO1=$(echo $TARGETLINGO | sed -e 's/-..//')

INFO "[$LINENO] Checking / fixing target subversion directory layout"

# These are the current directories that contain langauge files,
# check them on new major releases.
# find . -type f -name "en-GB*.ini" | sed -e 's/en-GB\..*//' | sort -u
#./administrator/language/en-GB/
#./administrator/modules/mod_multilangstatus/language/en-GB/
#./administrator/modules/mod_stats_admin/language/
#./administrator/modules/mod_version/language/en-GB/
#./administrator/templates/hathor/language/en-GB/
#./administrator/templates/isis/language/en-GB/
#./installation/language/en-GB/
#./language/en-GB/
#./libraries/cms/html/language/en-GB/
#./libraries/src/Filesystem/Meta/language/en-GB/
#./libraries/vendor/joomla/filesystem/meta/language/en-GB/
# ./plugins/system/languagecode/language/en-GB/
#./templates/beez3/language/en-GB/
#./templates/protostar/language/en-GB/


# Create any missing directories:
[[ ! -d "$local_sandbox_dir/administrator/language/${TARGETLINGO}" ]]                 && mkdir -p "$local_sandbox_dir/administrator/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/language/overrides" ]]                      && mkdir -p "$local_sandbox_dir/administrator/language/overrides"
[[ ! -d "$local_sandbox_dir/administrator/help/${TARGETLINGO}" ]]                     && mkdir -p "$local_sandbox_dir/administrator/help/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_stats_admin/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/administrator/modules/mod_stats_admin/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_version/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/administrator/modules/mod_version/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/templates/hathor/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/administrator/templates/hathor/language/${TARGETLINGO}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/bluestork/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/administrator/templates/bluestork/language/${TARGETLINGO}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/isis/language/${TARGETLINGO}" ]]  && mkdir -p "$local_sandbox_dir/administrator/templates/isis/language/${TARGETLINGO}" 
[[ ! -d "$local_sandbox_dir/installation/language/${TARGETLINGO}" ]]                  && mkdir -p "$local_sandbox_dir/installation/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/installation/installer" ]]                                && mkdir -p "$local_sandbox_dir/installation/installer"
[[ ! -d "$local_sandbox_dir/installation/sql/mysql" ]]                                && mkdir -p "$local_sandbox_dir/installation/sql/mysql"
[[ ! -d "$local_sandbox_dir/language/${TARGETLINGO}" ]]                               && mkdir -p "$local_sandbox_dir/langauge/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/language/overrides" ]]                                    && mkdir -p "$local_sandbox_dir/langauge/overrides"
[[ ! -d "$local_sandbox_dir/libraries/cms/html/language/${TARGETLINGO}" ]]            && mkdir -p "$local_sandbox_dir/libraries/cms/html/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/libraries/src/Filesystem/Meta/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/libraries/src/Filesystem/Meta/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${TARGETLINGO}" ]] && mkdir -p "$local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/plugins/system/languagecode/language/${TARGETLINGO}" ]]   && mkdir -p "$local_sandbox_dir/plugins/system/languagecode/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/templates/beez3/language/${TARGETLINGO}" ]]               && mkdir -p "$local_sandbox_dir/templates/beez3/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/templates/protostar/language/${TARGETLINGO}" ]]           && mkdir -p "$local_sandbox_dir/templates/protostar/language/${TARGETLINGO}"

# Check if directories are there:
[[ ! -d "$local_sandbox_dir/administrator/language/${TARGETLINGO}" ]]                 && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/language/overrides" ]]                      && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/language/overrides"
[[ ! -d "$local_sandbox_dir/administrator/help/${TARGETLINGO}" ]]                     && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/help/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${TARGETLINGO}" ]] && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_stats_admin/language/${TARGETLINGO}" ]] && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/modules/mod_stats_admin/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_version/language/${TARGETLINGO}" ]] && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/modules/mod_version/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/administrator/templates/hathor/language/${TARGETLINGO}" ]] && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/templates/hathor/language/${TARGETLINGO}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/bluestork/language/${TARGETLINGO}" ]] &&  DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/templates/bluestork/language/${TARGETLINGO}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/isis/language/${TARGETLINGO}" ]]  && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/administrator/templates/isis/language/${TARGETLINGO}" 
[[ ! -d "$local_sandbox_dir/installation/language/${TARGETLINGO}" ]]                  && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/installation/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/installation/installer" ]]                                && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/installation/installer"
[[ ! -d "$local_sandbox_dir/installation/sql/mysql" ]]                                && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/installation/sql/mysql"
[[ ! -d "$local_sandbox_dir/language/${TARGETLINGO}" ]]                               && DIE "Unexpected directory layout - Expected: $local_sandbox_dir/langauge/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/language/overrides" ]]                                    && DIE "Unexpected directory layout - Expected:  $local_sandbox_dir/langauge/overrides"
[[ ! -d "$local_sandbox_dir/libraries/cms/html/language/${TARGETLINGO}" ]]            && DIE "Unexpected subversion directory layout - Expected: $local_sandbox_dir/libraries/cms/html/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/libraries/src/Filesystem/Meta/language/${TARGETLINGO}" ]] && DIE "Unexpected subversion directory layout - Expected: $local_sandbox_dir/libraries/src/Filesystem/Meta/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${TARGETLINGO}" ]] && DIE "Unexpected subversion directory layout - Expected: $local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/plugins/system/languagecode/language/${TARGETLINGO}" ]]   && DIE "Unexpected subversion directory layout - Expected: $local_sandbox_dir/plugins/system/languagecode/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/templates/beez3/language/${TARGETLINGO}" ]]               && DIE "Unexpected subversion directory layout - Expected: $local_sandbox_dir/templates/beez3/language/${TARGETLINGO}"
[[ ! -d "$local_sandbox_dir/templates/protostar/language/${TARGETLINGO}" ]]           && DIE "Unexpected subversion directory layout - Expected: $local_sandbox_dir/templates/protostar/language/${TARGETLINGO}"


# Default parameters
if [[ -n $dictionary ]]; then
  if [[ -z $lexicon ]]; then
    lexicon=${CWD}/${TARGETLINGO}.sed
  fi
  [[ ! -f ${lexicon} ]]  && DIE "[$LINENO] Could not find the dictionary lookup file: ${lexicon}"
fi

JP=${source_package%\.*}
joomla_source_dir=${WORKFOLDER}/${TARGETLINGO}_${JP##*/}
rm -fr $joomla_source_dir 2>/dev/null
mkdir -p ${joomla_source_dir}
if [[ $? -ne 0 ]]; then
  DIE "[$LINENO] Could not create working directory ${joomla_source_dir}"
fi

UnpackSourcePackage

# Creates a report on the file name differences between the Source lingo distribution
# and the Target lingo distribution
function DiffFileReport {
  INFO "[$LINENO] Comparing number of .ini files:"
  find ${local_sandbox_dir} -type f -name "*.ini" | grep ${TARGETLINGO} | sed -e "s|${local_sandbox_dir}||" -e "s|${TARGETLINGO}|LINGO|g" -e 's|^/||' | sort > ${WORKFOLDER}/${TARGETLINGO}_files
  find ${joomla_source_dir} -type f -name "*.ini" | grep ${SOURCELINGO} | sed -e "s|${joomla_source_dir}||" -e "s|${SOURCELINGO}|LINGO|g" -e 's|^/||' | sort > ${WORKFOLDER}/${SOURCELINGO}_files

  SOURCELINGOFILES=`cat ${WORKFOLDER}/${SOURCELINGO}_files | wc -l`
  TARGETLINGOFILES=`cat ${WORKFOLDER}/${TARGETLINGO}_files | wc -l`

  INFO "[$LINENO] - Number of ${SOURCELINGO} files: $SOURCELINGOFILES"
  INFO "[$LINENO] - Number of ${TARGETLINGO} files: $TARGETLINGOFILES"

  INFO "[$LINENO] Files in the ${SOURCELINGO} source translation that don't yet exit in the ${TARGETLINGO} translation:"
  declare -a aSOURCELINGONotInTARGETLINGO
  aSOURCELINGONotInTARGETLINGO=(`diff ${WORKFOLDER}/${SOURCELINGO}_files ${WORKFOLDER}/${TARGETLINGO}_files | grep "^<" | sed -e "s/< //g" -e "s/LINGO/${TARGETLINGO}/g"`) 
  SOURCELINGONOTINTARGETLINGO=${#aSOURCELINGONotInTARGETLINGO[*]}
  [[ ! -z ${aSOURCELINGONotInTARGETLINGO[*]} ]] && printf "%s\n" ${aSOURCELINGONotInTARGETLINGO[*]-"None"}
  INFO "[$LINENO]  - Total $SOURCELINGONOTINTARGETLINGO file(s)"

  INFO "[$LINENO] Files in the ${TARGETLINGO} target translation that don't exit in the ${SOURCELINGO} translation any more:"
  declare -a aTARGETLINGONotInSOURCELINGO
  aTARGETLINGONotInSOURCELINGO=(`diff ${WORKFOLDER}/${SOURCELINGO}_files ${WORKFOLDER}/${TARGETLINGO}_files | grep "^>" | sed -e "s/> //g" -e "s/LINGO/${TARGETLINGO}/g"`)
  TARGETLINGONOTINSOURCELINGO=${#aTARGETLINGONotInSOURCELINGO[*]}
  [[ ! -z ${aTARGETLINGONotInSOURCELINGO[*]} ]] && printf "%s\n" ${aTARGETLINGONotInSOURCELINGO[*]-"None"}
  INFO "[$LINENO]  - Total $TARGETLINGONOTINSOURCELINGO file(s)"

  if [[ $SOURCELINGONOTINTARGETLINGO != "0" ]] || [[  $TARGETLINGONOTINSOURCELINGO != "0" ]]; then
    # Create work file
    # Set up patchfile script
    PATCHFILE=${WORKFOLDER}/WorkFile_${TARGETLINGO}_files.sh
    rm $PATCHFILE 2>/dev/null

    # Make up a patch script file
    printf "#!/bin/bash
# This script is a summary of the work required to bring the $TARGETLINGO language
# pack up to the latest Joomla patch level. It was created using the
# ${0##*/} utility.
# Run this utility with no command line parameters for further details.
#
# What do I do with this file?
# Step 1: Execute this file:
#         $ ./${PATCHFILE}
#         You should only run this file ONCE. If in doubt, run the 
#         ${0##*/} script again.
# Step 2: Verify that the changes were correcTARGETLINGOy made 
# Step 3: Run the ${0##*/} script again - 
#         If you did everything correcTARGETLINGOy, then further work files will be
#         created similar to this file. 
# 
" > $PATCHFILE
    printf "# Files in the ${SOURCELINGO} source translation that don't yet exit in the ${TARGETLINGO} translation:\n" >> $PATCHFILE
    [[ ${SOURCELINGONOTINTARGETLINGO} -eq 0 ]] && printf "# None\n" >> $PATCHFILE
    for f in "${aSOURCELINGONotInTARGETLINGO[@]}"; do
      printf "[[ ! -d %s ]] && \\ \n  mkdir -p %s\n"  >> $PATCHFILE $(dirname  ${local_sandbox_dir}/$f) $(dirname  ${local_sandbox_dir}/$f)
      printf "printf \"; $TARGETLINGO Language Translation for Joomla!
; Joomla! Project
; Copyright (C) 2005 - $YEAR Open Source Matters. All rights reserved.
; License http://www.gnu.org/licenses/gpl-2.0.html GNU/GPL, see LICENSE.php
; Note : All ini files need to be saved as UTF-8

\" > ${local_sandbox_dir}/$f\n" >> $PATCHFILE
      
      printf "cd ${local_sandbox_dir}\n" >> $PATCHFILE      
      printf "git add ${local_sandbox_dir}/$f\n" >> $PATCHFILE      
      printf "cd -\n\n" >> $PATCHFILE
    done

    printf "\n# Files in the ${TARGETLINGO} target translation that don't exit in the ${SOURCELINGO} translation any more:\n" >> $PATCHFILE
    for f in "${aTARGETLINGONotInSOURCELINGO[@]}"; do
      #g=$(echo $f | sed -e 's|${SOURCELINGO}|${TARGETLINGO}|g')
      printf "git rm ${local_sandbox_dir}/$f\n" >> $PATCHFILE
    done

    chmod +x $PATCHFILE

    DIE "[$LINENO] Resolve the discrepancy in the number of files first by running 
    ${WORKFOLDER}/$PATCHFILE. 
    Then run this script ${0##*/} again. 
    Once there is a one-to-one correspondence between all files, this utility will 
    check for changes in the contents of language strings in the .ini files"
  fi
} # DiffFileReport

# ============================================================================
# Creates a report on the differences in content between the Source lingo and the Target lingo
function DiffContentReport {
  case $1 in
    'site')
      dir='language'
      ;;
    'admin')
      dir='administrator'
      ;;
    'install')
      dir='installation'
      ;;
    *)
      DIE "[$LINENO] Unexpected directive: [$0]"
      ;;
  esac

  INFO "[$LINENO] Changes in language strings of $1 files:"
  find ${local_sandbox_dir}/$dir -type f -name "*.ini" | grep ${TARGETLINGO} | grep -v "^;" | sort -u > ${WORKFOLDER}/${TARGETLINGO}_files
  find ${joomla_source_dir}/$dir -type f -name "*.ini" | grep ${SOURCELINGO} | grep -v "^;" | sort -u > ${WORKFOLDER}/${SOURCELINGO}_files

  # Arrays of Source Language file names:
  declare -a ASOURCELINGO
  ASOURCELINGO=(`cat ${WORKFOLDER}/${SOURCELINGO}_files`)
  # Arrays of Target Language file names:
  declare -a ATARGETLINGO
  ATARGETLINGO=(`cat ${WORKFOLDER}/${TARGETLINGO}_files`)

  i=0
  TSNOTINSOURCELINGO=0
  SSNOTINTARGETLINGO=0
  FILESTHATDIFFER=0
  while : ; do
    DEBUG "Checking strings ${ASOURCELINGO[$i]}"
    cut -f1 -d= -s ${ASOURCELINGO[$i]} | grep -v "^#" | grep -v "^$" | grep -v "^;" | sort -u > ${WORKFOLDER}/SOURCELINGOTemp
    cut -f1 -d= -s ${ATARGETLINGO[$i]} | grep -v "^#" | grep -v "^$" | grep -v "^;" | sort -u > ${WORKFOLDER}/TARGETLINGOTemp
    TSNOTINSOURCELINGO=$(($TSNOTINSOURCELINGO+$(diff ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | grep "<" | wc -l)))
    SSNOTINTARGETLINGO=$(($SSNOTINTARGETLINGO+$(diff ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | grep ">" | wc -l)))
    FILESTHATDIFFER=$(($FILESTHATDIFFER + $(diff -q ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | wc -l)))
    i=$((i+1))
    [[ $i -ge ${#ASOURCELINGO[*]} ]] && break
  done

  INFO "[$LINENO] === Summary of required work for '${1^^}' files: === "
  SUMMARY1="Number of NEW Strings in ${SOURCELINGO} source language not in ${TARGETLINGO} target language: $TSNOTINSOURCELINGO"
  SUMMARY2="Number of OLD Strings in ${TARGETLINGO} target language not in ${SOURCELINGO} source language: $SSNOTINTARGETLINGO"
  SUMMARY3="Total number of ${TARGETLINGO} files that need to be modified: $FILESTHATDIFFER"
  INFO "[$LINENO] $SUMMARY1"
  INFO "[$LINENO] $SUMMARY2"
  INFO "[$LINENO] $SUMMARY3"

  # Set up patchfile script
  PATCHFILE=${WORKFOLDER}/WorkFile_${TARGETLINGO}_${1}.sh
  rm $PATCHFILE 2>/dev/null

  if [[ $FILESTHATDIFFER -eq 0 ]]; then
    INFO "[$LINENO] No changes required for $1 installation"    
    echo "# No changes required for $1 installation" > $PATCHFILE
    return 0
  fi


  # Make up a patch script file
  printf "#!/bin/bash
# This script is a summary of the work required to bring the $TARGETLINGO language
# pack up to the latest Joomla patch level. It was created using the 
# ${0##*/} utility 
# https://github.com/gerritonagoodday/af-ZA_joomla_lang/tree/master/utilities
# This utility works for all languages, as long as the directory structure is in the
# prescribed Joomla structure and you have a very recent update of your translation 
# project on hand - presumably from a Subversion repository. 
# More details are shown when the ${0##*/} 
# utility is executed with the '-h' command line parameter.
#
# What do I do with this file?
# Step 1: Translate ALL the identified strings (see Note 1) below in this file,
#         e.g. where you see text like this:
#         echo \"ADD CUSTOM BUTTON(S)=Add custom button(s)\" >> [some-file-path]
#          - translate this bit:     ~~~~~~~~~~~~~~~~~~~~
#         Where possible, suggestions are given if specified with the  -s 
#         command line parameter.
# Step 2: Execute this file:
#         $ ./$PATCHFILE
#         You can only run this file ONCE, so make sure all your
#         translations are complete.
# Step 3: Verify the changes in the identified files
# Step 4: Check the changed files back in again
#
# Note 1: You *can* do a partial translation on this file but you have to remove
#         the lines that you did not translate before you execute this file.
# Note 2: Make sure you save the file again as a UTF-8 file and that it has no BOM!
#         (Byte Order Marker), because BOMs are a pain in the arse.
# Note 3: If in doubt, re-run ${0##*/} to create 
#         a new version of this, make your edits and execute it ONCE only.
# 
" > $PATCHFILE
  echo "# Summary of required work"  >> $PATCHFILE
  echo $SUMMARY1 | sed -e 's/^/# /g' >> $PATCHFILE
  echo $SUMMARY2 | sed -e 's/^/# /g' >> $PATCHFILE
  echo $SUMMARY3 | sed -e 's/^/# /g' >> $PATCHFILE
  chmod +x $PATCHFILE

  i=0
  jobcount=1
  while : ; do
    DEBUG "[$LINENO] Checking strings %s\n" ${ASOURCELINGO[$i]}
    cut -f1 -d= -s ${ASOURCELINGO[$i]} | grep -v "^#" | grep -v "^$" | sort -u > ${WORKFOLDER}/SOURCELINGOTemp
    cut -f1 -d= -s ${ATARGETLINGO[$i]} | grep -v "^#" | grep -v "^$" | sort -u > ${WORKFOLDER}/TARGETLINGOTemp

    diff ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | grep "^<" > /dev/null
    if [[ $? -eq 0 ]]; then
      MSG1="Job $jobcount: Add the following translated string(s) to the file:"
      MSG2="${ATARGETLINGO[$i]}"
      [[ $VERBOSE -eq 1 ]] && INFO "[$LINENO] $MSG1\n$MSG2"
      printf "\n# $MSG1\n# $MSG2\n" >> $PATCHFILE
      #printf "  Source file:      %s\n" ${ASOURCELINGO[$i]}
      diff ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | grep "^<" | sed -e "s/^< //g" > ${WORKFOLDER}/AddTemp
      #printf "  Summary:\n"
      #cat ${WORKFOLDER}/AddTemp | sed -e 's/^/  + /g'
      #printf "  The source string(s) to be added and translated:\n"
      while read LINE; do
        # Look up source String To Be Translated in Source Language file & Doulbe-Escape quotation marks while we are at it...
        # Does not work for strings, e.g. containing embedded HTML: <strong class="...
        # TODO
        # EMbedded ! need to be escaped
        # Split admin, main and install
        # Identify most important bits
        # Reduce number of goole api calls

        # STBT contains: XXXXXX="Source Language String"
        STBT=`grep -e "^${LINE}=" ${ASOURCELINGO[$i]} | head -1 | sed -e 's|\s*$||' -e 's|=\s*"|=\\\\"|' -e 's|"\s*$|\\\\"|' 2>/dev/null`
        # Use echo since there may be embedded %s in the strings
        [[ $VERBOSE -eq 1 ]] && echo "$STBT"
        #echo "echo \"${STBT}\" >> ${ATARGETLINGO[$i]}" >> $PATCHFILE
        echo "echo \"${STBT}\"\\" >> $PATCHFILE
        echo "     >> ${ATARGETLINGO[$i]}" >> $PATCHFILE

        # SOURCESTRING contains "Source Language String"
        SOURCESTRING=$(echo $STBT | sed -e "s|^$LINE.*=||")
        # GOOGLE TRANSOURCELINGOATION
        if [[ -n $GOOGLELOOKUP ]]; then
          if [[ -z $GOOGLE_IS_ON_STRIKE ]]; then
            # Look up using google translator for suggestions:
            # Get Text Only String
            SUGGESTION=$(translate "$SOURCESTRING" $SOURCELINGO1 $TARGETLINGO1)
            SUGGESTION=$(echo $SUGGESTION | sed -e 's|\\u0026quot;||g')

            if [[ $SUGGESTION =~ "\"responseStatus\": 403" ]]; then
              # If Google thinks it is being abused, then it stops serving translations
              printf "# Google will not do any more translations - try again later.\n" >> $PATCHFILE
              INFO "Google will not do any more translations - try again later"
              GOOGLE_IS_ON_STRIKE="very unhappy"
            else
              if [[ $SUGGESTION =~ "\"responseStatus\": 400" ]]; then
                printf "# GOOGLE LOOKUP FAILED: Could not find a Google translation.\n" >> $PATCHFILE
              else
                printf "# GOOGLE LOOKUP: $SUGGESTION\n" >> $PATCHFILE
                # Give Google time to recover
                sleep 1
              fi
            fi
          fi
        fi


        if [[ -n $lexicon ]]; then
          # lexicon LOOKUPSTBTARGETLINGOex=
          # Strip preamble
          STBTs=$(echo $STBT | sed -e 's/^.*=\\*"*//' -e 's/\\*\"*\s*>>.*//' -e 's/\\*\"$//')
          # De-HTML-ify
          STBTs=$(echo $STBTs | sed -e 's/<[^>]*>//g')
          # Lookup words in lexicon
          STBTARGETLINGOex=$(echo $STBTs | sed -f $lexicon)
          # Use echo!
          echo "# lexicon: $STBTARGETLINGOex" >> $PATCHFILE
        fi

        if [[ -n $SUGGESTIONS ]]; then
          # Exact Match
          # Use previous efforts so far for suggestions and look up 100% previous translations for this string ID
          STBTid=$(echo $STBT | sed -e 's/=.*//')
          grep -hi "${STBTid}=" ${local_sandbox_dir}/administrator/language/${TARGETLINGO}/*.ini 2>/dev/null  > ${WORKFOLDER}/Look1
          grep -hi "${STBTid}=" ${local_sandbox_dir}/language/${TARGETLINGO}/*.ini 2>/dev/null               >> ${WORKFOLDER}/Look1
          grep -hi "${STBTid}=" ${local_sandbox_dir}/installation/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look1
          grep -hi "${STBTid}=" ${local_sandbox_dir}/plugins/system/languagecode/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look1
          grep -hi "${STBTid}=" ${local_sandbox_dir}/templates/*/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look1
          num_previous_matches=$(cat ${WORKFOLDER}/Look1 | wc -l)
          # Check if we have at least 1 match from already-existing translated strings
          if [[ $num_previous_matches -gt 0 ]]; then
            # strip preamble & clean up a litTARGETLINGOe
            cat ${WORKFOLDER}/Look1 | sort -u > ${WORKFOLDER}/Look2
            sed -e 's/^.*="*//' -e 's/\"$//' -i ${WORKFOLDER}/Look2
            sed -e 's/:|-/ /' -e 's/%\w*//g' -e 's/  / /' -e 's/  / /' -i ${WORKFOLDER}/Look2
            # Get longest line as it is likely to give the best translated context
            SUGGESTION=$(cat ${WORKFOLDER}/Look2 | awk '{ print length(), $0 | "sort -nr" }'| sed -e 's/^[0-9]*\s*//' | head -1)
            echo "# EXACTMATCH: $SUGGESTION" >> $PATCHFILE
          fi

          # Look for same English content that may been translated under a different Id somewhere else
          # Strip preamble - but don't clean up
          STBTs=$(echo $STBT | sed -e 's/^.*=\\*"*//' -e 's/\\*\"*\s*>>.*//' -e 's/\\*\"$//' -e 's/[\.\s]*$//')
          DEBUG "Looking for the string \"$STBTs\" in\n\t${joomla_source_dir}/administrator/language/${SOURCELINGO}\n\t${joomla_source_dir}/language/${SOURCELINGO}\n\t${joomla_source_dir}/installation/language/${SOURCELINGO}\n\t${joomla_source_dir}/plugins/system/languagecode/language/${SOURCELINGO}\n\t${joomla_source_dir}/templates/\*/language/${SOURCELINGO}"
          grep -hi "${STBTs}" ${joomla_source_dir}/administrator/language/${SOURCELINGO}/*.ini 2>/dev/null >  ${WORKFOLDER}/Look6
          grep -hi "${STBTs}" ${joomla_source_dir}/language/${SOURCELINGO}/*.ini 2>/dev/null               >> ${WORKFOLDER}/Look6
          grep -hi "${STBTs}" ${joomla_source_dir}/installation/language/${SOURCELINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look6
          grep -hi "${STBTs}" ${joomla_source_dir}/plugins/system/languagecode/language/${SOURCELINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look6
          grep -hi "${STBTs}" ${joomla_source_dir}/templates/*/language/${SOURCELINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look6
          # Remove the string with this Id
          grep -v "^${STBTid}=" ${WORKFOLDER}/Look6 | sort -u > ${WORKFOLDER}/Look7
          if [[ $(cat ${WORKFOLDER}/Look7 | wc -l) -gt 0 ]]; then
            while read LINE; do 
              # Get Id
              STBTid=$(echo $STBT | sed -e 's/=.*//')
              DEBUG "FOUND. Check if the string Id \"$STBTid\" has already been translated in\n\t${local_sandbox_dir}/administrator/language/${TARGETLINGO}\n \t${local_sandbox_dir}/language/${TARGETLINGO}\n\t${local_sandbox_dir}/installation/language/${TARGETLINGO}\n\t${local_sandbox_dir}/plugins/system/languagecode/language/${TARGETLINGO}\n\t${local_sandbox_dir}/templates/\*/language/${TARGETLINGO}"
              # Now search through text of already-translated strings
              grep -hi ${STBTid} ${local_sandbox_dir}/administrator/language/${TARGETLINGO}/*.ini 2>/dev/null  > ${WORKFOLDER}/Look8
              grep -hi ${STBTid} ${local_sandbox_dir}/language/${TARGETLINGO}/*.ini 2>/dev/null               >> ${WORKFOLDER}/Look8
              grep -hi ${STBTid} ${local_sandbox_dir}/installation/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look8
              grep -hi ${STBTid} ${local_sandbox_dir}/plugins/system/languagecode/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look8
              grep -hi ${STBTid} ${local_sandbox_dir}/templates/*/language/${TARGETLINGO}/*.ini 2>/dev/null   >> ${WORKFOLDER}/Look8
            done < ${WORKFOLDER}/Look7
            if [[ $(cat ${WORKFOLDER}/Look8 | wc -l) -gt 0 ]]; then
              DEBUG "String Id \"${STBTid}\" has already been translated."
              printf "# PREVIOUS TRANSOURCELINGOATIONS: \n" >> $PATCHFILE
              # Strip preambles
              sed -e 's/^.*=\\*"*//' -e 's/\\*\"*\s*>>.*//' -e 's/\\*\"$//' -i  ${WORKFOLDER}/Look8
              # Select longest translated string
              cat ${WORKFOLDER}/Look8 | sort -u | awk '{ print length(), $0 | "sort -nr" }'| sed -e 's/^[0-9]*\s*//' | head -10 > ${WORKFOLDER}/Look9              
              while read LINE; do
                echo "# $LINE" >> $PATCHFILE
              done < ${WORKFOLDER}/Look9
            fi
          else
            DEBUG "The string \"${STBTs}\" has not previously been transalated"
          fi

          # Look up longest word from lexiconned string in already-existing translated strings
          if [[ -n $lexicon ]]; then
            source_packageACED_LINE=$(echo $STBTARGETLINGOex | sed -e 's/_/ /g')
            # Look for longest word but ignore module names
            for l in $source_packageACED_LINE; do [[ ${#l} -gt $len ]] && [[ ${l} =~ [^_] ]] && WORD=$l; len=${#l}; done
            WORD=$(echo $WORD | sed -e 's/.*=//' -e 's/\"//g' -e 's/\.$//')
            if [[ ${#WORD} -ge 4 ]]; then
              grep -hi ${WORD} ${local_sandbox_dir}/administrator/language/${TARGETLINGO}/*.ini 2>/dev/null >  ${WORKFOLDER}/Look3
              grep -hi ${WORD} ${local_sandbox_dir}/language/${TARGETLINGO}/*.ini 2>/dev/null               >> ${WORKFOLDER}/Look3
              grep -hi ${WORD} ${local_sandbox_dir}/installation/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look3
              grep -hi ${WORD} ${local_sandbox_dir}/plugins/system/languagecode/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look3
              grep -hi ${WORD} ${local_sandbox_dir}/templates/*/language/${TARGETLINGO}/*.ini 2>/dev/null    >> ${WORKFOLDER}/Look3
            fi
            if [[ $(wc -l ${WORKFOLDER}/Look3 | cut -f1 -d" ") -lt 2 ]]; then
              # Look for second-longest word but ignore module names
              for l in $source_packageACED_LINE; do [[ ${#l} -gt $len && ${#l} -lt ${#WORD} ]] && [[ ${l} =~ [^_] ]] && WORD2=$l; len=${#l}; done
              WORD2=$(echo $WORD2 | sed -e 's/.*=//' -e 's/\"//g' -e 's/\.$//')
              if [[ ${#WORD2} -ge 4 ]]; then
                grep -hi ${WORD2} ${local_sandbox_dir}/administrator/language/${TARGETLINGO}/*.ini 2>/dev/null >  ${WORKFOLDER}/Look3
                grep -hi ${WORD2} ${local_sandbox_dir}/language/${TARGETLINGO}/*.ini 2>/dev/null               >> ${WORKFOLDER}/Look3
                grep -hi ${WORD2} ${local_sandbox_dir}/installation/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look3
                grep -hi ${WORD2} ${local_sandbox_dir}/plugins/system/languagecode/language/${TARGETLINGO}/*.ini 2>/dev/null  >> ${WORKFOLDER}/Look3
                grep -hi ${WORD2} ${local_sandbox_dir}/templates/*/language/${TARGETLINGO}/*.ini 2>/dev/null   >> ${WORKFOLDER}/Look3
              fi
            fi

            # strip preamble & clean up a litTARGETLINGOe
            sed -e 's/^.*="*//' -e 's/\"$//' -i ${WORKFOLDER}/Look3
            sed -e 's/:|-/ /' -e 's/%\w*//g' -e 's/  / /' -e 's/  / /' -i ${WORKFOLDER}/Look3

            # dedupe & order & # remove Help-links
            sort -u -f ${WORKFOLDER}/Look3 | grep -v "_" > ${WORKFOLDER}/Look4

            # Only keep candidate strings that have about a many words as the source string has
            # Word count in string, rounding down:
            numWords=$(echo $source_packageACED_LINE | wc -w)
            maxWords=$(echo $numWords | awk '{print $0 * 1.5}' | sed -e 's/\..*//')
            minWords=$(echo $numWords | awk '{print $0 * 0.5}' | sed -e 's/\..*//')
            # Pick candidate strings that have word counts in this range
            cat ${WORKFOLDER}/Look4 | awk '{if (lenth < "'"$minWords"'" && length > "'"$maxWords"'") print ""; else print $0 }' | sort -u > ${WORKFOLDER}/Look5
            if [[ $(wc -l ${WORKFOLDER}/Look5 | cut -f1 -d" ") -gt 0 ]]; then
              cat ${WORKFOLDER}/Look5 | awk '{ print length(), $0 | "sort -nr" }'| sed -e 's/^[0-9]*\s*//' | head -10 > ${WORKFOLDER}/Look6
              printf "# SUGGESTIONS:\n" >> $PATCHFILE
              while read SUGGESTION; do
                [[ -z $SUGGESTION ]] && continue
                echo "# $SUGGESTION" >> $PATCHFILE
              done < ${WORKFOLDER}/Look6
            fi
          fi
        fi
      done < ${WORKFOLDER}/AddTemp
      jobcount=$((jobcount+1))
    fi

    diff ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | grep "^>" > /dev/null
    if [[ $? -eq 0 ]]; then
      MSG1="Job $jobcount: Remove the following string(s) from the file:"
      MSG2="${ATARGETLINGO[$i]}"
      [[ $VERBOSE -eq 1 ]] && INFO "$MSG1\n$MSG2"
      printf "\n# $MSG1\n# $MSG2\n" >> $PATCHFILE
      diff ${WORKFOLDER}/SOURCELINGOTemp ${WORKFOLDER}/TARGETLINGOTemp | grep "^>" | sed -e "s/^> //g" | sort > ${WORKFOLDER}/DelTemp
      while read LINE; do
        # String To Be Removed
        [[ $VERBOSE -eq 1 ]] && printf "$LINE\n"
        printf "# $LINE:\n" >> $PATCHFILE
        ESC_LINE=$(echo $LINE | sed -e 's|\/|\\\/|g'  -e 's|\!|\\\!|g' -e 's|\*|\\\*|g' -e 's|`|\\`|g')
        printf "sed -e \"/${ESC_LINE}\s*=/d\" -i ${ATARGETLINGO[$i]}\n" >> $PATCHFILE;
      done < ${WORKFOLDER}/DelTemp
      jobcount=$((jobcount+1))
    fi

    i=$((i+1))
    [[ $i -ge ${#ASOURCELINGO[*]} ]] && break
  done  # while :
}  # DiffContentReport

DiffFileReport
DiffContentReport "site"
DiffContentReport "admin"
DiffContentReport "install"

INFO "[$LINENO] ============= Next step: ====================================="
INFO "[$LINENO]

You can either manually apply the changes recommended above and re-run 
this utility until no further changes are required. 

Or, you can do all the translations by editing the patch file 
$PATCHFILE in $WORKFOLDER and then executing it:

  $ cd $WORKFOLDER
  $ nano $PATCHFILE
  $ ./$PATCHFILE 

Do the same for the ..._site and the ..._admin files.
If you are happy with the changes, you should check the
changes back in to subversion with the commands:

  $ cd $local_sandbox_dir
  $ svn ci -m \"Patched to next Joomla release\"

"

EXITCODE=1
exit $EXITCODE
