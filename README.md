# TiddlyWiki on NAS

Scripts and configuration to run [TiddlyWiki on
Node.js](https://tiddlywiki.com/#TiddlyWiki%20on%20Node.js) on a
[Synology](https://www.synology.com/) Network Attached Storage (NAS) device.

I use this to:

1. Start an instance of TiddlyWiki on the NAS device that is always running at
my home anyway. That enables access to the notes kept in TiddlyWiki from any web
accessible device in the house.

1. Back up the contents of the TiddlyWiki daily - because you can never have
too many safety nets.

I use the same scripts on my (macOS) laptop also, to run a local copy
when I am disconnected from the NAS.

# Installation

This assumes you have a minimal comfort level working on a command line.

1. On NAS, install node.js: 

   I used the Synology GUI to install the **Node.js** package. These scripts also
   rely on a few of the command-line utilities provided by the Synology
   Community maintained **SynoCli Network Tools** package (`screen`, `rsync`)
   and the Synology maintained **Diagnosis Tool** package (`ncat`, `pgrep`,
   `pkill`). You will need to install those or the equivalent tools as
   well. The latter **Diagnosis Tool** package also requires a command line
   `sudo synogear install`.

1. Change the NAS's DNS server and poke a hole in its firewall for 192.168.1.x
   (or whatever IP address your local network uses) access to the port
   TiddlyWiki will run on. The default PORT these use is 9998.

1. Using an ssh login to the NAS I then `cd /path/to/where/this/will/live` -
   call this the **app root** directory.
 
1. `git clone [your TiddlyWiki repo] subdirectory_name_to_hold_tiddlywiki` to
   get a local clone of your TiddlyWiki repo in a subdirectory of the current
   one.
   
1. `git submodule add https://github.com/JonathanDoughty/tiddlywiki-nas.git` to add this repo as a
   submodule. You'll end up with a `tiddlywiki-nas` directory with the
   submodule contents.

1. `npm install tiddlywiki` - I do this npm install locally, not globally, so that
   tiddlywiki will be run via the path `./node_modules/.bin/tiddlywiki`
   
   Note that as of tiddlywiki 5.2.7 this may result in a warning: "npm
   WARN tar TAR_ENTRY_ERROR ENAMETOOLONG: name too long ..."

   I also install TiddlyWiki as a *local* npm package so that I can install
   and test pre-release versions of TiddlyWiki without impacting 'production'
   (and because I resist any tool that suggest I need to `sudo ...` almost anything.
   
1. `ln -s tiddlywiki-nas/daily.sh tiddlywiki-nas/start.sh . ` - make symbolic
   links in your **app root** directory to the script that will run daily and
   that can re-start your TiddlyWiki when the NAS reboots. If you want to be
   able to stop TiddlyWiki from a command line or as the NAS shuts down also make a symbolic link `ln
   -s tiddlywiki-nas/start.sh ./stop.sh` (same as start script, it stops if
   the script name includes 'stop'.

1. Copy the submodule's `environment.default` file into your **app root** directory
   using the special, hidden filename `.env`:
   `cp tiddlywiki-nas/environment.default ./.env`, and **edit** that
   `.env` copy to adjust environment variables for, e.g., the HOST and
   domain name you use on your internal network, the PORT number node.js 
   will be access, etc., per the comments in that file.

   Note that there is a PRE_RELEASE variable that can be used to check
   TiddlyWiki pre-release versions. **Warning:** the pre-release version of
   TiddlyWiki will be use the contents in $NOTES_DIR and other wikis defined
   by its tiddlywiki.info - make sure any content that could be corrupted by
   pre-release software has been backed up.
   
1. Arrange for a nightly git commit and backup. Given the setup above, I used
   Synology's Task Scheduler to create a Scheduled Task to
   run `bash /path/to/[app root directory]/daily.sh`

   I configure the Task Schedule job to only generate an
   email on errors. The scripts are setup to force an email if the
   VERBOSE level is 1 or greater. Set the VERBOSE level in the .env file as a means to
   debug your setup.

1. Arrange for the TiddlyWiki on Node.js to run whenever the NAS reboots. My
   Task Scheduler Triggered Task to accomplish this runs `bash
   /path/to/[app root directory]/start.sh` on Bootup.

1. Arrange for the TiddlyWiki on Node.js to shutdown as the NAS begins its 
   shutdown sequence using the stop.sh link created above. As stop simply
   kills the process running node.js there isn't much to be gained by adding this currently. My
   Task Scheduler Triggered Task to accomplish this runs `bash
   /path/to/[app root directory]/stop.sh` on Shutdown.

You can test these tasks by selecting them in Task Scheduler and then Run and then 'Action ... View Result',
increasing the VERBOSE value in your .env file for additional detail.

Once it is running then access TiddlyWiki on your NAS from a browser on a desktop, phone, or
tablet in your local network, 
e.g., something like `http://nas.local:9998/'`
