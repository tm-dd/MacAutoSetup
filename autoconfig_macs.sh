#!/bin/bash
#
# Copyright (c) 2021 tm-dd (Thomas Mueller)
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


### settings and check ###

# don't allow running for user root (makes the Time Machine configuration easier)
if [ $USER == "root" ]
then
	echo "Do NOT start this script as user root !!!"
	exit -1
fi

# default vaulues
DefaultSoftwareRepoURL='https://munki.example.org/repo/'
DefaultClientIdentifier='int-mac-en'
DefaultMunkiLogin='initial'
DefaultMunkiPassword='VerySuperSecurePassword'
DefaultAdminUser=`whoami`

# hide the current account (can be a problem on Macs with Apple CPU, because this login was sometimes not visible, after rebooting with FileVault 2)
hideCurrentAccount="no"

### read settings ####

# get serial number
serialNumber=$(/usr/sbin/ioreg -l | /usr/bin/grep "IOPlatformSerialNumber" | /usr/bin/awk -F '"' '{ print $4 }')

# script directory
scriptDir="`dirname $0`"

# fix if newline is missing on the last line
echo >> "${scriptDir}/config.csv"

# read settings from csv file
OIFS="${IFS}"
IFS=$'\n'
for i in $(grep '","'${serialNumber}'","' "${scriptDir}/config.csv" | tail -n 1)
do

	i=`echo $i | sed 's/,,/,"",/g' | sed 's/,,/,"",/g' | sed 's/,$/,""/'`   # fix '"Val1",,,"Val4",,' to '"Val1","","","Val4","",""'
	i=`echo $i | sed 's/^"//g' | sed 's/"$//g'`                             # remove first and last character '"'    

	macName=`echo $i | awk -F '","' '{ print $1 }'`                         # the Name of the Mac
	serialNumber=`echo $i | awk -F '","' '{ print $2 }'`                    # the serial number of the Mac
	tmLogin=`echo $i | awk -F '","' '{ print $3 }'`                         # the login for Time Machine
	tmPassword=`echo $i | awk -F '","' '{ print $4 }'`                      # the password for Time Machine
	fileVault2Key=`echo $i | awk -F '","' '{ print $5 }'`                   # the FileVault 2 key
	MunkiCSVClientIdentifier=`echo $i | awk -F '","' '{ print $6 }'`        # the ClientIdentifier for Munki
	MunkiCSVSoftwareRepoURL=`echo $i | awk -F '","' '{ print $7 }'`         # the SoftwareRepoURL for Munki
	MunkiCSVLogin=`echo $i | awk -F '","' '{ print $8 }'`                   # the login for later MunkiAuthorization
	MunkiCSVPassword=`echo $i | awk -F '","' '{ print $9 }'`                # the password for later MunkiAuthorization
	MunkiCSVSelfServeManifest=`echo $i | awk -F '","' '{ print $10 }'`      # use this file as ServeManifest for configured software installations

done
IFS="${OIFS}"

todayDate=`date '+%Y-%m-%d'`
macNameWithoutSpace=`echo "${macName}" | sed 's/ //g'`

# output settings
echo
echo "current settings:"
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
if [ "${fileVault2Key}" == "-" ]; then echo "   SKIP FileVault 2 configuration, later."; fi
echo

# let the user check this settings
echo "Press ENTER to continue ..."
read


### setup mac configurations ###

echo "Configure some default settings ..."; echo

# enable Firewall (commands from https://superuser.com/questions/472038/how-can-i-enable-the-firewall-via-command-line-on-mac-os-x)
(set -x; sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on)
echo

# hide the current account (can be a problem on Macs with Apple CPU, because this login was sometimes not visible, after rebooting with FileVault 2)
if [ "${hideCurrentAccount}" == "yes" ]
then
	(set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow.plist HiddenUsersList -array-add `/usr/bin/whoami`)
else
	(set -x; sudo defaults delete /Library/Preferences/com.apple.loginwindow.plist HiddenUsersList)
fi
echo

# delete preinstalled Apps
(set -x; sudo rm -rf /Applications/GarageBand.app /Applications/iMovie.app /Applications/Keynote.app /Applications/Numbers.app /Applications/Pages.app)

# delete local Time Machine snapshots
(set -x; tmutil deletelocalsnapshots /)

