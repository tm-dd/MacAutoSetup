#!/bin/bash
#
# Copyright (c) 2025 tm-dd (Thomas Mueller)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#


####################
### first checks ###
####################

# don't allow running for user root (makes the Time Machine configuration easier)
if [ $USER == "root" ]; then echo "Do NOT start this script as user root !!!"; exit -1; fi

# script directory
scriptDir="`dirname $0`"

# check csv file #
if [ ! -f "${scriptDir}/config.csv" ]; then echo 'ERROR: Could not read CSV file "'"${scriptDir}/config.csv"'".'; exit -1; fi


################
### settings ###
################

# the time zone for the Mac
newTimeZone='Europe/Berlin'

# hide the current account (can be a problem on Macs with Apple CPU, because this login was sometimes not visible, after rebooting with FileVault 2)
hideCurrentAccount="no"

# delete this
deleteThisApps="/Applications/GarageBand.app /Applications/iMovie.app /Applications/Keynote.app /Applications/Numbers.app /Applications/Pages.app"
deleteTemporaryFiles="/Users/Shared/Relocated\ Items /Users/*/Desktop/*.nosync"

# the current admin account
currentAdminUserNameOfThisMac=`whoami`

# get serial number
serialNumberSystem=$(/usr/sbin/ioreg -l | /usr/bin/grep "IOPlatformSerialNumber" | /usr/bin/awk -F '"' '{ print $4 }')

# read settings from csv file
OIFS="${IFS}"
IFS=$'\n'
for i in $(grep '","'${serialNumberSystem}'","' "${scriptDir}/config.csv" | tail -n 1)
do

	i=`echo $i | sed 's/,,/,"",/g' | sed 's/,,/,"",/g' | sed 's/,$/,""/'`   # fix '"Val1",,,"Val4",,' to '"Val1","","","Val4","",""'
	i=`echo $i | sed 's/^"//g' | sed 's/"$//g'`                             # remove first and last character '"'    

	macName=`echo $i | awk -F '","' '{ print $1 }'`                         # the Name of the Mac
	serialNumber=`echo $i | awk -F '","' '{ print $2 }'`                    # the serial number of the Mac
	timeMachineServer=`echo $i | awk -F '","' '{ print $3 }'`               # the name of the Time Machine Server (with Samba shares)
	tmLogin=`echo $i | awk -F '","' '{ print $4 }'`                         # the login for Time Machine
	tmPassword=`echo $i | awk -F '","' '{ print $5 }'`                      # the password for Time Machine
	fileVault2Key=`echo $i | awk -F '","' '{ print $6 }'`                   # the FileVault 2 key
	MunkiCSVClientIdentifier=`echo $i | awk -F '","' '{ print $7 }'`        # the ClientIdentifier for Munki
	MunkiCSVSoftwareRepoURL=`echo $i | awk -F '","' '{ print $8 }'`         # the SoftwareRepoURL for Munki
	MunkiCSVLogin=`echo $i | awk -F '","' '{ print $9 }'`                   # the login for later MunkiAuthorization
	MunkiCSVPassword=`echo $i | awk -F '","' '{ print $10 }'`               # the password for later MunkiAuthorization
	MunkiCSVSelfServeManifest=`echo $i | awk -F '","' '{ print $11 }'`      # use this file as ServeManifest for configured software installations

done
IFS="${OIFS}"

# Time Machine share
# example 1: timeMachineShare="afp://${tmLogin}:${tmPassword}@${timeMachineServer}/TimeMachine/"
# example 2: timeMachineShare="smb://${tmLogin}:${tmPassword}@${timeMachineServer}/${tmLogin}"
timeMachineShare="smb://${tmLogin}:${tmPassword}@${timeMachineServer}/${tmLogin}"

# output settings
echo
echo "current settings from the CSV file:"
echo
echo "   name of this mac: $macName"
echo "   serial number: $serialNumber"
echo "   Time Machine login: $tmLogin"
echo "   Time Machine password: $tmPassword"
echo "   Munki ClientIdentifier: $MunkiCSVClientIdentifier"
echo "   Munki SoftwareRepoURL: $MunkiCSVSoftwareRepoURL"
echo "   Munki authorization login: $MunkiCSVLogin"
echo "   Munki authorization password: $MunkiCSVPassword"
echo "   Munki SelfServeManifest file: $MunkiCSVSelfServeManifest"
echo "   delete this: $deleteTemporaryFiles $deleteThisApps"

