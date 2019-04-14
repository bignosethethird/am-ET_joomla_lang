#!/bin/bash
# $Id: MkJoomlaSnapshotBuild.sh 1939 2015-07-04 14:16:48Z gerrit_hoekstra $

# What does it do?
# ~~~~~~~~~~~~~~~~
# This script fetches the latest state of all translations from SVN and
# builds a custom Joomla installation package based on the English-based
# Joomla installation. The difference is that when you create a new Joomla
# installation with this package, it will be entirely configured to your 
# chosen language and will display your latest translation efforts from 
# the SVN version control system.
#
# This installtion is then checked back into SVN in the NightlyBuilds 
# directory.
#
# Using daily builds allows a curious person, who is prepared to take some
# risks with regards to language instability, to install the project and to
# evaluate it (and to fawn and marvel at your fantastic work). Once you are 
# happy with the functionality and the stability of the language pack, you can
# release it into the public domain - typically in the Files sections of your
# project in http://joomlacode.org (this last bit is a manual process).
#
# Usage
# ~~~~~
# You would normally run this script via a cron job on a daily basis.
# Copy this script to a suitable place such as /usr/local/bin.
# Enter the following in your cron table (use the command `crontab -e` as user
# `root`) to run this process every night at 2.08 am for example:
# 08 2 * * * /usr/local/bin/MkJoomlaSnapshotBuild.ksh
#
# Environment:
# ~~~~~~~~~~~
# Below is what the expected directory structure off the SVN root of your
# project is expected to look like, where LINGO is the name of your language.
# (The LINGO-variable is described below)
#
# +...Joomla1.5.0
# |   +...administrator
# |   |   +...help
# |   |   .   +...LINGO                 -->         DATA
# |   |   +...language                              GOES
# |   |       +...LINGO                 -->         FROM
# |   +...language                                  HERE
# |   |   +...LINGO                     -->         TO...
# |   +...installation
# |       +...language
# |       |   +...LINGO                 -->
# |       +...sql
# |           +...mysql                 -->
# |                                                 
# +...nightlybuilds                     <--         HERE
#
# So, what happens here?
# ~~~~~~~~~~~~~~~~~~~~~
# The language directories are assembled into a complete Joomla install pack
# and then put back into the nightly builds directory. You will get a file 
# in there that you can use to install a brand new, but custom-made Joomla 
# installation, which includes your spoken language.
#
# One-Off Preparation
# ~~~~~~~~~~~~~~~~~~~
# 1. Take the latest Joomla release package and name it to
#    [your language]_[JoomlaPackageName].zip
#    (Use the .zip package so that Windows Weenies can also it)
# 2. Create a directory in your Subversion repository called Snapshots
# 3. Commit this renamed Joomla package into the Snapshots directory.
# 4. Now continue with the configuration below:
#
# Configuration
# ~~~~~~~~~~~~~
# 0. Set the project name 
PROJECT="Joomla-1.5"
# 1. Set the SVN project name, snapshot directory and the source files
#    directory (no trailing slashes)
SVNPROJECT="http://joomlacode.org/svn/afrikaans_taal"
#    This is a sub-directory off the SVNPROJECT where snapshots are stored.
SVNSNAPSHOTS="nightlybuilds"
#    This is the sub directory off the SVNPROJECT where actual translations
#    files are worked on.
SVNFILES="Joomla1.5.0"
# 2. Set your local working folder (no trailing slashes)
WORKFOLDER="/tmp"
# 3. Set the SVN user name and password. Get an SVN account from 
#    http://joomlacode.org when you register your project.
#SVNUSERNAME="SVN user name"
SVNPASSWD="very_secret_password"
SVNUSERNAME="gerrit_hoekstra"
SVNPASSWD="tic206d2"
# 4. Joomla translation language in the following form:
#    2-letter ISO language + hyphen + 2-letter ISO country
#    Put YOUR LANGUAGE here:
LINGO="af-ZA"
# 5. Nightly Build installation file name
#    This is a standard Joomla component install.
#    The build date in the file name will be displayed in
#    the format YYYYMMDD.
NIGHTLYBUILDFILENAME="${LINGO}_${PROJECT}_nightlybuild"