## power management (-a ... all power modes, -b ... battery mode, -c ... cable mode)
# power cable mode: after 30 minute turn off the display
(set -x; sudo pmset -c displaysleep 60)
# battery mode: after 30 minute turn off the display
(set -x; sudo pmset -b displaysleep 30)
# power cable mode: allow computer sleep after 60 minutes
(set -x; sudo pmset -c sleep 60)
# battery mode: allow computer sleep after 60 minutes
(set -x; sudo pmset -b sleep 30)
# allow disk to sleep
(set -x; sudo pmset -a disksleep 10)
# allow powernap for backups, during sleep
(set -x; sudo pmset -a powernap 1)
# do not turn on, if person open the lid 
(set -x; sudo pmset -a lidwake 0)
# do not turn on, if power was lost 
(set -x; sudo pmset -a acwake 0)
# allow wakeonlan
(set -x; sudo pmset -a womp 1)
# show setting
(set -x; sudo pmset -g)

# rename Mac
(set -x; sudo scutil --set ComputerName "Mac")
(set -x; sudo scutil --set LocalHostName "Mac")
(set -x; sudo scutil --set HostName "Mac")

# set and read update setting (check for updates and install system data files and security updates)
(set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled YES)
(set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload NO)
(set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates NO)
(set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall YES)
(set -x; sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall YES)

# setting for the login windows
(set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow PowerOffDisabled 0)
(set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint 3)
(set -x; sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu 1)