if [ "${MunkiCSVSoftwareRepoURL}" == "-" ] || [ "${MunkiCSVClientIdentifier}" == "-" ]; then echo -e "\n   SKIP MUNKI configuration, later.\n"; fi
if [ "${tmLogin}" == "-" ]; then echo -e "\n   SKIP Time Machine configuration, later.\n"; else echo -e "   Time Machine Share: $timeMachineShare\n"; fi
if [ "${fileVault2Key}" == "-" ]; then echo -e "\n   SKIP FileVault 2 configuration, later.\n"; fi

# let the user check this settings
echo "Press ENTER to continue ..."
read

# the date (to write in files)
todayDate=`date '+%Y-%m-%d'`


#####################
### second checks ###
#####################

# serial number was not found
if [ -z "${serialNumber}" ]; then echo "ERROR: Could not find the serial number '"${serialNumberSystem}"' in the CSV file."; exit -1; fi

# no correct time machine settings
if [ -z "${tmLogin}" ] || [ -z "${tmPassword}" ]; then echo "Information: Missing some settings for Time Machine."; fi

# no correct Munki settings
if [ "${MunkiCSVSoftwareRepoURL}" != "-" ] && [ "${MunkiCSVClientIdentifier}" != "-" ] 
then
	if [ -z "${MunkiCSVClientIdentifier}" ] || [ -z "${MunkiCSVSoftwareRepoURL}" ] || [ -z "${MunkiCSVLogin}" ] || [ -z "${MunkiCSVPassword}" ] || [ -z "${MunkiCSVSelfServeManifest}" ]; then echo "ERROR: Missing at least one of the upper settings for MUNKI."; exit -1; fi
fi


###################################
### mac configurations - part 1 ###
###################################

echo "Configure some default settings ..."; echo

# let the user change the access for Terminal and Munki
echo "Please add 'Terminal' to 'System Setting' -> 'Privacy & Security' -> 'Full Disk Access'. Then press Enter."
open /Applications/Utilities
open /System/Applications/System\ Settings.app
read

# rename Mac
macNameWithoutSpace=`echo "${macName}" | sed 's/ //g'`
( set -x; sudo scutil --set ComputerName "${macName}" )
( set -x; sudo scutil --set LocalHostName "${macNameWithoutSpace}" )
( set -x; sudo scutil --set HostName "${macName}" )

# enable Firewall (commands from https://superuser.com/questions/472038/how-can-i-enable-the-firewall-via-command-line-on-mac-os-x)
( set -x; sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on )
echo

# hide the current account (can be a problem on Macs with Apple CPU, because this login was sometimes not visible, after rebooting with FileVault 2)
if [ "${hideCurrentAccount}" == "yes" ]
then
	( set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow.plist HiddenUsersList -array-add `/usr/bin/whoami` )
else
	( set -x; sudo defaults delete /Library/Preferences/com.apple.loginwindow.plist HiddenUsersList )
fi
echo

# delete preinstalled Apps
( set -x; sudo rm -rf $deleteThisApps )

# delete temporary files
( set -x; sudo rm -rfv $deleteTemporaryFiles )

# delete local Time Machine snapshots
( set -x; tmutil deletelocalsnapshots / )

## power management (-a ... all power modes, -b ... battery mode, -c ... cable mode)
# power cable mode: after 30 minute turn off the display
( set -x; sudo pmset -c displaysleep 60 )
# battery mode: after 30 minute turn off the display
( set -x; sudo pmset -b displaysleep 30 )
# power cable mode: allow computer sleep after 60 minutes
( set -x; sudo pmset -c sleep 60 )
# battery mode: allow computer sleep after 60 minutes
( set -x; sudo pmset -b sleep 30 )
# allow disk to sleep
( set -x; sudo pmset -a disksleep 10 )
# allow powernap for backups, during sleep
( set -x; sudo pmset -a powernap 1 )
# do not turn on, if person open the lid 
( set -x; sudo pmset -a lidwake 0 )
# do not turn on, if power was lost 
( set -x; sudo pmset -a acwake 0 )
# allow wakeonlan
( set -x; sudo pmset -a womp 1 )
# show setting
( set -x; sudo pmset -g )

# set the time zone
if [ -n "${newTimeZone}" ]; then ( set -x; sudo systemsetup -settimezone "$newTimeZone" ); fi

# enable location services (command was found on https://www.hexnode.com/mobile-device-management/help/script-to-enable-disable-location-services-on-macos-devices/)
( set -x; sudo /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -bool true; /bin/launchctl kickstart -k system/com.apple.locationd )

