#!/bin/bash

# What this script does:
# ~~~~~~~~~~~~~~~~~~~~~
# This script compares your language .ini files with those from a chosen
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
#
# TODO:
# ----
# Complete linting of this script by running this:
#   shellcheck -e SC2086,SC2016,SC2059,SC2153,SC2001 Chk4NewJoomlaLanguageFiles.sh 


# Set your local working folder (no trailing slashes)
workfolder="${PWD}/../.build"
if [ ! -d "$workfolder" ]; then
  printf "[$LINENO] Making $workfolder...\n"
  mkdir -p $workfolder
fi
if [ ! -d "$workfolder" ]; then
  printf "[$LINENO] Working folder $workfolder does not exist."
  exit 1
fi
if [ ! -w $workfolder ]; then
  printf "[$LINENO] Working folder $workfolder is not writable."
  exit 1
fi

tmpfile1=$(mktemp /tmp/joomla.1.XXXX)
tmpfile2=$(mktemp /tmp/joomla.2.XXXX)
tmpfile3=$(mktemp /tmp/joomla.3.XXXX)
tmpfile4=$(mktemp /tmp/joomla.4.XXXX)
tmpfile5=$(mktemp /tmp/joomla.5.XXXX)
tmpfile6=$(mktemp /tmp/joomla.6.XXXX)
tmpfile7=$(mktemp /tmp/joomla.7.XXXX)
tmpfile8=$(mktemp /tmp/joomla.8.XXXX)
tmpfile9=$(mktemp /tmp/joomla.9.XXXX)
tmpfile10=$(mktemp /tmp/joomla.10.XXXX)
tmpfile11=$(mktemp /tmp/joomla.11.XXXX)
tmpfile12=$(mktemp /tmp/joomla.12.XXXX)
tmpfile13=$(mktemp /tmp/joomla.13.XXXX)
tmpfile14=$(mktemp /tmp/joomla.14.XXXX)
tmpfile15=$(mktemp /tmp/joomla.15.XXXX)
tmpfile16=$(mktemp /tmp/joomla.16.XXXX)

YEAR=$(date +"%Y")
CWD=$PWD

# Set up logging - this is important if we run this as a cron job
progname=${0##*/}
[ ! -d $workfolder ] &&  mkdir -p $workfolder
logfile="${workfolder}/${progname%\.*}.log"
touch $logfile 2>/dev/null
if [[ $? -ne 0 ]]; then
  logfile="${HOME}/${progname%\.*}.log"
  touch "$logfile" 2>/dev/null
  if [[ $? -ne 0 ]]; then
    logfile="${progname%\.*}.log"
    touch "$logfile" 2>/dev/null
    if [[ $? -ne 0 ]]; then
      printf "Could not write to $logfile. Exiting...\n"    
      exit 1
    fi
  fi
fi

#============================================================================#
# Diagnostics
#============================================================================#
function DEBUG {
  [[ -z $option_debug ]] && return
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "[$TS][$target_lingo][DEBUG]" >> $logfile
  while [[ -n $1 ]] ; do
    printf "%s " $1 >>  $logfile
    shift
  done
  printf "\n" >> $logfile
}

function INFO {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  echo "[$TS][$target_lingo][INFO ]$@" | tee -a $logfile
}

function WARN {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  echo "[$TS][$target_lingo][WARN ]$@" | tee -a $logfile
}

# Death to the evil function for it must surely die!
# Parameters:  optional error message
# Exit Code:   1
function DIE {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  echo "[$TS][$target_lingo][FATAL]$@" | tee -a $logfile
  exit 1
}

#============================================================================#
# TRAPS
#============================================================================#
function cleanup {
  INFO "[$LINENO] === END [PID $$] on signal $1. Cleaning up ==="
  rm "$tmpfile1" 2>/dev/null
  rm "$tmpfile2" 2>/dev/null
  rm "$tmpfile3" 2>/dev/null
  rm "$tmpfile4" 2>/dev/null
  rm "$tmpfile5" 2>/dev/null
  rm "$tmpfile6" 2>/dev/null
  rm "$tmpfile7" 2>/dev/null
  rm "$tmpfile8" 2>/dev/null
  rm "$tmpfile9" 2>/dev/null
  rm "$tmpfile10" 2>/dev/null
  rm "$tmpfile11" 2>/dev/null
  rm "$tmpfile12" 2>/dev/null
  rm "$tmpfile13" 2>/dev/null
  rm "$tmpfile14" 2>/dev/null
  rm "$tmpfile15" 2>/dev/null
  rm "$tmpfile16" 2>/dev/null
  exit
}
for sig in KILL TERM INT EXIT; do trap 'cleanup $sig' "$sig" ; done

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
  rm -fr $workfolder/admin 2>/dev/null
  mkdir -p $workfolder/admin
  rm -fr $workfolder/site 2>/dev/null
  mkdir -p $workfolder/site
}

