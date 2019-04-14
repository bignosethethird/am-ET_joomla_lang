#!/bin/bash

# Translation version: [major].[minor].[point].[revision], used inside the XML definition, no leading zeros.
# Only change this value when building a new version. It must be in the form x.y.z.n
# - other variants of this version will be calculated
TRANSLATIONVERSION_XML="3.9.5.1"

# What it this file for?
# ~~~~~~~~~~~~~~~~~~~~~
# o Holds all the configuration values for building Joomla Language packs,
#'
# o Change this file every time a new release of a language pack needs to be
#   built
#
# o One file per language
#
# o Recommended configiration file name is:
#    [iso-language-code]-[iso-country-code].conf
#    More on language code naming below.
#
# Git file Structure:
# ~~~~~~~~~~~~~~~~~~~
# This is what the directory structure off the root of your repo in Git is
# expected to look like, where LINGO is the name of your language,
# made of the ISO 639-1 2-letter language code and the ISO 3166-1 2-letter 
# country code. e.g. af-ZA, en-GB, etc..
#
# Git Repo Root
# +...xx-XX_joomla-lang
#     |
#     +...administrator
#     |   +...help
#     |   .   +...LINGO
#     |   +...language
#     |       +...LINGO
#     |       +...overrides
#     |
#     +...language
#     |   +...LINGO
#     |   +...overrides
#     |
#     +...installation
#     |   +...language
#     |   |   +...LINGO
#     |   +...sql
#     |        +...mysql
#     |
#     +---libraries
#     |   +...joomla
#     |       +...html
#     |           +...language
#     |               +...LINGO
#     +...plugins
#         +...system
#             +...languagecode
#                 +...language
#                     +...LINGO

# Set your local working folder (no trailing slashes)
WORKFOLDER="${HOME}/joomlawork"
# Needs to be here for sub-shell use
THISYEAR=$(date +%Y)

# Language Configuration Items
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Joomla translation language in the following form:
#    2-letter ISO language + hyphen + 2-letter ISO country
#    Examples:
#    af-ZA for Afrikaans as spoken in South Africa
#    sw-TZ for Swahili as spoken in Tanzania
#    sw-KE for Swahili as spoken in Kenya
#    zu-ZA for Zulu as spoken in South Africa
# Source Language - this will never change!
SOURCELINGO="en-GB"
# Put YOUR target language here:
TARGETLINGO="am-ET"

# Build Configuration
# ~~~~~~~~~~~~~~~~~~~

# Calculate the rest:
major=$(echo $TRANSLATIONVERSION_XML  | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/g")
minor=$(echo $TRANSLATIONVERSION_XML  | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\2/g")
point=$(echo $TRANSLATIONVERSION_XML  | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3/g")
revision=$(echo $TRANSLATIONVERSION_XML  | sed -e "s/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\4/g")

# Joomla Base version that this transalation pack is aimed at: [major].[minor]
JOOMLABASEVERSION="${major}.${minor}"
# Specific Joomla target version that this translation pack is aimed at: [major].[minor].[point]
JOOMLAVERSION="${major}.${minor}.${point}"
# Translation version: [major].[minor].[point]v[revision], used in the package file name, no leading zeros.
TRANSLATIONVERSION="${major}.${minor}.${point}v${revision}"
# Git files are in this repo (no leading slashes). Unlikely to change.
GITREPONAME="am-ET_joomla_lang"
# Language name - in your own language and the English exonym (
# Note: endonym is the local name for the language: 
#           'Kiswahili' or 'Deutsch' or 'isiZulu'.
#       exonym is what 'outsiders' use to refer to the language: 
#           'Swahili' or 'German' or 'Zulu'.
LINGONAME="Amharic (ET)"
LINGOEXONYM="Amharic"
# This is the native name for the language and needs to be in the local script
LINGOINDONYM="አማርኛ"
TARGETCOUNTRY="Ethiopia"
# Description of the langauge on one line.
# This in your target language: "xxxxx (country xxx) translation for Joomla!"
PACKAGE_HEADER='ለዚህ ትርጉም Joomla!'
# Your langauge term for: "xxxxx language pack in the informal form of address", or something similar
PACKAGE_DESC="በአማርኛ ቋንቋ የተዘጋጀ መደበኛ ያልሆነ የአድራሻ ቅፅ"
# Local language terms:
# Your langauge term for "Language"
LOCAL_LANGUAGE="ቋንቋ"
# Your langauge term for "Schema"
LOCAL_SCHEME="እቅድ"
# Your langauge term for "Author"
LOCAL_AUTHOR="ደራሲ"
# Your langauge term for "Website"
LOCAL_WEBSITE="ድህረገፅ"
# Your langauge term for "Revision"
LOCAL_VERSION="ክለሳ"
# Your langauge term for Date
LOCAL_DATE="ቀን"
# Your langauge term for "Please check the project website frequently for the most recent translation"
LOCAL_INSTALL="እባክዎ በጣም የቅርብ ጊዜውን የትርጉም ሂደት በተደጋጋሚ የፕሮጀክት ድር ጣቢያው ይመልከቱ. ይሄ Google ትርጉምን በመጠቀም የታመነ ሙከራ ነው."
# Your langauge term for "All rights reserved", or use the English.
LOCAL_ALLRIGHTS="መብቱ በህግ የተጠበቀ ነው"
# Right To Left = 0 for most languages
RTL=0
# Locales by which this lnaguage is known
# e.g. for German: de_DE.utf8, de_DE.UTF-8, de_DE, deu_DE, de, german, german-de, de, deu, germany
LOCALE="am_ET.uft8, am_ET.UTF-8, am, am_ET, amh_ET, am-ET, amharic, amharic-et, amh, ethiopia, ኢትዮጵያ"
# First day of the week in the locale, mostly 1 = Sunday, sometimes 2 = Monday or 6=Saturday
FIRSTDAY=1
# Name of package author or team
AUTHORNAME="Gerrit Hoekstra"
# Email address of author or team
AUTHOREMAIL="gerrit@hoekstra.co.uk"
# Installation Configuration:
#     A flag to display on successful completion of installation
#     This can either be a publically-accessible URL or the name of graphics file. e.g.
#     http://joomla4africa.org/images/smallflags/South Africa.gif
#     If it is a file then specify relative to the directory that this file is in. If it is a file,
#     it will be UU-encoded into the installation XML file. 
#     The Recommended size for the images is 256x256 pixels, PNG format and with background alpha-channeled.
#     Find your flag in http://www.flags.net
LINGOFLAG="http://www.flags.net/images/largeflags/ETHP0001.GIF"
#     The website that hosts this translation team
LINGOSITE="http://forge.joomla.org/gf/project/afrikaans_taal"

