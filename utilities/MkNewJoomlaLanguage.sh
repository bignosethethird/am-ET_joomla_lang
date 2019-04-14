#!/bin/bash
# $Id: MkNewJoomlaLanguage.sh 1939 2015-07-04 14:16:48Z gerrit_hoekstra $
#
# What does it do?
# ~~~~~~~~~~~~~~~
# This script uses the joomla source code to create the code base for a
# Joomla! language pack in a new language. All strings remain in English
# and are translated using other processes.
#
# Configuration
# ~~~~~~~~~~~~~
# This is held in the configuration file, [iso-language-code]-[iso-country-code].conf
#
# Fixed values
# ~~~~~~~~~~~~
#    This is a sub-directory off the SVNPROJECTURL where nightly builds
#    a.k.a. snapshots are stored. (No leading slash). Do not change.
SVNSNAPSHOTS="nightlybuilds"
# This is the sub directory off the SVNPROJECTURL where actual translations
# files are worked on. (No leading slash)
# Set your local initial working folder (no trailing slashes)
WORKFOLDER="${HOME}/joomlawork"
# Initial value until config file is read
TARGETLINGO="xx-XX"

# Inferred values:
TODAY=$(date +"%d %b %Y")
STARTDIR=${PWD}
DEBUG=true
BUILDDATE=$(date +%Y%m%d)
THISYEAR=$(date +%Y)
EXITCODE=0
COMMAND="$0" # Save command