function usage {
  printf "
Compares your language .ini files with those from a chosen Joomla Release and
generates a report and work package of work that needs to be done to bring your
current translation package in line with the latest package.

Run this from the utilities directory.

Usage: %s -p|--package_source=[Joomla_x.x.x-Full_Package.zip|JoomlaSourceCodeDirectory] [-l|--lexicon[=Dictionary File]] 
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
          %s
  -d, --debug
          Output debug messages to screen and 
          %s
  -h, --help
          Displays this text

Examples:
   ./%s -p=~/Downloads/Joomla_x.y.z-Stable-Full_Package.zip
   or
   ./%s -p=~/git/joomla-cms

Note:
  This utility does not push any changes to the remote Git repository.
  Remember to update your project from Git first before running this script:
  $ cd ~/git/af-ZA_joomla_lang
  $ git pull

" ${0##*/} ${logfile} ${logfile} ${0##*/} ${0##*/}
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
      cd ${joomla_source_dir} || LOGDIE "[$LINENO] Could not change directory to ${joomla_source_dir}"
      RETCODE=$(tar -xjf $source_package)
      cd - || LOGDIE "[$LINENO] Could not change directory back"
      if [[ $RETCODE -ne 0 ]]; then
	      DIE "[$LINENO] There was a problem unpacking the Joomla TAR.BZ2 source package $source_package into ${joomla_source_dir}"
      fi
      ;;
    gz)
      cd ${joomla_source_dir} || LOGDIE "[$LINENO] Could not change directory to ${joomla_source_dir}"
      RETCODE=$(tar -xzf $source_package)
      cd - || LOGDIE "[$LINENO] Could not change directory back"
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

INFO "[$LINENO] === BEGIN [PID $$] $progname ==="

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
        source_package=$VAL; [[ $VAL = "$ARG" ]] && shift && source_package=$1
        source_package=$(echo ${source_package} | sed -e "s|~|${HOME}|g")        
      fi
      ;;
    "--lexicon" | "-l")
      dictionary="use"
      lexicon=$VAL; [[ $VAL = "$ARG" ]] && shift && lexicon=$1
      lexicon=$(echo $lexicon | sed -e "s|~|${HOME}|g") 
      ;;
    "--google" | "-g")
      option_googletranslate="use"
      ;;
    "--suggestions" | "-s")
      option_suggestions="use"
      ;;
    "--help" | "-h" )
      usage
      ;;
    "--verbose" | "-v" )
      option_verbose=1
      ;;
    "--debug" | "-d" )
      option_debug=1
      option_verbose=1
      ;;
    *)
      print "Invalid option: $1"
      exit 1
      ;;
  esac
  shift
done

# Check input parameters from config file
target_lingo=$TARGETLINGO
source_lingo=$SOURCELINGO
if [[ -z $target_lingo ]]; then
  DIE "[$LINENO] Target language not specified"
fi
# Check input parameters from command line
[ -z "$source_package" ] && DIE "[$LINENO] Joomla installation package not specified" 
[ ! -e "$source_package" ] && DIE "[$LINENO] Joomla source package or source repository $source_package could not be found."
[ -n "$dictionary" ] && [ ! -f "$lexicon" ] && DIE "[$LINENO] Lexicon file $lexicon could not be found. Specify full path."

# Default parameters
[ -n "$option_googletranslate" ] && unset $option_suggestions

# Make ISO-639-1 language code from ISO-639-0 codes: (e.g. en-GB => en)
source_lingo_1=${source_lingo/-[A-Z]*/}
target_lingo_1=${target_lingo/-[A-Z]*/}


INFO "[$LINENO] Checking / fixing target subversion directory layout"

