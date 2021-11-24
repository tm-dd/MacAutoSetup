#!/bin/bash
#
# This Script change the owner of Software in "/Applications". It ask for the old username and change all files of this user (in this directory) to a new identity. 
# This is useful for software which have a build in update process and the software was installed not for the user which using the software normally.
#
# Copyright (c) 2020 tm-dd (Thomas Mueller)
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

# check of root rights
if [ $USER != "root" ]
then
	echo "THIS SCRIPT MUST RUN AS USER root !!!"
        exec sudo $0
fi

# a temporary scipt to change access rights
TMPFILE="/tmp/change_owner_of_software.sh"

# a file to keep the settings
USERANDGROUPFILE='/usr/local/default_user_and_group.cfg'

echo 'This script CHANGE THE OWNER of all SOFTWARE in "/Applications" from a specified old login to a new LOGIN.'

# define the old user name
echo -n "What is the LOGIN of the OLD OWNER of the software (e.g. admin): "
read OLDUSER
echo


# define the new user name for the software
echo -n "Please type the login and/or group name which should be the NEW OWNER (e.g. 'mylogin' or 'mylogin:staff'): "
read NEWUSERANDGROUP
echo

find /Applications -user $OLDUSER -maxdepth 1 -exec echo sudo chown -R $NEWUSERANDGROUP \"{}\" \; > $TMPFILE
echo sudo chown -R $NEWUSERANDGROUP /anaconda* >> $TMPFILE

cat $TMPFILE
echo

# show the commands to run
echo -n "Should I run the upper commands (file: $TMPFILE) to change the login and group ? (y/n) : "
read USERINPUT
echo

# Should the commands realy run, now ?
if [ $USERINPUT != y ]
then
	rm $TMPFILE
	echo "EXIT. NOTHING CHANGED NOW."
	exit -1
fi

# change the ownership
echo
echo "Please wait ..."
bash $TMPFILE
rm $TMPFILE

# write the new ownership (settings) in the file $USERANDGROUPFILE
echo "CONFIGURE: $USERANDGROUPFILE"
echo '# this value define the default user and group for some new apps' > $USERANDGROUPFILE
echo 'USERANDGROUP="'$NEWUSERANDGROUP'"' >> $USERANDGROUPFILE
echo
echo "FILE $USERANDGROUPFILE IS CHANGED TO:"
echo
cat $USERANDGROUPFILE
echo

echo "END OF SCRIPT. EXIT NOW."

exit 0

