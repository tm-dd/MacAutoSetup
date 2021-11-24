# MacAutoSetup

Some scripts to configure an install an new Mac.

## What will the scripts do on the Mac ?

- read settings for the Mac from the config file, based on his serial number
- enable the firewall
- hide or unhide the account
- remove preinstalled Apps (Garangeband, iMovie, Keynote, Numbers and Pages)
- delele Time Machine snapshopts
- change some power management settings
- setup the computer name
- set some update settings
- remove relocated files
- enable FileVault 2
- help to setup Time Machine
- install and configure the Munki client
- write the FileVault 2 recovery key to a text file
- backup some system information
- try to install Rosetta 2
- start software installation with the Munki client
- start macOS updates

## How to use ?

- install a fresh macOS.
- create a first account or migrate a fresh user account from a Time Machine backup
- copy all files from here to an USB pen drive
- copy the Munki client software package to the USB pen drive
- change the config.csv (and check the syntax of the original config.csv file)
- run autoconfig_mac.sh ...