# These are the current directories that contain language files,
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
[[ ! -d "$local_sandbox_dir/administrator/language/${target_lingo}" ]]                 && mkdir -p "$local_sandbox_dir/administrator/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/language/overrides" ]]                      && mkdir -p "$local_sandbox_dir/administrator/language/overrides"
[[ ! -d "$local_sandbox_dir/administrator/help/${target_lingo}" ]]                     && mkdir -p "$local_sandbox_dir/administrator/help/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_stats_admin/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/administrator/modules/mod_stats_admin/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_version/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/administrator/modules/mod_version/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/templates/hathor/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/administrator/templates/hathor/language/${target_lingo}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/bluestork/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/administrator/templates/bluestork/language/${target_lingo}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/isis/language/${target_lingo}" ]]  && mkdir -p "$local_sandbox_dir/administrator/templates/isis/language/${target_lingo}" 
[[ ! -d "$local_sandbox_dir/installation/language/${target_lingo}" ]]                  && mkdir -p "$local_sandbox_dir/installation/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/installation/installer" ]]                                && mkdir -p "$local_sandbox_dir/installation/installer"
[[ ! -d "$local_sandbox_dir/installation/sql/mysql" ]]                                && mkdir -p "$local_sandbox_dir/installation/sql/mysql"
[[ ! -d "$local_sandbox_dir/language/${target_lingo}" ]]                               && mkdir -p "$local_sandbox_dir/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/language/overrides" ]]                                    && mkdir -p "$local_sandbox_dir/language/overrides"
[[ ! -d "$local_sandbox_dir/libraries/cms/html/language/${target_lingo}" ]]            && mkdir -p "$local_sandbox_dir/libraries/cms/html/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/libraries/src/Filesystem/Meta/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/libraries/src/Filesystem/Meta/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${target_lingo}" ]] && mkdir -p "$local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/plugins/system/languagecode/language/${target_lingo}" ]]   && mkdir -p "$local_sandbox_dir/plugins/system/languagecode/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/templates/beez3/language/${target_lingo}" ]]               && mkdir -p "$local_sandbox_dir/templates/beez3/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/templates/protostar/language/${target_lingo}" ]]           && mkdir -p "$local_sandbox_dir/templates/protostar/language/${target_lingo}"

# Check if directories are there:
[[ ! -d "$local_sandbox_dir/administrator/language/${target_lingo}" ]]                 && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/language/overrides" ]]                      && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/language/overrides"
[[ ! -d "$local_sandbox_dir/administrator/help/${target_lingo}" ]]                     && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/help/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${target_lingo}" ]] && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/modules/mod_multilangstatus/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_stats_admin/language/${target_lingo}" ]] && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/modules/mod_stats_admin/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/modules/mod_version/language/${target_lingo}" ]] && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/modules/mod_version/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/administrator/templates/hathor/language/${target_lingo}" ]] && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/templates/hathor/language/${target_lingo}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/bluestork/language/${target_lingo}" ]] &&  DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/templates/bluestork/language/${target_lingo}" 
[[ ! -d "$local_sandbox_dir/administrator/templates/isis/language/${target_lingo}" ]]  && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/administrator/templates/isis/language/${target_lingo}" 
[[ ! -d "$local_sandbox_dir/installation/language/${target_lingo}" ]]                  && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/installation/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/installation/installer" ]]                                && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/installation/installer"
[[ ! -d "$local_sandbox_dir/installation/sql/mysql" ]]                                && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/installation/sql/mysql"
[[ ! -d "$local_sandbox_dir/language/${target_lingo}" ]]                               && DIE "[$LINENO] Unexpected directory layout - Expected: $local_sandbox_dir/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/language/overrides" ]]                                    && DIE "[$LINENO] Unexpected directory layout - Expected:  $local_sandbox_dir/language/overrides"
[[ ! -d "$local_sandbox_dir/libraries/cms/html/language/${target_lingo}" ]]            && DIE "[$LINENO] Unexpected subversion directory layout - Expected: $local_sandbox_dir/libraries/cms/html/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/libraries/src/Filesystem/Meta/language/${target_lingo}" ]] && DIE "[$LINENO] Unexpected subversion directory layout - Expected: $local_sandbox_dir/libraries/src/Filesystem/Meta/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${target_lingo}" ]] && DIE "[$LINENO] Unexpected subversion directory layout - Expected: $local_sandbox_dir/libraries/vendor/joomla/filesystem/meta/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/plugins/system/languagecode/language/${target_lingo}" ]]   && DIE "[$LINENO] Unexpected subversion directory layout - Expected: $local_sandbox_dir/plugins/system/languagecode/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/templates/beez3/language/${target_lingo}" ]]               && DIE "[$LINENO] Unexpected subversion directory layout - Expected: $local_sandbox_dir/templates/beez3/language/${target_lingo}"
[[ ! -d "$local_sandbox_dir/templates/protostar/language/${target_lingo}" ]]           && DIE "[$LINENO] Unexpected subversion directory layout - Expected: $local_sandbox_dir/templates/protostar/language/${target_lingo}"


# Default parameters
if [[ -n $dictionary ]]; then
  if [[ -z $lexicon ]]; then
    lexicon=${CWD}/${target_lingo}.sed
  fi
  [[ ! -f ${lexicon} ]]  && DIE "[$LINENO] Could not find the dictionary lookup file: ${lexicon}"