# Save current environment
STARTDIR=${PWD}

# Static values
DEBUG=true
BUILDDATE=$(date +%Y%m%d)
TODAY=$(date +"%d %b %Y")
FINALBUILDFILENAME="${NIGHTLYBUILDFILENAME}-${BUILDDATE}.zip"
PACKFOLDER="${WORKFOLDER}/pack"

# Set up logging - this is important if we run this as a cron job
PROGNAME=${0##*/}
LOGFILE="/var/log/${PROGNAME%\.*}.log"
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
printf "============= BEGIN: $(date) ===========\n" | tee -a $LOGFILE

# Debug
function debug {
  [[ -z $DEBUG ]] && return
  msg=$1
  printf "DEBUG: $msg\n" | tee -a $LOGFILE
}

SVN=/usr/bin/svn
[[ ! -a $SVN ]] && printf "$SVN does not exist. Exiting...\n" | tee -a $LOGFILE && exit 1
[[ ! -x $SVN ]] && printf "$SVN is not executable. Exiting...\n" | tee -a $LOGFILE && exit 1

printf "Check working directory $WORKFOLDER...\n" | tee -a $LOGFILE
if [[ ! -d $WORKFOLDER ]]; then
  printf "Making $WORKFOLDER...\n"
  mkdir -p $WORKFOLDER
fi
if [[ ! -d $WORKFOLDER ]]; then
  printf "Working folder $WORKFOLDER does not exist.\nExiting...\n" | tee -a $LOGFILE
  exit 1
fi
if [[ ! -w $WORKFOLDER ]]; then
  printf "Working folder $WORKFOLDER is not writable.\nExiting...\n" | tee -a $LOGFILE
  exit 1
fi

cd $WORKFOLDER
rm -fr $PACKFOLDER 2>/dev/null
rm -fr $SVNSNAPSHOTS 2>/dev/null
rm -fr $SVNFILES 2>/dev/null

printf "Get all nightly builds from $SVNPROJECT/$SVNSNAPSHOTS to $WORKFOLDER as user $SVNUSERNAME...\n" | tee -a $LOGFILE
debug    "svn checkout --username $SVNUSERNAME --password $SVNPASSWD $SVNPROJECT/$SVNSNAPSHOTS"
RETCODE=$(svn checkout --username $SVNUSERNAME --password $SVNPASSWD $SVNPROJECT/$SVNSNAPSHOTS)
echo $RETCODE | grep error
if [[ $? -eq 0 ]]; then
  printf "Could not check out project $SVNPROJECT/$SVNSNAPSHOTS as user $SVNUSERNAME to $WORKFOLDER.\nExiting...\n" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
fi
echo $RETCODE | grep fail
if [[ $? -eq 0 ]]; then
  printf "Could not check out project $SVNPROJECT/$SVNSNAPSHOTS as user $SVNUSERNAME to $WORKFOLDER.\nExiting...\n" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
fi

printf "Most recent nightly build is..." | tee -a $LOGFILE
LASTNIGHTLYBUILDFILENAME=$(find $SVNSNAPSHOTS -type f -name "*.zip" | grep $NIGHTLYBUILDFILENAME | sort | tail -1 | sed -e "s|\.\/||g")
if [[ -z $LASTNIGHTLYBUILDFILENAME ]]; then
  printf "none yet\n" | tee -a $LOGFILE
  # There is no nightly build file on which to base this on 
  printf "The build system needs to be primed!
This nightly build is based on an existing Joomla installation package,
which could not be found in the '$SVNSNAPSHOTS' SVN folder.
You need to find a copy of the latest Joomla package in .zip archive form,
rename it to $FINALBUILDFILENAME
and add it to the '$SVNSNAPSHOTS' SVN folder using these commands (assuming
the downloaded package is ~/Joomla-1.5.zip):
  \$ cd $WORKFOLDER/$SVNSNAPSHOTS
  \$ cp ~/Joomla-1.5.zip $FINALBUILDFILENAME
  \$ svn add $FINALBUILDFILENAME
  \$ svn ci -m \"Latest Joomla installation package\"
Then rerun this script.
Exiting...
" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
else
  printf "$LASTNIGHTLYBUILDFILENAME\n" | tee -a $LOGFILE
  printf "Unpack $LASTNIGHTLYBUILDFILENAME to $PACKFOLDER...\n" | tee -a $LOGFILE
  debug    "unzip $LASTNIGHTLYBUILDFILENAME -d $PACKFOLDER 1>/dev/null"
  RETCODE=$(unzip $LASTNIGHTLYBUILDFILENAME -d $PACKFOLDER 1>/dev/null)
  if [[ $RETCODE -ne 0 ]]; then
    printf "Could not unzip file $LASTNIGHTLYBUILDFILENAME. Error code from unzip: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
    cd $STARTDIR
    exit 1
  fi
  debug "rm $LASTNIGHTLYBUILDFILENAME"
  rm $LASTNIGHTLYBUILDFILENAME
fi

printf "Get Source Files from $SVNPROJECT/$SVNFILES...\n" | tee -a $LOGFILE
debug    "svn checkout --username $SVNUSERNAME $SVNPROJECT/$SVNFILES"
RETCODE=$(svn checkout --username $SVNUSERNAME $SVNPROJECT/$SVNFILES)
echo $RETCODE | grep error
if [[ $? -eq 0 ]]; then
  printf "Could not check out files from $SVNPROJECT/$SVNFILES as user $SVNUSERNAME to $WORKFOLDER.\nExiting...\n" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
fi
echo $RETCODE | grep fail
if [[ $? -eq 0 ]]; then
  printf "Could not check out file from $SVNPROJECT/$SVNFILES as user $SVNUSERNAME to $WORKFOLDER.\nExiting...\n" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
fi

printf "Collate translated files into snapshot build...\n" | tee -a $LOGFILE
# Repeat this code for translations of other components that you want to
# incorporate in the Joomla Install snapshot.
# .svn directories will not be overwritten
printf "  1. Merging language/$LINGO...\n" | tee -a $LOGFILE
debug "rm -fr $PACKFOLDER/language/$LINGO"
rm -fr $PACKFOLDER/language/$LINGO
CMD="cp -r $SVNFILES/language/$LINGO $PACKFOLDER/language/. "
debug "$CMD"
$($CMD 2>/dev/null)

printf "  2. Merging administrator/language/$LINGO...\n" | tee -a $LOGFILE
debug "rm -fr $PACKFOLDER/administrator/language/$LINGO"
rm -fr $PACKFOLDER/administrator/language/$LINGO
CMD="cp -r $SVNFILES/administrator/language/$LINGO $PACKFOLDER/administrator/language/."
debug "$CMD"
$($CMD 2>/dev/null)

printf "  3. Merging administrator/help/$LINGO...\n" | tee -a $LOGFILE
debug "rm -fr $PACKFOLDER/administrator/help/$LINGO"
rm -fr $PACKFOLDER/administrator/help/$LINGO
CMD="cp -r $SVNFILES/administrator/help/$LINGO $PACKFOLDER/administrator/help/."
debug "$CMD"
$($CMD 2>/dev/null)

printf "  4. Merging installation/language/$LINGO...\n" | tee -a $LOGFILE
debug "rm -fr $PACKFOLDER/installation/language/$LINGO"
rm -fr $PACKFOLDER/installation/language/$LINGO
CMD="cp -r $SVNFILES/installation/language/$LINGO $PACKFOLDER/installation/language/."
debug "$CMD"
$($CMD 2>/dev/null)

printf "  5. Merging installation/sql/mysql/ sql files...\n" | tee -a $LOGFILE
debug "rm $PACKFOLDER/installation/sql/mysql/*"
rm  $PACKFOLDER/installation/sql/mysql/*
CMD="cp -r $SVNFILES/installation/sql/mysql/*.sql $PACKFOLDER/installation/sql/mysql/."
debug "$CMD"
$($CMD 2>/dev/null)

if [[ -z $LASTNIGHTLYBUILDFILENAME ]]; then
  printf "Package up installation snapshot to $SVNSNAPSHOTS/$FINALBUILDFILENAME...\n" | tee -a $LOGFILE
  debug    "zip -r -m $SVNSNAPSHOTS/$FINALBUILDFILENAME $PACKFOLDER/*  -x '*/.svn/*' 1>/dev/null 2>&1"
  RETCODE=$(zip -r -m $SVNSNAPSHOTS/$FINALBUILDFILENAME $PACKFOLDER/*  -x "*/.svn/*" 1>/dev/null 2>&1)
  if [[ $RETCODE -ne 0 ]]; then
    printf "Could not package the snapshot into file $FINALBUILDFILENAME. Error code from zip: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
    cd $STARTDIR
    exit 1
  fi
else
  # Exists already - need to override existing and then rename in SVN
  printf "Package up installation snapshot to overwrite $LASTNIGHTLYBUILDFILENAME...\n" | tee -a $LOGFILE
  cd $PACKFOLDER
  debug    "zip -r -m $WORKFOLDER/$LASTNIGHTLYBUILDFILENAME * -x '*/.svn/*' 1>/dev/null 2>&1"
  RETCODE=$(zip -r -m $WORKFOLDER/$LASTNIGHTLYBUILDFILENAME * -x "*/.svn/*" 1>/dev/null 2>&1)
  cd -
  if [[ $RETCODE -ne 0 ]]; then
    printf "Could not package the snapshot into file $LASTNIGHTLYBUILDFILENAME. Error code from zip: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
    cd $STARTDIR
    exit 1
  fi
  if [[ $LASTNIGHTLYBUILDFILENAME != $FINALBUILDFILENAME ]]; then
    printf "Renaming $LASTNIGHTLYBUILDFILENAME to $SVNSNAPSHOTS/$FINALBUILDFILENAME in SVN...\n" | tee -a $LOGFILE
    RETCODE=$(svn rename $LASTNIGHTLYBUILDFILENAME $SVNSNAPSHOTS/$FINALBUILDFILENAME --force)
    echo $RETCODE | grep error
    if [[ $? -eq 0 ]]; then
      printf "Could not rename $LASTNIGHTLYBUILDFILENAME to $FINALBUILDFILENAME in SVN. Error code from svn: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
      cd $STARTDIR
      exit 1
    fi
    echo $RETCODE | grep fail
    if [[ $? -eq 0 ]]; then
      printf "Could not rename $LASTNIGHTLYBUILDFILENAME to $FINALBUILDFILENAME in SVN. Error code from svn: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
      cd $STARTDIR
      exit 1
    fi
  fi
fi

printf "Check-in Joomla Installation $SVNSNAPSHOTS/$FINALBUILDFILENAME...\n" | tee -a $LOGFILE
cd $SVNSNAPSHOTS
debug    "svn commit --username $SVNUSERNAME --password $SVNPASSWD -m 'Joomla install with $LINGO translations as of $TODAY'"
RETCODE=$(svn commit --username $SVNUSERNAME --password $SVNPASSWD -m "Joomla install with $LINGO translations as of $TODAY")
echo $RETCODE | grep error
if [[ $? -eq 0 ]]; then
  printf "Could not check-in the snapshot $FINALBUILDFILENAME. Error code from svn: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
fi
echo $RETCODE | grep fail
if [[ $? -eq 0 ]]; then
  printf "Could not check-in the snapshot $FINALBUILDFILENAME. Error code from svn: $RETCODE.\nExiting...\n" | tee -a $LOGFILE
  cd $STARTDIR
  exit 1
fi
cd -

printf "Cleaning up...\n" | tee -a $LOGFILE
#rm -fr $SVNSNAPSHOTS 2>/dev/null
#rm -fr $SVNFILES 2>/dev/null
cd $STARTDIR

printf "============= END:   $(date) ===========\n" | tee -a $LOGFILE