# enable ALL update setting 
( set -x; sudo defaults write /Library/Preferences/com.apple.commerce.plist AutoUpdate -bool TRUE )
( set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool TRUE )
( set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool TRUE )
( set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool TRUE )
( set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool TRUE )
( set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool TRUE )

# setting for the login windows
( set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow PowerOffDisabled 0 )
( set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint 3 )
( set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu 1 )

sleep 2


###################
### setup munki ###
###################

if [ "${MunkiCSVSoftwareRepoURL}" == "-" ] || [ "${MunkiCSVClientIdentifier}" == "-" ]
then 
	echo -e "\n   SKIP MUNKI installation and configuration.\n"

else
	
	echo "Setup Munki software and configuration ..."; echo
	
	# install munki
	( munkiPackage=`find ${scriptDir}/files | grep 'munkitools' | grep '.pkg'`; sudo xattr -rc ${munkiPackage}; set -x; sudo installer -target / -pkg ${munkiPackage} )
	
	echo

	# let the user change the access for Munki
	echo "Please add 'managedsoftwareupdate' to 'System Setting' -> 'Privacy & Security' -> 'Full Disk Access' and 'App Management'. Then press Enter."
	open /usr/local/munki
	open /System/Applications/System\ Settings.app
	read
	
	# setup Munki ClientIdentifier
	( set -x; sudo defaults write /Library/Preferences/ManagedInstalls ClientIdentifier "${MunkiCSVClientIdentifier}" )
	
	# setup the Munki SoftwareRepoURL
	( set -x; sudo defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL "${MunkiCSVSoftwareRepoURL}" )
	
	# setup the login and password for protected packages in the Munki repository
	MunkiAuthorization=`echo -n "${MunkiCSVLogin}:${MunkiCSVPassword}" | base64`
	( set -x; sudo defaults write /Library/Preferences/ManagedInstalls.plist AdditionalHttpHeaders -array "Authorization: Basic ${MunkiAuthorization}" )
	
	# output the current settings
	( set -x; sudo defaults read /Library/Preferences/ManagedInstalls )
	
	# if files exists, setup the configured SelfServeManifest
	MunkiCSVSelfServeManifestFilePath="${scriptDir}/files/SelfServeManifests/${MunkiCSVSelfServeManifest}"
	if [ -f "${MunkiCSVSelfServeManifestFilePath}.default" ]; then ( set -x; MunkiCSVSelfServeManifestFilePath="${MunkiCSVSelfServeManifestFilePath}.default" ); fi
	if [ -f "${MunkiCSVSelfServeManifestFilePath}" ]
	then
	
		( set -x; sudo /bin/mv "/Library/Managed Installs/manifests/SelfServeManifest" "/Library/Managed Installs/manifests/SelfServeManifest.old" 2>&1 )
		( set -x; sudo /bin/cp -a "${MunkiCSVSelfServeManifestFilePath}" "/Library/Managed Installs/manifests/SelfServeManifest" )
		( set -x; sudo /usr/bin/xattr -r -d com.apple.quarantine "/Library/Managed Installs/manifests/SelfServeManifest" )
		( set -x; sudo /usr/bin/xattr -c -r "/Library/Managed Installs/manifests/SelfServeManifest" )
		( set -x; sudo /bin/chmod 644 "/Library/Managed Installs/manifests/SelfServeManifest" )
		( set -x; sudo /usr/sbin/chown root "/Library/Managed Installs/manifests/SelfServeManifest" )
		( set -x; sudo /usr/bin/chgrp admin "/Library/Managed Installs/manifests/SelfServeManifest" )
		( set -x; sudo /bin/cat "/Library/Managed Installs/manifests/SelfServeManifest" )
	fi
	
	echo
fi


###################################
### mac configurations - part 2 ###
###################################

# setup FileVault 2 
if [ "${fileVault2Key}" == "-" ]
then
	echo "SKIP FileVault 2 configuration and create a random md5sum for the time machine encryption."
	fileVault2Key=`echo $(ps awux ; dd if=/dev/random bs=1024 count=1 2> /dev/null) | md5 | awk '{ print "" $1 }'`
else
	echo "Enter password to try to activate FileVault 2."
	fileVault2Key=`sudo fdesetup enable -user ${currentAdminUserNameOfThisMac} | awk -F "'" '{ print $2 }'` && echo "The new FileVault 2 key is: $fileVault2Key"