fi

JP=${source_package%\.*}
joomla_source_dir=${workfolder}/${target_lingo}_${JP##*/}
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
  find ${local_sandbox_dir}/{administrator,installation,language,libraries,plugins,templates} -type f -name "*.ini" | grep ${target_lingo} | sed -e "s|${local_sandbox_dir}||" -e "s|${target_lingo}|LINGO|g" -e 's|^/||' | sort > "$tmpfile15"
  find ${joomla_source_dir}/{administrator,installation,language,libraries,plugins,templates} -type f -name "*.ini" | grep ${source_lingo} | sed -e "s|${joomla_source_dir}||" -e "s|${source_lingo}|LINGO|g" -e 's|^/||' | sort > "$tmpfile16"

  SOURCELINGOFILES=`cat "$tmpfile16" | wc -l`
  TARGETLINGOFILES=`cat "$tmpfile15" | wc -l`

  INFO "[$LINENO] - Number of ${source_lingo} files: $SOURCELINGOFILES"
  INFO "[$LINENO] - Number of ${target_lingo} files: $TARGETLINGOFILES"

  INFO "[$LINENO] Files in the ${source_lingo} source translation that don't yet exit in the ${target_lingo} translation:"
  declare -a a_sourcefiles_not_in_target
  a_sourcefiles_not_in_target=(`diff "$tmpfile16" "$tmpfile15" | grep "^<" | sed -e "s/< //g" -e "s/LINGO/${target_lingo}/g"`) 
  num_sourcefiles_not_in_target=${#a_sourcefiles_not_in_target[*]}
  [[ ! -z ${a_sourcefiles_not_in_target[*]} ]] && printf "%s\n" ${a_sourcefiles_not_in_target[*]-"None"}
  INFO "[$LINENO]  - Total $num_sourcefiles_not_in_target file(s)"

  INFO "[$LINENO] Files in the ${target_lingo} target translation that don't exit in the ${source_lingo} translation any more:"
  declare -a a_targetfiles_not_in_source
  a_targetfiles_not_in_source=(`diff "$tmpfile16" "$tmpfile15" | grep "^>" | sed -e "s/> //g" -e "s/LINGO/${target_lingo}/g"`)
  num_targetfiles_not_in_source=${#a_targetfiles_not_in_source[*]}
  [[ ! -z ${a_targetfiles_not_in_source[*]} ]] && printf "%s\n" ${a_targetfiles_not_in_source[*]-"None"}
  INFO "[$LINENO]  - Total $num_targetfiles_not_in_source file(s)"

  if [[ $num_sourcefiles_not_in_target != "0" ]] || [[  $num_targetfiles_not_in_source != "0" ]]; then
    # Create work file
    # Set up patchfile script
    PATCHFILE=${workfolder}/WorkFile_${target_lingo}_files.sh
    rm "$PATCHFILE" 2>/dev/null

    # Make up a patch script file
    printf "#!/bin/bash
# This script is a summary of the work required to bring the $target_lingo language
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
" > "$PATCHFILE"
    printf "# Files in the %s source translation that don't yet exit in the %s translation:\n" >> $PATCHFILE ${source_lingo} ${target_lingo}
    [[ ${num_sourcefiles_not_in_target} -eq 0 ]] && printf "# None\n" >> $PATCHFILE
    for f in "${a_sourcefiles_not_in_target[@]}"; do
      printf "[[ ! -d %s ]] && \\ \n  mkdir -p %s\n"  >> $PATCHFILE "$(dirname  ${local_sandbox_dir}/$f)" "$(dirname  ${local_sandbox_dir}/$f)"
      printf "printf \"; $target_lingo Language Translation for Joomla!
; Joomla! Project
; Copyright (C) 2005 - $YEAR Open Source Matters. All rights reserved.
; License http://www.gnu.org/licenses/gpl-2.0.html GNU/GPL, see LICENSE.php
; Note : All ini files need to be saved as UTF-8

\" > ${local_sandbox_dir}/$f\n" >> $PATCHFILE
      
      printf "cd ${local_sandbox_dir}\n" >> $PATCHFILE      
      printf "git add ${local_sandbox_dir}/$f\n" >> $PATCHFILE      
      printf "cd -\n\n" >> $PATCHFILE
    done

    printf "\n# Files in the ${target_lingo} target translation that don't exit in the ${source_lingo} translation any more:\n" >> $PATCHFILE
    for f in "${a_targetfiles_not_in_source[@]}"; do
      #g=$(echo $f | sed -e 's|${source_lingo}|${target_lingo}|g')
      printf "git rm ${local_sandbox_dir}/$f\n" >> $PATCHFILE
    done

    chmod +x $PATCHFILE

    DIE "[$LINENO] Resolve the discrepancy in the number of files first by running     
    $PATCHFILE. 
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
  find ${local_sandbox_dir}/$dir -type f -name "*.ini" | grep ${target_lingo} | grep -v "^;" | sort -u > "$tmpfile15"
  find ${joomla_source_dir}/$dir -type f -name "*.ini" | grep ${source_lingo} | grep -v "^;" | sort -u > "$tmpfile16"

  # Arrays of Source Language file names:
  declare -a a_source_filenames
  a_source_filenames=(`cat "$tmpfile16"`)
  # Arrays of Target Language file names:
  declare -a a_target_filenames
  a_target_filenames=(`cat "$tmpfile15"`)

  i=0
  num_new_strings=0
  num_old_strings=0
  num_files_different=0
  while : ; do
    DEBUG "[$LINENO] Checking strings ${a_source_filenames[$i]}"
    cut -f1 -d= -s ${a_source_filenames[$i]} | grep -v "^#" | grep -v "^$" | grep -v "^;" | sort -u > "$tmpfile13"
    cut -f1 -d= -s ${a_target_filenames[$i]} | grep -v "^#" | grep -v "^$" | grep -v "^;" | sort -u > "$tmpfile14"
    num_new_strings=$((num_new_strings+$(diff "$tmpfile13" "$tmpfile14" | grep "<" | wc -l)))
    num_old_strings=$((num_old_strings+$(diff "$tmpfile13" "$tmpfile14" | grep ">" | wc -l)))
    num_files_different=$((num_files_different + $(diff -q "$tmpfile13" "$tmpfile14" | wc -l)))
    i=$((i+1))
    [[ $i -ge ${#a_source_filenames[*]} ]] && break
  done

  INFO "[$LINENO] === Summary of required work for '${1^^}' files: === "
  summary_1="Number of NEW Strings in ${source_lingo} source language not in ${target_lingo} target language: $num_new_strings"
  summary_2="Number of OLD Strings in ${target_lingo} target language not in ${source_lingo} source language: $num_old_strings"
  summary_3="Total number of ${target_lingo} files that need to be modified: $num_files_different"
  INFO "[$LINENO] $summary_1"
  INFO "[$LINENO] $summary_2"
  INFO "[$LINENO] $summary_3"

  # Set up patchfile script
  PATCHFILE=${workfolder}/WorkFile_${target_lingo}_${1}.sh
  rm $PATCHFILE 2>/dev/null

  if [[ $num_files_different -eq 0 ]]; then
    INFO "[$LINENO] No changes required for $1 installation"    
    echo "# No changes required for $1 installation" > $PATCHFILE
    return 0
  fi


  # Make up a patch script file
  printf "#!/bin/bash
# This script is a summary of the work required to bring the $target_lingo language
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
" > "$PATCHFILE"
  { echo "# Summary of required work";
    echo $summary_1 | sed -e 's/^/# /g'; 
    echo $summary_2 | sed -e 's/^/# /g'; 
    echo $summary_3 | sed -e 's/^/# /g'; } >> "$PATCHFILE"
  chmod +x "$PATCHFILE"

  i=0
  jobcount=1
  while : ; do
    DEBUG "[$LINENO] Checking strings in file ${a_source_filenames[$i]}"
    cut -f1 -d= -s "${a_source_filenames[$i]}" | grep -v "^#" | grep -v "^$" | sort -u > "$tmpfile13"
    cut -f1 -d= -s "${a_target_filenames[$i]}" | grep -v "^#" | grep -v "^$" | sort -u > "$tmpfile14"

    diff "$tmpfile13" "$tmpfile14" | grep "^<" > /dev/null
    if [[ $? -eq 0 ]]; then
      MSG1="Job $jobcount: Add the following translated string(s) to the file:"
      MSG2="${a_target_filenames[$i]}"
      [[ -n $option_verbose ]] && INFO "[$LINENO] $MSG1 $MSG2"
      printf "\n# $MSG1\n# $MSG2\n" >> $PATCHFILE
      #printf "  Source file:      %s\n" ${a_source_filenames[$i]}
      diff "$tmpfile13" "$tmpfile14" | grep "^<" | sed -e "s/^< //g" > "$tmpfile2"
      #printf "  Summary:\n"
      #cat "$tmpfile2" | sed -e 's/^/  + /g'
      #printf "  The source string(s) to be added and translated:\n"
      while read -r LINE; do
        # Look up source String To Be Translated in Source Language file & Doulbe-Escape quotation marks while we are at it...
        # Does not work for strings, e.g. containing embedded HTML: <strong class="...

        # STBT contains: XXXXXX="Source Language String"
        STBT=`grep -e "^${LINE}=" ${a_source_filenames[$i]} | head -1 | sed -e 's|\s*$||' -e 's|=\s*"|=\\\\"|' -e 's|"\s*$|\\\\"|' 2>/dev/null`
        # Use echo since there may be embedded %s in the strings
        [[ -n $option_verbose ]] && echo "$STBT"

        if [[ -n $option_googletranslate ]]; then          
          string_id=$(echo ${STBT} | cut -d'=' -f1)
          google_querystring=$(echo ${STBT} | cut -d'=' -f2- | sed -e 's/^\\"//' -e 's/\\"$//')
          echo "#    ${string_id}=\"${google_querystring}\"" >> $PATCHFILE
          # Deal with wierd Joomla embedded quotation marks: "_QQ_"
          google_querystring=${google_querystring//\"_QQ_\"/\"}     
          if [[ -n $DEBUG ]]; then     
            google_translation=$(google_translate.pl -q="$google_querystring" -s=$source_lingo_1 -t=$target_lingo_1 2>>"${logfile}")
          else
            google_translation=$(google_translate.pl -q="$google_querystring" -s=$source_lingo_1 -t=$target_lingo_1 2>/dev/null)
          fi
          [ "$google_translation" == "null" ] && DIE "[$LINENO] Google Translation API failed. Check your key, network, docs, dog..."
          [[ -n $option_verbose ]] && INFO "[$LINENO] Translated >>${google_querystring}<< to >>${google_translation}<<"
          echo "echo ${string_id}=\"${google_translation}\"\\" >> $PATCHFILE
        else
          echo "echo \"${STBT}\"\\" >> $PATCHFILE
        fi
        echo "     >> ${a_target_filenames[$i]}" >> $PATCHFILE

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

        if [[ -n $option_suggestions ]]; then
          # Exact Match
          # Use previous efforts so far for suggestions and look up 100% previous translations for this string ID
          STBTid=$(echo $STBT | sed -e 's/=.*//')
          grep -hi "${STBTid}=" ${local_sandbox_dir}/administrator/language/${target_lingo}/*.ini 2>/dev/null  > "$tmpfile4"
          grep -hi "${STBTid}=" ${local_sandbox_dir}/language/${target_lingo}/*.ini 2>/dev/null               >> "$tmpfile4"
          grep -hi "${STBTid}=" ${local_sandbox_dir}/installation/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile4"
          grep -hi "${STBTid}=" ${local_sandbox_dir}/plugins/system/languagecode/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile4"
          grep -hi "${STBTid}=" ${local_sandbox_dir}/templates/*/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile4"
          num_previous_matches=$(cat "$tmpfile4" | wc -l)
          # Check if we have at least 1 match from already-existing translated strings
          if [[ $num_previous_matches -gt 0 ]]; then
            # strip preamble & clean up a litTARGETLINGOe
            cat "$tmpfile4" | sort -u > "$tmpfile5"
            sed -e 's/^.*="*//' -e 's/\"$//' -i "$tmpfile5"
            sed -e 's/:|-/ /' -e 's/%\w*//g' -e 's/  / /' -e 's/  / /' -i "$tmpfile5"
            # Get longest line as it is likely to give the best translated context
            SUGGESTION=$(cat "$tmpfile5" | awk '{ print length(), $0 | "sort -nr" }'| sed -e 's/^[0-9]*\s*//' | head -1)
            echo "# EXACTMATCH: $SUGGESTION" >> $PATCHFILE
          fi

          # Look for same English content that may been translated under a different Id somewhere else
          # Strip preamble - but don't clean up
          STBTs=$(echo $STBT | sed -e 's/^.*=\\*"*//' -e 's/\\*\"*\s*>>.*//' -e 's/\\*\"$//' -e 's/[\.\s]*$//')
          DEBUG "[$LINENO] Looking for the string \"$STBTs\" in\n\t${joomla_source_dir}/administrator/language/${source_lingo}\n\t${joomla_source_dir}/language/${source_lingo}\n\t${joomla_source_dir}/installation/language/${source_lingo}\n\t${joomla_source_dir}/plugins/system/languagecode/language/${source_lingo}\n\t${joomla_source_dir}/templates/\*/language/${source_lingo}"
          grep -hi "${STBTs}" ${joomla_source_dir}/administrator/language/${source_lingo}/*.ini 2>/dev/null >  "tmpfile12"
          grep -hi "${STBTs}" ${joomla_source_dir}/language/${source_lingo}/*.ini 2>/dev/null               >> "tmpfile12"
          grep -hi "${STBTs}" ${joomla_source_dir}/installation/language/${source_lingo}/*.ini 2>/dev/null  >> "tmpfile12"
          grep -hi "${STBTs}" ${joomla_source_dir}/plugins/system/languagecode/language/${source_lingo}/*.ini 2>/dev/null  >> "tmpfile12"
          grep -hi "${STBTs}" ${joomla_source_dir}/templates/*/language/${source_lingo}/*.ini 2>/dev/null  >> "tmpfile12"
          # Remove the string with this Id
          grep -v "^${STBTid}=" "tmpfile12" | sort -u > "$tmpfile6"
          if [[ $(cat "$tmpfile6" | wc -l) -gt 0 ]]; then
            while read -r LINE; do 
              # Get Id
              STBTid=$(echo $STBT | sed -e 's/=.*//')
              DEBUG "[$LINENO] FOUND. Check if the string Id \"$STBTid\" has already been translated in\n\t${local_sandbox_dir}/administrator/language/${target_lingo}\n \t${local_sandbox_dir}/language/${target_lingo}\n\t${local_sandbox_dir}/installation/language/${target_lingo}\n\t${local_sandbox_dir}/plugins/system/languagecode/language/${target_lingo}\n\t${local_sandbox_dir}/templates/\*/language/${target_lingo}"
              # Now search through text of already-translated strings
              grep -hi ${STBTid} ${local_sandbox_dir}/administrator/language/${target_lingo}/*.ini 2>/dev/null  > "$tmpfile7"
              grep -hi ${STBTid} ${local_sandbox_dir}/language/${target_lingo}/*.ini 2>/dev/null               >> "$tmpfile7"
              grep -hi ${STBTid} ${local_sandbox_dir}/installation/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile7"
              grep -hi ${STBTid} ${local_sandbox_dir}/plugins/system/languagecode/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile7"
              grep -hi ${STBTid} ${local_sandbox_dir}/templates/*/language/${target_lingo}/*.ini 2>/dev/null   >> "$tmpfile7"
            done < "$tmpfile6"
            if [[ $(cat "$tmpfile7" | wc -l) -gt 0 ]]; then
              DEBUG "[$LINENO] String Id \"${STBTid}\" has already been translated."
              printf "# PREVIOUS TRANSOURCELINGOATIONS: \n" >> $PATCHFILE
              # Strip preambles
              sed -e 's/^.*=\\*"*//' -e 's/\\*\"*\s*>>.*//' -e 's/\\*\"$//' -i  "$tmpfile7"
              # Select longest translated string
              cat "$tmpfile7" | sort -u | awk '{ print length(), $0 | "sort -nr" }'| sed -e 's/^[0-9]*\s*//' | head -10 > "$tmpfile8"              
              while read -r LINE; do
                echo "# $LINE" >> $PATCHFILE
              done < "$tmpfile8"
            fi
          else
            DEBUG "[$LINENO] The string \"${STBTs}\" has not previously been transalated"
          fi

          # Look up longest word from lexiconned string in already-existing translated strings
          if [[ -n $lexicon ]]; then
            source_packageACED_LINE=$(echo $STBTARGETLINGOex | sed -e 's/_/ /g')
            # Look for longest word but ignore module names
            for l in $source_packageACED_LINE; do [[ ${#l} -gt $len ]] && [[ ${l} =~ [^_] ]] && WORD=$l; len=${#l}; done
            WORD=$(echo $WORD | sed -e 's/.*=//' -e 's/\"//g' -e 's/\.$//')
            if [[ ${#WORD} -ge 4 ]]; then
              grep -hi ${WORD} ${local_sandbox_dir}/administrator/language/${target_lingo}/*.ini 2>/dev/null >  "$tmpfile9"
              grep -hi ${WORD} ${local_sandbox_dir}/language/${target_lingo}/*.ini 2>/dev/null               >> "$tmpfile9"
              grep -hi ${WORD} ${local_sandbox_dir}/installation/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile9"
              grep -hi ${WORD} ${local_sandbox_dir}/plugins/system/languagecode/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile9"
              grep -hi ${WORD} ${local_sandbox_dir}/templates/*/language/${target_lingo}/*.ini 2>/dev/null    >> "$tmpfile9"
            fi
            if [[ $(wc -l "$tmpfile9" | cut -f1 -d" ") -lt 2 ]]; then
              # Look for second-longest word but ignore module names
              for l in $source_packageACED_LINE; do [[ ${#l} -gt $len && ${#l} -lt ${#WORD} ]] && [[ ${l} =~ [^_] ]] && WORD2=$l; len=${#l}; done
              WORD2=$(echo $WORD2 | sed -e 's/.*=//' -e 's/\"//g' -e 's/\.$//')
              if [[ ${#WORD2} -ge 4 ]]; then
                grep -hi ${WORD2} ${local_sandbox_dir}/administrator/language/${target_lingo}/*.ini 2>/dev/null >  "$tmpfile9"
                grep -hi ${WORD2} ${local_sandbox_dir}/language/${target_lingo}/*.ini 2>/dev/null               >> "$tmpfile9"
                grep -hi ${WORD2} ${local_sandbox_dir}/installation/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile9"
                grep -hi ${WORD2} ${local_sandbox_dir}/plugins/system/languagecode/language/${target_lingo}/*.ini 2>/dev/null  >> "$tmpfile9"
                grep -hi ${WORD2} ${local_sandbox_dir}/templates/*/language/${target_lingo}/*.ini 2>/dev/null   >> "$tmpfile9"
              fi
            fi

            # strip preamble & clean up a litTARGETLINGOe
            sed -e 's/^.*="*//' -e 's/\"$//' -i "$tmpfile9"
            sed -e 's/:|-/ /' -e 's/%\w*//g' -e 's/  / /' -e 's/  / /' -i "$tmpfile9"

            # dedupe & order & # remove Help-links
            sort -u -f "$tmpfile9" | grep -v "_" > "tmpfile10"

            # Only keep candidate strings that have about a many words as the source string has
            # Word count in string, rounding down:
            numWords=$(echo $source_packageACED_LINE | wc -w)
            maxWords=$(echo $numWords | awk '{print $0 * 1.5}' | sed -e 's/\..*//')
            minWords=$(echo $numWords | awk '{print $0 * 0.5}' | sed -e 's/\..*//')
            # Pick candidate strings that have word counts in this range
            cat "tmpfile10" | awk '{if (lenth < "'"$minWords"'" && length > "'"$maxWords"'") print ""; else print $0 }' | sort -u > "tmpfile11"
            if [[ $(wc -l "tmpfile11" | cut -f1 -d" ") -gt 0 ]]; then
              cat "tmpfile11" | awk '{ print length(), $0 | "sort -nr" }'| sed -e 's/^[0-9]*\s*//' | head -10 > "tmpfile12"
              printf "# option_suggestions:\n" >> $PATCHFILE
              while read -r SUGGESTION; do
                [[ -z $SUGGESTION ]] && continue
                echo "# $SUGGESTION" >> $PATCHFILE
              done < "tmpfile12"
            fi
          fi
        fi
      done < "$tmpfile2"
      jobcount=$((jobcount+1))
    fi

    diff "$tmpfile13" "$tmpfile14" | grep "^>" > /dev/null
    if [[ $? -eq 0 ]]; then
      MSG1="Job $jobcount: Remove the following string(s) from the file:"
      MSG2="${a_target_filenames[$i]}"
      [[ -n $option_verbose ]] && INFO "$MSG1\n$MSG2"
      printf "\n# $MSG1\n# $MSG2\n" >> $PATCHFILE
      diff "$tmpfile13" "$tmpfile14" | grep "^>" | sed -e "s/^> //g" | sort > "$tmpfile3"
      while read -r LINE; do
        # String To Be Removed
        [[ -n $option_verbose ]] && INFO "[$LINENO] Setting instructions to remove $LINE"
        printf "# %s:\n" "$LINE" >> "$PATCHFILE"
        ESC_LINE=$(echo "$LINE" | sed -e 's|\/|\\\/|g'  -e 's|\!|\\\!|g' -e 's|\*|\\\*|g' -e 's|`|\\`|g')
        printf "sed -e \"/%s\s*=/d\" -i %s\n" >> "$PATCHFILE" ${ESC_LINE} ${a_target_filenames[$i]}
      done < "$tmpfile3"
      jobcount=$((jobcount+1))
    fi

    i=$((i+1))
    [[ $i -ge ${#a_source_filenames[*]} ]] && break
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
$PATCHFILE in $workfolder and then executing it:

  $ cd $workfolder
  $ nano $PATCHFILE
  ... do translations in the file and save ...
  $ ./$PATCHFILE 

Do the same for the other Workfiles.
If you are happy with the changes, you should check the
changes back into the repository with the commands:

  $ cd $local_sandbox_dir
  $ git add . 
  $ git commit -m \"Patched to next Joomla release\"
  $ git push

"

exit 0