# Set up logging - this is important if we run this as a cron job
PROGNAME=${0##*/}
# Log in work folder
LOGFILE="${WORKFOLDER}/${PROGNAME%\.*}.log"
if [[ ! -f $LOGFILE ]]; then
  touch $LOGFILE 2>/dev/null
  if [[ $? -ne 0 ]]; then
    # Log in HOME
    LOGFILE="~/${PROGNAME%\.*}.log"
    touch "$LOGFILE" 2>/dev/null
    if [[ $? -ne 0 ]]; then
      # Log in CWD
      LOGFILE="${PWD}/${PROGNAME%\.*}.log"
      touch "$LOGFILE" 2>/dev/null
      if [[ $? -ne 0 ]]; then
        printf "Could not write to $LOGFILE. Exiting...\n"
        exit 1
      fi
    fi
  fi
fi

#============================================================================#
# Diagnostics
#============================================================================#
function DEBUG {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "$TS $TARGETLINGO DEBUG: " >> $LOGFILE
  while [[ -n $1 ]] ; do
    printf "$1 " >>  $LOGFILE
    shift
  done
  printf "\n" >> $LOGFILE
}
export -f DEBUG

function INFO {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "$TS $TARGETLINGO INFO: $@\n" | tee -a $LOGFILE
}
export -f INFO

function WARN {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "$TS $TARGETLINGO WARN: $@\n" | tee -a $LOGFILE
}
export -f WARN

# Death to the evil function for it must surely die!
# Parameters:  optional error message
# Exit Code:   1
function DIE {
  TS=$(date '+%Y.%m.%d %H:%M:%S')
  printf "$TS $TARGETLINGO DIE: $@\n" | tee -a $LOGFILE
  exit 1
}
export -f DIE

#============================================================================#
# Configuration
#============================================================================#

INFO "============= BEGIN ============"

function ReadConfiguration {
  INFO "Checking configuration file"
  config_file=$@
  [[ -z $config_file ]] && DIE "No configuration file specified"
  [[ ! -f $config_file ]] && DIE "Configuration file $config_file can not be found"
  INFO "Reading configuration file $config_file"
  source $config_file
  [[ -z $JOOMLABASEVERSION ]] && DIE "Configuration file $config_file does not seem to be the correct file"
  [[ -z $LINGONAME ]] && DIE "Configuration file $config_file does not seem to be the correct file"
  [[ -z $TARGETLINGO ]] && DIE "Configuration file $config_file does not seem to be the correct file"
  # Save full path of config file
  export config_file=${PWD}/${config_file}
}
ReadConfiguration $1


# Replaces en-GB comment header with this comment header
# Parameters: 1	File name
function FileCommentHeader {
  file_name=$1
  [[ -z $file_name ]]   && DIE "$0 called with no file name"
  [[ ! -f $file_name ]] && DIE "$0 can't find file $file_name"
  [[ ! -w $file_name ]] && DIE "$0 can't write to file $file_name"
  # Remote header comments
  # All lines from the beginning that start with ; until the first non-; is  found
  while : ; do head -1 $file_name | grep "^;" > /dev/null; [[ $? -eq 0 ]] && $(tail -n +2 $file_name > ${file_name}_; mv ${file_name}_ ${file_name}) || break; done

  # Add new header - one line at a time (in reverse order!)
  sed -i "1i ; Note : All ini files need to be saved as UTF-8" ${file_name}
  sed -i "1i ; License http://www.gnu.org/licenses/gpl-2.0.html GNU/GPL, see LICENSE.php" ${file_name}
  sed -i "1i ; Copyright (C) ${THISYEAR} ${LINGOSITE}" ${file_name}
  sed -i "1i ; Copyright (C) 2005 - ${THISYEAR} Open Source Matters. All rights reserved." ${file_name}
  sed -i "1i ; Joomla! Project" ${file_name}
  sed -i '1i ; $Id: MkNewJoomlaLanguage.sh 1939 2015-07-04 14:16:48Z gerrit_hoekstra $' ${file_name} # special case for svn propset 
  sed -i "1i ; ${LINGONAME} Language Translation for Joomla\!" ${file_name}
}
export -f FileCommentHeader


# Main program start
cd $WORKFOLDER
INFO "Getting latest Joomla Source code from $SVNJOOMLA into ${JOOMLASOURCE}"
[[ ! -d $JOOMLASOURCE ]] && mkdir -p $JOOMLASOURCE
cd $JOOMLASOURCE

# If you are prompted for a password, remove the line "password-stores =" from  ~/.subversion/config 
# To checkout or to update
trunk=${SVNJOOMLA##*/}
if [[ -d ${trunk}/.svn ]]; then
  INFO "Updating local working copy from Subversion"
  cd $trunk
  DEBUG "svn update"
  svn update
  cd - > /dev/null
else 
  INFO "Checking out a new working copy from Subversion"
  DEBUG "svn checkout $SVNJOOMLA"
  svn checkout $SVNJOOMLA
fi
cd $WORKFOLDER

INFO "Making work environment for $TARGETLINGO in ${WORKFOLDER}/${TARGETLINGO}"
[[ -d $TARGETLINGO ]] && rm -fr $TARGETLINGO
find ${JOOMLASOURCE} -type f -name "${SOURCELINGO}*ini" | grep -v .svn | grep -v "tests/" | sed -e "s|${JOOMLASOURCE}/\(.*\)/${SOURCELINGO}/${SOURCELINGO}\.\(.*\)|${TARGETLINGO}/\1/${TARGETLINGO}|" | sort -u | xargs -I {} mkdir -p {} 2>/dev/null;
INFO "Collecting .ini language source files"
find ${JOOMLASOURCE} -type f -name "${SOURCELINGO}*ini" | grep -v .svn | grep -v "tests/" | sort -u | sed -e "s|${JOOMLASOURCE}/\(.*\)/${SOURCELINGO}/${SOURCELINGO}\.\(.*\)|cp ${JOOMLASOURCE}/\1/${SOURCELINGO}/${SOURCELINGO}\.\2 ${WORKFOLDER}/${TARGETLINGO}/\1/${TARGETLINGO}/${TARGETLINGO}\.\2|" | xargs -I{} bash -c 'source $config_file; INFO "{}"; {}'

INFO "Updating file headers of target language files"
find ${WORKFOLDER}/${TARGETLINGO} -type f -exec bash -c 'source $config_file; INFO "Set header for {}"; FileCommentHeader "{}"' \;

INFO "The new language pack code base for $TARGETLINGO is in your temporary subversion sandbox in ${WORKFOLDER}"
INFO "The content of these files now need to be translated from ${SOURCELINGO} to ${TARGETLINGO}"
INFO "============= END ============"