fi

sleep 2

# setup Time Machine
if [ "${tmLogin}" == "-" ]
then
	echo "SKIP Time Machine configuration."
else
	( set -x; open $timeMachineShare )
	echo
	echo "Please configure Time Machine manually, now OR SKIP this step."
	echo "Use the password ${tmPassword} and the encryption password $fileVault2Key for this step and PRESS ENTER TO CONTINUE."
	( set -x; open /System/Applications/System\ Preferences.app || open /System/Applications/System\ Settings.app )
	read
	
	# set max Time Maschine storage size (should work only on some system versions on Macs)
	if [ "`sw_vers -productVersion | awk -F '.' '{ print $1 }'`" -eq 10 ] && [ "`sw_vers -productVersion | awk -F '.' '{ print $2 }'`" -ge 8 ] && [ "`sw_vers -productVersion | awk -F '.' '{ print $2 }'`" -le 12 ]
	then
		# Time Machine storage size
		diskSizeInGigaByte=`df -g / | grep '^/dev/' | awk '{ print $2 }'`
		maxTimeMachineBackupSizeInMegabyte=`echo $(($diskSizeInGigaByte*17000/10)) | awk -F '.' '{ print $1 }'`
	
		# echo "Give the Terminal 'Full Disk Access' to try to setup the max size of $maxTimeMachineBackupSizeInMegabyte MB for Time Machine Backups and PRESS ENTER."; read
		echo -e "Try to set the max size of Time Machine to $maxTimeMachineBackupSizeInMegabyte MB .\n"
		( set -x; sudo defaults write /Library/Preferences/com.apple.TimeMachine.plist MaxSize -integer $maxTimeMachineBackupSizeInMegabyte )
	fi
fi


###########################
### create client files ###
###########################

echo "Write files ..."; echo

# create directory for "new mac files"
dirOfNewMacFiles="${scriptDir}/${macName}"
( set -x; mkdir "${dirOfNewMacFiles}" )

# save ifconfig
( set -x; ifconfig > "${dirOfNewMacFiles}/ifconfig.txt" )

# save system profile
( set -x; system_profiler -xml | bzip2 -9 > "${dirOfNewMacFiles}/system_profile.spx.bz2" )

# save values
echo '' >> "${scriptDir}/config.csv"  # if the last line have not newline 
echo "\"${macName}\",\"${serialNumber}\",\"${timeMachineServer}\",\"${tmLogin}\",\"${tmPassword}\",\"${fileVault2Key}\",\"${MunkiCSVClientIdentifier}\",\"${MunkiCSVSoftwareRepoURL}\",\"${MunkiCSVLogin}\",\"${MunkiCSVPassword}\",\"${MunkiCSVSelfServeManifest}\",\"${todayDate}\"" >> "${scriptDir}/config.csv"
echo "Serial number: ${serialNumber}" > "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"
if [ "${tmLogin}" == "-" ] && [ "${fileVault2Key}" == "-" ]
then
	echo "FileVault 2 / TM encryption key NOT CONFIGURED." >> "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"
else
	echo "FileVault 2 / TM encryption key: ${fileVault2Key}" >> "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"
fi
echo "Time Machine password (in some faulty cases by the system automatically also used for the TM encryption): ${tmPassword}" >> "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"
echo "As of: ${todayDate}" >> "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"

echo


####################################
### install software and updates ###
####################################

echo "Install software ..."; echo

# set link to admin_scripts
( set -x; sudo rm -rf "/Users/${currentAdminUserNameOfThisMac}/Desktop/admin_files" )
( set -x; sudo ln -s /usr/local/admin_scripts "/Users/${currentAdminUserNameOfThisMac}/Desktop/admin_scripts" )
echo

# script to setup the default user
( set -x; cp -a "${scriptDir}/files/setup_current_user_as_default_user_for_apps.sh" "/tmp/setup_current_user_as_default_user_for_apps.sh" )
( set -x; sudo /usr/bin/xattr -c "/tmp/setup_current_user_as_default_user_for_apps.sh" )
( set -x; sudo /bin/bash "/tmp/setup_current_user_as_default_user_for_apps.sh" )
echo

# nessesary on some ARM based Macs for some packages (also during the installation)
( set -x; sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license )
echo

# run the update script
cp /Volumes/USB/files/admin_files/start_updates_mac.sh /tmp/
exec sudo /bin/bash "/tmp/start_updates_mac.sh" 

exit 0