# delete temporary files
(set -x; sudo rm -rfv /Users/Shared/Relocated\ Items /Users/*/Desktop/*.nosync)

# rename Mac
( set -x; sudo scutil --set ComputerName "${macName}" )
( set -x; sudo scutil --set LocalHostName "${macNameWithoutSpace}" )
( set -x; sudo scutil --set HostName "${macName}" )

sleep 2

# setup FileVault 2 
if [ "${fileVault2Key}" == "-" ]
then
	echo "SKIP FileVault 2 configuration and create a random md5sum for the time machine encryption."
	fileVault2Key=`echo $(ps awux ; dd if=/dev/random bs=1024 count=1 2> /dev/null) | md5 | awk '{ print "" $1 }'`
else
	echo "Enter password to try to activate FileVault 2."
	fileVault2Key=`sudo fdesetup enable -user ${DefaultAdminUser} | awk -F "'" '{ print $2 }'` && echo "The new FileVault 2 key is: $fileVault2Key"
fi
sleep 2

# setup Time Machine
(set -x; open afp://${tmLogin}:${tmPassword}@tm2/TimeMachine/)
echo
echo "Please configure Time Machine manually, now."
echo "Use the password ${tmPassword} and the encryption password $fileVault2Key for this step and press enter to continue."
(set -x; open /System/Applications/System\ Preferences.app)
read


### setup munki ###

echo "Setup Munki ..."; echo

# install munki
(set -x; munkiPackage=`find ${scriptDir}/files | grep 'munkitools' | grep '.pkg'`; sudo xattr -rc ${munkiPackage}; sudo installer -target / -pkg ${munkiPackage})

echo; sleep 3

# setup Munki ClientIdentifier
if [ "${MunkiCSVClientIdentifier}" = "" ]; 
then MunkiClientIdentifier="${DefaultClientIdentifier}"
else MunkiClientIdentifier="${MunkiCSVClientIdentifier}"
fi
(set -x; sudo defaults write /Library/Preferences/ManagedInstalls ClientIdentifier "${MunkiClientIdentifier}")

# setup the Munki SoftwareRepoURL
if [ "${MunkiCSVSoftwareRepoURL}" = "" ]
then MunkiSoftwareRepoURL="${DefaultSoftwareRepoURL}"
else MunkiSoftwareRepoURL="${MunkiCSVSoftwareRepoURL}"
fi
(set -x; sudo defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL "${MunkiSoftwareRepoURL}")

# setup the login and password for protected packages in the Munki repository
if [ "${MunkiCSVLogin}" != "" ]; then MunkiLogin="${MunkiCSVLogin}"; else MunkiLogin="${DefaultMunkiLogin}"; fi
if [ "${MunkiCSVPassword}" != "" ]; then MunkiPassword="${MunkiCSVPassword}"; else MunkiPassword="${DefaultMunkiPassword}"; fi
MunkiAuthorization=`python -c 'import base64; print "%s" % base64.b64encode("'${MunkiLogin}':'${MunkiPassword}'")'`
(set -x; sudo defaults write /Library/Preferences/ManagedInstalls.plist AdditionalHttpHeaders -array "Authorization: Basic ${MunkiAuthorization}")

# output the current settings
(set -x; sudo defaults read /Library/Preferences/ManagedInstalls)

# if files exists, setup the configured SelfServeManifest
MunkiCSVSelfServeManifestFilePath="${scriptDir}/files/SelfServeManifests/${MunkiCSVSelfServeManifest}"
if [ -f "${MunkiCSVSelfServeManifestFilePath}.default" ]; then (set -x; MunkiCSVSelfServeManifestFilePath="${MunkiCSVSelfServeManifestFilePath}.default"); fi
if [ -f "${MunkiCSVSelfServeManifestFilePath}" ]
then

	(set -x; sudo /bin/mv "/Library/Managed Installs/manifests/SelfServeManifest" "/Library/Managed Installs/manifests/SelfServeManifest.old" 2>&1)
	(set -x; sudo /bin/cp -a "${MunkiCSVSelfServeManifestFilePath}" "/Library/Managed Installs/manifests/SelfServeManifest")
	(set -x; sudo /usr/bin/xattr -r -d com.apple.quarantine "/Library/Managed Installs/manifests/SelfServeManifest")
	(set -x; sudo /usr/bin/xattr -c -r "/Library/Managed Installs/manifests/SelfServeManifest")
	(set -x; sudo /bin/chmod 644 "/Library/Managed Installs/manifests/SelfServeManifest")
	(set -x; sudo /usr/sbin/chown root "/Library/Managed Installs/manifests/SelfServeManifest")
	(set -x; sudo /usr/bin/chgrp admin "/Library/Managed Installs/manifests/SelfServeManifest")
	(set -x; sudo /bin/cat "/Library/Managed Installs/manifests/SelfServeManifest")
else
	if [ "${MunkiCSVSelfServeManifest}" != "" ]
	then
		echo "ERROR: The following file was not found."
		(set -x; ls "${MunkiCSVSelfServeManifestFilePath}")
	fi
fi

echo


### write files ###

echo "Write files ..."; echo

# create directory for "new mac files"
dirOfNewMacFiles="${scriptDir}/${macName}"
(set -x; mkdir "${dirOfNewMacFiles}")

# save ifconfig
(set -x; ifconfig > "${dirOfNewMacFiles}/ifconfig.txt")

# save system profile
(set -x; system_profiler -xml | bzip2 -9 > "${dirOfNewMacFiles}/system_profile.spx.bz2")

# save values
echo "\"${macName}\",\"${serialNumber}\",\"${tmLogin}\",\"${tmPassword}\",\"${fileVault2Key}\",\"${MunkiClientIdentifier}\",\"${MunkiSoftwareRepoURL}\",\"${MunkiLogin}\",\"${MunkiPassword}\",\"${MunkiCSVSelfServeManifest}\",\"${todayDate}\"" >> "${scriptDir}/config.csv"
echo "Serial Number: ${serialNumber}" > "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"
echo "FileVault 2 Key: ${fileVault2Key}" >> "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"
echo "As of: ${todayDate}" >> "${dirOfNewMacFiles}/FileVault2_${macNameWithoutSpace}.txt"

echo


### install software and possible updates ###

echo "Install software ..."; echo

# copy admin_files
(set -x; cp -a "${scriptDir}/files/admin_files" "/Users/${DefaultAdminUser}/Desktop/admin_files")
(set -x; sudo /usr/bin/xattr -c -r "/Users/${DefaultAdminUser}/Desktop/admin_files")
(set -x; sudo /usr/bin/xattr -r -d com.apple.quarantine "/Users/${DefaultAdminUser}/Desktop/admin_files")
(set -x; sudo /usr/sbin/chown ${DefaultAdminUser} "/Users/${DefaultAdminUser}/Desktop/admin_files")
(set -x; sudo /usr/bin/chgrp staff "/Users/${DefaultAdminUser}/Desktop/admin_files")
(set -x; sudo /bin/chmod -R 755 "/Users/${DefaultAdminUser}/Desktop/admin_files")
echo

# script to setup the default user
(set -x; cp -a "${scriptDir}/files/setup_current_user_as_default_user_for_apps.sh" "/tmp/setup_current_user_as_default_user_for_apps.sh")
(set -x; sudo /usr/bin/xattr -c "/tmp/setup_current_user_as_default_user_for_apps.sh")
(set -x; sudo /bin/bash "/tmp/setup_current_user_as_default_user_for_apps.sh")
echo

# nessesary on some ARM based Macs for some packages (also during the installation)
(set -x; sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license)
echo

# run the update script
exec sudo /bin/bash "/Users/${DefaultAdminUser}/Desktop/admin_files/start_updates_mac.sh" 

exit 0
