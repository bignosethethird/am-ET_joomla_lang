# Suite of Language Tranlation Utilities for Joomla

First: What is Joomla? Find out [here](https://www.joomla.org/)!

Currently Joomla support around 50 spoken languages. Every revision of Joomla requires some text to be translated 
from the origin language, English, to be translated into all 50 languages. Most translation teams have developed 
their own set of tools, an here is another set of such tools. The tool set differs in that it is totally command-line
driven and uses the collaboration abilities of Git to spread the work load across team members.

## Table of Contents

- [Suite of Language Tranlation Utilities for Joomla](#suite_of_language_tranlation_utilities_for_joomla)
  - [Table of Contents](#table_of_contents)
- [Instructions](#instructions)
  - [Naming conventions](#naming_conventions)
  - [How much work is involved in creating a language pack?](#how_much_work_is_involved_in_creating a language pack?)
  - [How does the language pack build process work?](#how_does_the_language_pack_build_process work?)
  - [What are these translation report files?](#what_are_these_translation_report_files?)
- [Install the necessary tools](#install_the_necessary_tools)
  - [Install Git](#install_git)
  - [Create an account for yourself on Github](#create_an_account_for_yourself_on_github)
  - [Configure yourself in Git](#configure_yourself_in_git)
  - [Clone this Git repository](#clone_this_git_repository)
  - [Special case: Create a new language pack](#special_case:_create_a_new_language_pack)
  - [Local vs Global configuration](#local_vs_global_configuration)
  - [Get the latest Joomla CMS source code](#get_the_latest_joomla_cms_source_code)
    - [Select the relevant release](#select_the_relevant_release)
  - [Set up the configuration for building](#set_up_the_configuration_for_building)
  - [Run the build tools](#run_the_build_tools)
    - [Working with Google Translate](#working_with_google_translate)
  - [How to complete the report files](#how_to_complete_the_report_files)
  - [Running the report files](#running_the_report_files)
  - [Building your new language pack](#building_your_new_language_pack)
  - [Test and upload](#test_and_upload)
- [Git Cheat Sheet](#git_cheat_sheet)
  - [Where on earth am I?](#where_on_earth_am_i?)
  - [Renaming files](#renaming_files)
  - [Post changes](#post_changes)
  - [Remote Repositories](#remote_repositories)
  - [Branches](#branches)
  - [Merge branches](#merge_branches)
  - [Dealing with Merge Conflicts](#dealing_with_merge_conflicts)
  - [Tagging](#tagging)
- [Further information](#further_information)
  - [Avoiding confusion: always know your current branch!](#avoiding_confusion:_always_know_your_current_branch!)
  - [Some useful reference material](#some_useful_reference_material)

_NOTE:_

>You can update this TOC as follows:
```bash
grep "^#" README.md | sed -e 's/#/  /g' -e 's/   \(\s*\)\(.*\)/\1- [\2](#\L\2)/' \
-e 's/\(.*(#[a-z:_]*\) /\1_/g' -e 's/\(.*(#[a-z:_]*\) /\1_/g' -e 's/\(.*(#[a-z:_]*\) /\1_/g' \
-e 's/\(.*(#[a-z:_]*\) /\1_/g' -e 's/\(.*(#[a-z:_]*\) /\1_/g' -e 's/\(.*(#[a-z:_]*\) /\1_/g' 
```

# Instructions

The instructions are for any Joomla language pack that uses this tool-set for managing and building language packs for Joomla. Since the first langauae to use this pack was Afrikaans (a-ZA) and it is the first language in the alphabet, we use this for as an example thoughout. 

## Naming conventions

The name of the language pack is made up from the 2-letter ISO code of the language code (lower-case), hyphenated with the 2-letter ISO code of the country (upper case) that the regional variation is aimed at. So for Afrikaans, we have af-ZA, for English we can have en-GB, en-US, en-NZ, en-ZA, etc.

The name of the packaged file that is installed to Joomla is `[language-specifier]_joomla_lang_full_[version-details]`, where `[version-details]` consists of the following series of numbers, along the lines of the `semantic versioning` convention: `[major-revision].[minor-revision].[point-release]v[revision]`. The version number is given by the leader of the Joomla Language Development team, which will always coincide with the version of Joomla that it is aimed at, e.g. `3.9.5`. As leader of your own translation team, you need to ensure that the GIT repository is branched to a branch that is called `3.9.5` so that the building process can use this tag value (more on branching and tagging later on). Furthermore, as a translation team leader, you are only allowed to increment the `[revision]` number (starting at 1), and then only every time that you need to publish a revision, say, when you discovered and corrected bug. 

For example, the language pack version would be `3.9.5v1`, and in the case of the `af-ZA` language, your language pack would be called `af-ZA_joomla_lang_full_3.9.5v1`. Since the actual file would be a ZIP file, the final file name would be hosted in Joomla Language Package repository would be called `af-ZA_joomla_lang_full_3.9.5v1.zip`.

## How much work is involved in creating a language pack?

Let's look at Joomla Release 3.9.5 as example. You can use the commands below to determine this for any other release of Joomla:

* Number of files to translate: 405

```bash
$ find  ~/git/joomla-cms -name "en-GB.*.ini" | wc -l
405
```

* Number of lines to translate in all these files: 9892

```bash
$ find ~/git/joomla-cms -name "en-GB.*.ini" -exec grep '[A-Z_0-9]*="' {} > /tmp/a \;
$ wc -l /tmp/a
9892 /tmp/a
```

* This is how many lines are unique: 8358

```bash
$ sort -u /tmp/a > /tmp/b
$ wc -l /tmp/b
8358 /tmp/b
```
* Number of words to translate: 53492

```bash
$ cut -d"=" -f2- /tmp/b | sed -e 's/"//g'  -e 's/%.//g'   -e 's/\s*%//' -e 's/<[^>]*>//g' -e 's/\\n//g' -e 's/:/ /g' | tr [A-Z] [a-z] > /tmp/c
$ wc -w  /tmp/c
53492 /tmp/c
```
 
* Top occurances of words

This is for interest only, and may give you some insight in how to speed the translation process up. The most frequently-occurring work is the indicative article, 'the':

```bash
$ sed -e 's/\s\s*/\n/g' /tmp/c | grep [a-zA-Z] | grep -v [0-9] |  sed  -e 's/\.//g' -e 's/,//g' -e 's/(//g' -e 's/)//g' -e "s/^'//" -e "s/'$//" -e 's/;$//' -e 's/\!$//' -e 's/\?$//' | grep -v '^/' | sort > /tmp/d
$ $ uniq -c /tmp/d | sort -nr  > /tmp/e
$ less /tmp/e
   2978 the
   1655 to
    997 a
    763 for
    725 of
    675 in
    652 this
    643 is
    530 you
    510 or
    507 be
    501 not
    480 and
    418 will
    414 user
    407 your    
etc...
```

The occurances of each words form a Zipfian distribution, as you would expect the case to be with a large corpus of any given spoken langauge. You can plot this file, note the straight-ish line formed:

```bash
$ gnuplot <<!
> set terminal dumb
> set logscale
> set xrange [1:300]
> plot '/tmp/f' with lines
> !

                                                                               
  10000 +------------------------------------------------------------------+   
        |+                         +                          +           +|   
        |+                                                '/tmp/f' *******+|   
        |+                                                                +|   
        |                                                                  |   
        |*****                                                            +|   
        |     **                                                           |   
   1000 |-+     ********                                                 +-|   
        |+              ********                                          +|   
        |+                      *********                                 +|   
        |+                               *****                            +|   
        |+                                    ********                    +|   
        |                                             *******              |   
    100 |-+                                                 *****        +-|   
        |+                                                      *****     +|   
        |+                                                          ****  +|   
        |+                                                             ****|   
        |+                                                                +|   
        |+                                                                +|   
        |                          +                          +            |   
     10 +------------------------------------------------------------------+   
        1                          10                        100               
```

* Number of unique words to translate: 3004

```bash
$ sort -u /tmp/d > /tmp/e
$ wc -l /tmp/e
3004 /tmp/e
```

Bare in mind that the context varies so a given English word such as 'file' can end up having to be translated into many different words.

## How does the language pack build process work?

The default English en-GB language pack that is bundled with the Joomla installation is used as a reference: _Your_ language pack needs to contain all the text strings that exist in the English langauge pack, which must obvioulsy be translated into your specific language. Needless to say, Joomla grows and changes all the time, with new language strings added to each release. Every time that you execute the build process, it compares what you arready have on your langauge pack against the latest English language pack, creates any new (but blank) files where necessary and gives you a report of what text strings need to be translated. You then translate the missing text strings directly in the report files. The less often you produce langauge packs, the more text strings you are likely to have to translate each time. If you are starting from scratch, expect a huge amount of text strings to be translated. Once the translations are completed in the report files, you can then 'execute' the completed report files. This adds the new strings to your previously-exisitng language pack. 

Run the packagning process to produce the language pack, install the language pack into a spare Joomla instance and test it. If all is OK, then publish the language pack and commit your changes to your local Git repository, tag it and push it to your remote Git repository - ready to produce an new langauge pack when the next version of Joomla is released. 

## What are these translation report files?

The report files are in fact a series of BASH script files and are produced in the directory `~/joomlawork`:

1. New files that need to produced. This file is called `WorkFile_af-ZA_files.sh`. This report file needs to be executed like this:

```bash
~/joomlawork/WorkFile_af-ZA_files.sh
```

Any required new files will be created in your local project directory. Your files will also be named according to your langauge and that is all taken care of by this build process. Once this report script has been executed, the build tool needs to be run again to produce the remaining three reports. If no new files are required, the build process skips this process and continues to create the following:

2. New Text strings in the *installation* section that need to be translated. This file is called `WorkFile_af-ZA_install.sh`. 

3. New Text strings in the *administration* section that need to be translated. This file is called `WorkFile_af-ZA_admin.sh`. 

4. New Text strings in the *front-end* section that need to be translated. This file is called `WorkFile_af-ZA_site.sh`. 

# Install the necessary tools

First you need to install and configure the tools required. You will need:

* A good text editor that can do regular expression search and replacements, such as Visual Code, Notepad++, Kate, Eclipse, etc... 
* Git - the source control tools of choice
* A technical dictionary, either online or in book form.

## Install Git

If you have not installed Git yet, then here's how to do it on Ubuntu / Mint / other Linux derivatives:

```bash
~/ $ sudo apt-get install git
```

## Create an account for yourself on Github

Got to https://github.com and sign up for the free option. No need to part with any money!

You can either join an existing project on Github by forking it your Github account, or create your own project using the af-ZA project at https://github.com/gerritonagoodday/af-ZA_joomla_lang/tree/master/utilities as a template.

## Configure yourself in Git

From here on, all the steps are done in a terminal. Some, but not all of the operations can be done using a GUI tool such as GitKraken too. We will also assume that you are working on the af-ZA language pack.

Open a terminal on your computer.

Set your user name, email address and password up if this is the only Git account that you are likely to use. Only set your password up like this if you are on your personal computer:
```bash
~/ $ git config --global user.name "yourusername"
~/ $ git config --global user.email "your@email"
~/ $ git config --global user.password "XXXXX"
```

Check your configuration. The line with password will be shown 'in the clear' if you have previously set it up, so be aware of who might be shoulder-surfing: 

```bash
~ $ git config --list
user.email=your@email
user.name=yourusername
user.password=XXXXX
```

## Clone this Git repository

Create an area where you want to work with all your Git repos, such as `$HOME/git`:

```bash
~/ $ mkdir git
~/ $ cd git
```

Clone the choosen language pack repo - we use the af-ZA language as an example:

```bash
~/git $ git clone https://github.com/gerritonagoodday/af-ZA_joomla_lang.git
Cloning into 'af-ZA_joomla_lang'...
etc...
Unpacking objects: 100% (xxx/xxx), done.
```

Enter the repo. This is now your work area.

```bash
~/git $ cd af-ZA_joomla_lang/
~/git/af-ZA_joomla_lang $ 
```

## Special case: Create a new language pack

This step is only required if you want to create a new Joomla language pack. Let's assume you want to create a language pack to Amharic / Ge'ez for Ethiopia ('am-ET'). You will only need the `utilities` directory from the 'af-ZA' project and will need to chancge a few values in the configuration.sh file, which is very well documented:

```bash
~/git $ mkdir am-ET_joomla_lang
~/git/am-ET_joomla_lang $ cp -r ../af-ZA_joomla_lang/utilities .
```

Set the configuraton values in `configuration.sh` and continue with the following steps. If you are looking for a quick prototype language pack with about 75% translation accuracy mixed in with utter nonsense (you have been warned), select the 'Google Translate' option below.

## Local vs Global configuration

If you have need to work on this repo as a different user on this user because you are already have multiple Git accounts elsewhere, use the ```--local```-bit 

```bash
~/ $ git config --local user.name "yourusername"
~/ $ git config --local user.emai "your@email"
~/ $ git config --local user.password "XXXXX"
```

## Get the latest Joomla CMS source code

You will need to have the Joomla source code of the release that you are creating a language pack for. The language pack build process (more on this later) unpacks the Joomla installation and uses the default English (en-GB) language strings as a reference, against which the a report is generated of missing language strings so that your language can be brought into alignment with the source reference. If the Joomla installation package has already been published as a .zip or a .tar.gz file, you can use this as your source reference when you run the build process, however you can also use the source code out of the Joomla Git repository as a reference. The only difference s here are that the Git repo also contains test cases in a ```test``` directory, which will be ignored in the build process, and that you need to set the repo to the correct branch before running the build process. So, let's begin by getting the latest Joomla source code from its Git repo:

If you have not done some, create work space for holding all your Git repos, such as ```$HOME/git```:

```bash
~/ $ mkdir git
~/ $ cd git
```

And if you have not done so already, clone the remote repo of the latest version of the Joomla CMS source into a local repo. You only need to this __once__ ever:

```bash
~/git $ git clone https://github.com/joomla/joomla-cms.git
Cloning into 'joomla-cms'...
remote: Enumerating objects: 360, done.
remote: Counting objects: 100% (xxx/xxx), done.
remote: Compressing objects: 100% (xxx/xxx), done.
remote: Total xxx (delta 0), reused 0 (delta 0), pack-reused 0
Unpacking objects: 100% (xxx/xxx), done.
```

Go into the newly-loaded repo directory:

```bash
~/git $ cd joomla-cms
~/git/joomla-cms
```

If you already have a repo of this, you can skip to here and just do a refresh of the repo with the `pull` command:

```bash
~/git/joomla-cms $ git pull
remote: Enumerating objects: 360, done.
etc...
```

Ignore the last comments and instructions - these are meant for actual Joomla PHP developers.

### Select the relevant release

From the Joomla Translation leader, the instruction is to complete the language pack for Joomla release 3.9.5:

```email
From: Ilagnayeru Manickam <mig.joomla@gmail.com>
To: translations@lists.joomla.org
Subject: [Joomla Translation Team] Be Prepared for Joomla! 3.9.5

Good Afternoon!

Be known that Joomla! 3.9.5 RC has been released (https://github.com/joomla/joomla-cms/releases/tag/3.9.5-rc).  Joomla! 3.9.5 stable version is expected to be released on April 9, 2019 ([https://github.com/joomla/joomla-cms/milestones).
.
.
.
Thanks.

- Ilagnayeru (MIG) Manickam
  Joomla! Translations Coordination Team
```   

Now that you have pulled the latest Joomla source code repo in the previous step, list the available tags and select the relevant required tag, `3.9.5`: 

```bash
$ git tag -n | grep "^3\.9\.5"
3.9.5           Joomla! 3.9.5
3.9.5-rc        Joomla! 3.9.5 Release Candidate
|<----Tag---->| |<----Tag Comment---------------...
```

_NOTE:_ 
> Do not confuse Tags with Tag Comments, or Tag Comments with Code Commit comments!

* Checkout code against a tag

This is similar to checking code against a branch, excepts that we need to explicity specify that this is a tag, or multiple tags, by using the `tags/`-specifier.

```bash
$ git checkout tags/'3.9.5'
Checking out files: 100% (9506/9506), done.
Previous HEAD position was 6b8fd2b21f Tag Alpha 6
HEAD is now at 1547f8e760 Prepare 3.9.5 release
```

Check what we have:

```bash
$ git status
HEAD detached at 3.9.5
```

We have now successfully checked out the right code. Generally, should you ever want to develop any new PHP code against the code that relates to this tag, it is good practice to create branch:

```bash
$ git branch '3.9.5-dev'            # branch code
$ git branch                        # check if branching was successful
* (HEAD detached at 3.9.5)          # yes it was:
  3.9.5-dev                         #  - here is the branch, but it is not the active one
  ...
$ git checkout '3.9.5-dev'          # Make this branch active
Switched to branch '3.9.5-dev'
$ git branch                        # Check if this branch is now active
* 3.9.5-dev                         # yes, successfully switched to.
  ...
```

However, we are not going to develop any code off the Joomla main tree, and concentrate on developing the langauge pack only.

## Set up the configuration for building

In the `utilities configuration.sh` file, set the following values:

   ```bash
   # For your first release of version 3.9.5, say this:
   TRANSLATIONVERSION_XML="3.9.5.1"
   # If your lanaguage is something other than af-ZA, change this:
   TARGETLINGO="af-ZA"
   # You may have called the repo for your language something else, 
   # although it helps to stick to this convention. Change this 
   # if your lanaguage is something other than af-ZA:
   GITREPONAME="af-ZA_joomla_lang"
   # Your langauge term for the word "Author"
   LOCAL_AUTHOR="Outeur"
   # Language name - in your own language and the English exonym (
   # Note: endonym is the local name for the language: 
   #           'Kiswahili' or 'Deutsch' or 'isiZulu'.
   #       exonym is what 'outsiders' use to refer to the language: 
   #           'Swahili' or 'German' or 'Zulu'.
   LINGONAME="Afrikaans (ZA)"
   LINGOEXONYM="Afrikaans"

   # This is the native name for the language and needs to be in the local script
   LINGOINDONYM="Afrikaans"
   TARGETCOUNTRY="South Africa"
   # Description of the langauge on one line.
   # This in your target language: "xxxxx (country xxx) translation for Joomla!"
   PACKAGE_HEADER='Afrikaanse Vertaling vir Joomla!'
   # Your langauge term for: "xxxxx language pack in the informal form of address", or something similar
   PACKAGE_DESC="Afrikaanse Taalpaket in die vertroulike aanspreeksvorm"
   # Local language terms:
   # Your langauge term for "Language"
   LOCAL_LANGUAGE="Taal"
   # "Schema"
   LOCAL_SCHEME="Skema"
   # Your langauge term for "Author"
   LOCAL_AUTHOR="Outeur"
   # Your langauge term for "Website"
   LOCAL_WEBSITE="Webwerf"
   # Your langauge term for "Revision"
   LOCAL_VERSION="Hersiening"
   # Date
   LOCAL_DATE="Datum"
   # "Please check the project website frequently for the most recent translation"
   LOCAL_INSTALL="Laat asb. weet indien daar enige tik-foute of grammaktia-foute is - hulle sal so spoedig moontlik reggemaak word!"
   # "All rights reserved" in your language, or use the English.
   LOCAL_ALLRIGHTS="Alle regte voorbehou"
   # Right To Left = 0 for most languages
   RTL=0
   # Locales by which this lnaguage is known
   # e.g. for German: de_DE.utf8, de_DE.UTF-8, de_DE, deu_DE, de, german, german-de, de, deu, germany
   LOCALE="af_ZA.uft8, af_ZA.UTF-8, af, af_ZA, afr_ZA, af-ZA, afrikaans, afrikaans-za, afr, south africa, suid-afrika"
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
   LINGOFLAG="http://www.flags.net/images/largeflags/SOAF0001.GIF"
   #     The website that hosts this translation team
   LINGOSITE="http://forge.joomla.org/gf/project/afrikaans_taal"
   ```

## Run the build tools

TODO

### Working with Google Translate

if you specificy the ```-g``` option when running ```Chk4NewJoomlaLanguageFiles```, the program 
```google_translate.pl``` will be used to invoke the Google Translate API. 
See [https://github.com/gerritonagoodday/google_translate](https://github.com/gerritonagoodday/google_translate)
on follow the instructions for setting yourself up as Google Cloud API user.
This API is not yet perfect and in particular can really mess things up where parts of a string have been marked as "notranslate",
with the aim that Google leaves things as is there. When things get messed up, the string "notranslate" ends up
in the translated text and other bit go wrong too, so this must be manually dealt with in the generated work file. 

If you are in a hurry and want to remove these failures, say, when building an incomplete new language package prototype,
you can remove these from the work files as follows:

```bash
sed '/notranslate/,+1 d' -i WorkFile_am-ET_install.sh
```

## How to complete the report files


Now comes the hard work: all the strings need to be translated from the English into _your_ language in the report file. You can break the files up into sections and distribute them among the translation team members. In the course of typing in the translated text, be careful not to break the syntax of the executable script parts in a line of text - the only part of a line that you should modify is the human-spoken English text. Be particularly careful that you don't disturb the backslashes ('`\`') and double-inverted commas ('`"`') that surround the translation text.

## Running the report files

Once the report files are translated, execute them as follows, which will add your translated strings to the exisitng language pack.
```bash
~/joomlawork/WorkFile_af-ZA_install.sh
~/joomlawork/WorkFile_af-ZA_admin.sh
~/joomlawork/WorkFile_af-ZA_admin.sh
```

## Building your new language pack



## Test and upload



If you are member of an officially-recorgnized language translation team for Joomla, you will also also have access to Joomlacode.org and to Joomla's private Langauge Translation Working Group forum https://forum.joomla.org/viewforum.php?f=11. This will allow you to upload to your completed language pack for Joomla version 3 here: http://joomlacode.org/gf/project/jtranslation3_x



# Git Cheat Sheet

## Where on earth am I?

* The GO-TO Git command, ```git status```:

```bash
$ git status
On branch 3.9
Your branch is up-to-date with 'origin/3.9'.
```

* Show branch tree (in glorious technicolor). Look for the branch containing 'HEAD' - that is your currently-selected branch. 

```bash
$ git log --graph --all --decorate --oneline
* 25793d9 (origin/master, origin/HEAD) Update README.md
| * c9459b9 (origin/4.0, 4.0) new files
| * 4a60d7c 4.0 start
|/  
| * 7705d44 (HEAD -> 3.9, origin/3.9) 3.9
|/  
* 0fdd6dd (master) 
```

Make this command an alias ```gg``` - see further above.

## Renaming files

You can rename a file with the 'move' command:

```bash
$ git mv old_filename new_filename
```

Confirm that was successful:

```bash
$ git status
   renamed: old_filename -> new_filename
```

_NOTE:_
>Remember to commit file name changes.

## Post changes

A Git repository can be thought of as 3 file storage areas, being:
 * The Working Directory
 * The Staging area,a.k.a. the Index
 * The HEAD, which contains the most recently-committed changes

|my       | => |addded to| => |committed to  |
|Working  |    |Staging  |    |current branch|
|Direcory |    |Area     |    |HEAD          |
|:-------:|    |:-------:|    |:------------:|

* Post all changes from your working directory to the staging area. Remember to save the working files first!

```bash
$ git add .
```

* Commit all staged changes to the current branch. Add a useful comment here to explain your working. If you are using an issue management system such as Jira, start the comment with comment with the Issue Number:

```bash
$ git commit -m "TEC1024 Updated docs"
[3.9 642042e] TEC1024 Updated docs
 1 file changed, 184 insertions(+), 5 deletions(-)
```

* Push changes through to the remote repository's corresponding branch. If the branch does not yet exist on the remote repo, it will be created. If you have nt configured your access credentials yet with the `git config

```bash
$ git push 
Username for 'https://github.com': XXX
Password for 'https://gerritonagoodday@github.com': 
Counting objects: 3, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 4.02 KiB | 187.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0)
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
To https://github.com/gerritonagoodday/af-ZA_joomla_lang.git
   7705d44..642042e  3.9 -> 3.9
```


## Remote Repositories

The above `push` operation of the most recent changes to a remote repo introduces the concept of interacting with other source repositories. Assuming that you have been developing stuff in the absence of a version control system like Git and would like to add your collection of work into the root of a large project _somewhere else_, you can convert your work into a Git repo and then make it part of the remote. 

* Convert your non-versioned work into a repo

```bash
$ git init
Initialised empty Git repository in [my_project_directory]
```

* Add all the files in your project to your new (local) repo's staging area:

```bash
$ git add .
```

* Commit the staged files. This also makes them eligiable for pushing over to the remote repo in the next step:

```bash
$ git commit -m 'My project files'
```

The files are still not in the remote location. This is done in the next step.

* Join the remote repo (of which you know the remote git-file's URL) with your repo

First, check that no remote repo is already associated with this local repo:

```bash
$ git remote
$
```

Nothing. Now connect your local repo (notionally called 'origin') to the repo on the remote server:

```bash
$ git remote add origin https://github.com/gerritonagoodday/af-ZA_joomla_lang.git
```

Check again if the _remote repo_ is associated with this _local repo_:

```bash
$ git remote
$ origin
```

Yes, it is, and it is called 'origin', which is an _alias for the remote repo_. You can see this in more detail with the _verbose_ version of this command:

```bash
$ git remote -v
origin  https://github.com/gerritonagoodday/af-ZA_joomla_lang.git (fetch)
origin  https://github.com/gerritonagoodday/af-ZA_joomla_lang.git (push)
```

* Finally, push the files from origin to master

```bash
$ git push origin master
```
If you have not set up your user credientials to the _remote repo_, you will be prompted to do so now.

## Branches

This section lists a bunch of recipes and cheats that relate to branches.

* A simple approach to use branches

By default, a Git repository has at least one branch, called 'master'.

Branches are created to develop specific feature sets in, or to create a specific release with feature sets in. Once the development of the branch has been completed, the code can optionally be 'tagged' with the release name, and the branch can be merged back into the master branch. All branches must eventually rendevouz to the master branch. When a branch has successfully been merged into the master (branch), the branch has effectively been removed. All that remains is the optional 'tag' of the code. 

Should a branch need to be revisited in order to, say, fix a minor problem for a point-release, a branch can be made from the previous release tag. The fix is made, added, commited and pushed to remote, a point-release package is built, and the branch tagged with the point-release name and is merged into the master again, and the point-release branch does not exist any more. Repeat this process as often as required.

* List all current branches in repo. the one marked with a '*' is the currently-selected branch:

```bash
$ git branch
* 3.9
  4.0
  master
```

* Select an existig branch, i.e. checkout a branch:

```bash
$ git checkout '3.9'
Switched to branch '3.9'
Your branch is up-to-date with 'origin/3.9'.
```

Also do this to intentionlly obliterate any code changes that you have made thus far on branch '3.9', and to start afresh.

* Create a new branch off the currently-selected branch '3.9':

```$ git branch [new_branch_name]```

For example:

```$ git branch '3.9.5'```

Check the result - a new brnach was created but you are still on the last selected branch:

```bash
$ git branch
* 3.9
  3.9.5
  4.0
  master
```

* Delete a branch

Do this to remove a branch and all its work from your local repo.

```bash
$ git branch -d '3.9.5'
Deleted branch 3.9.5 (was 7705d44).
```

* Push a branch to your remote repo

One way to make your work in your local branch visible to the public is to commit your branch and to push it to the remote repo. Chance are that the branch does not yet exist on the remote repo, so will need to force the creation of the branch on the remote repo:

```bash
$ git push --set-upstream origin 3.9.5
Username for 'https://github.com': XXXX
Password for 'https://XXXX@github.com': 
...
...
To https://github.com/gerritonagoodday/af-ZA_joomla_lang.git
 * [new branch]      3.9.5 -> 3.9.5
Branch '3.9.5' set up to track remote branch '3.9.5' from 'origin'.
```

_NOTE:_
>Remeber to add and commit your changes first before pushing to remote.

Once you have create the branch on the remote repo, you can push as per normal:

```bash
$ git push
Everything up-to-date
```

## Merge branches

Merging code from another branch cleverly folds the files and lines of code in the files together, and also commits the changes at the same time. Of course, only commiteted code can be merged to somewhere else.

```bash
$ git merge '[other-branch]'
```

_NOTE:_
>1. You need to 'be in the branch' that is being merged to. Use the `git checkout '[branch-name]'` for this.
>2. The code is automatically commited after a merge. No need to do a `git commit` after a successful merge.
>3. Sometimes, a merge conflict arrises and needs to be resolved through your manual intervention. See the next section.

When a branch has been merged to `master`, the branch will continue to exist. If you are ready to do so, you can delete the branch forever:

```bash
$ git branch -d '[branch-to-delete]'
```

## Dealing with Merge Conflicts

Git attempts to automatically merge code from branches. Where there is any doubt on how a merge of code should be done, it raises a _merge conflict_ and invokes a merge tool that the user can use to correctly resolve the conflict. Luckily, the merging operation is mostly a straight-forward process and does not require user intervention. 

Because it can get complicated to resolve conflicting code during a merge on the command line, a number of graphical tools are available to make the operation clearer. The tool of choice here is `meld`. It is totally awesome. If you do not already have it installed, install it like this:

```bash
$ sudo apt install meld
```
You also need to configure Git to automatically invoke `meld` when the need arrrises to resolve merge conflicts:

Set the graphical merginging tool up
```bash
$ git config merge.tool meld
```

Let's assume that you are merging branch '3.9.5' to branch 'master' and this happens:

...TODO...

Run the merge tool:

```bash
$ git mergetool
```





## Tagging

Branches (mostly) rendevouz back to the `master` branch eventually after performing the necessary commits and merges. You may well decide to delete the branch, as its contents is now in the master branch. You can mark the committed code base with a tag that indicates the code release Id, or anything else that is significant in the life cycle of the code base.

* Create a tag 

```bash
$ git tag '3.9.5.1'
```

What can be very helpful is to add a comment to your new tag:

```bash
$ git tag '3.9.5.1' -m 'First point release'
```

Remember to do this only after you have committed your code. 

* List tags in a repository 

You can list all the tags and their comments in a repo (`-l` lists them without commants). In some cases, there can be many tags, so add a filter expression to limit the result:

```bash
$ git tag -n "3.9.5*" 
3.9.5           Joomla! 3.9.5
3.9.5-rc        Joomla! 3.9.5 Release Candidate
```

If you need to use a RegEx to for even finer filtering:

```bash
$ git tag -n | grep "^3\.9\.5"
3.9.5           Joomla! 3.9.5
3.9.5-rc        Joomla! 3.9.5 Release Candidate
```

Do not confuse Tags with Tag Comments, or with Code Commit comments!

* Checkout code against a tag

This is similar to checking code against a brnach, excepts that we need to explicity specify that this is a tag, or multiple tags, by using the `tags/`-specifier.

```bash
$ git checkout tags/'3.9.5'
Checking out files: 100% (9506/9506), done.
Previous HEAD position was 6b8fd2b21f Tag Alpha 6
HEAD is now at 1547f8e760 Prepare 3.9.5 release
```

Check what we have:

```bash
$ git status
HEAD detached at 3.9.5
```

Successfully checked out the right code. Should you want to develop and new code against the code that relates to this tag, it is good practice to create branch:

```bash
$ git branch '3.9.5-dev'            # branch code
$ git branch                        # check if branching was successful
* (HEAD detached at 3.9.5)          # yes it was:
  3.9.5-dev                         #  - here is the branch, but it is not the active one
  ...
$ git checkout '3.9.5-dev'          # Make this branch active
Switched to branch '3.9.5-dev'
$ git branch                        # Check if this branch is now active
* 3.9.5-dev                         # yes, successfully switched to.
  ...
```


# Further information

## Avoiding confusion: always know your current branch!

You can avoid a lot of confusion and possible mishaps of getting code in branches mixed up by always displaying the currently-selected branch on the command line. This is shown by default if you installed the Linux Git features on Windows. On the Linux terminal, you need to modify the PS1 variable in your local ```~/.bashrc``` file to show the current branch. For Debian-based Linux distros (around line 68), change the PS1 assignment to this:

```bash
PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \[\033[33;1m\]\$(git status 2>/dev/null | head -n1 | cut -d' ' -f3- | sed -e 's/\(.*\)/(\1) /')\[\033[01;34m\]\$\[\033[00m\] "
```

For all other Linuxes:

```bash
PS1="\[\e]0;\u@\h \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \[\033[33;1m\]$(git status 2>/dev/null | head -n1 | cut -d' ' -f3- | sed -e 's/\(.*\)/(\1) /')\[\033[01;34m\]$\[\033[00m\] "
```

Also add the following utility command to your local ```~/.bashrc``` file, which shows you a quick and colourful graph of the branches with the ```gg``` command:

```bash
alias gg="git log --graph --all --decorate --oneline"
```

## Some useful reference material

1. This is a good introduction to Git for a zero-knowledge start:

<a href="http://www.youtube.com/watch?feature=player_embedded&v=SWYqp7iY_Tc" target="_blank"><img src="http://img.youtube.com/vi/SWYqp7iY_Tc/0.jpg" 
alt="Git & GitHub Crash Course For Beginners" width="240" height="180" border="10" /></a>

2. Use GitKraken as a Git visualization tool. Download it from here: 

<a href="https://www.gitkraken.com/download" target="_blank"><img src="https://pbs.twimg.com/profile_images/714866842419011584/LRrR48qp_400x400.jpg" alt="GitKraken" width="240" height="180" border="10" /></a>


