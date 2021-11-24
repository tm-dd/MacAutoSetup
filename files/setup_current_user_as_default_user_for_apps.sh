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

echo "SEARCHING for the common user account of the system (if possible) and define it as owner for new apps ..."

# if only one user is logged in use this account 
NUMCONSOLEUSERS=`who | grep console | awk -F ' ' '{ print $1 }' | wc -l | awk -F ' ' '{ print $1 }'`
if [ "$NUMCONSOLEUSERS" -eq "1" ]
then
    LISTOFUSERS="`who | grep console | awk -F ' ' '{ print $1 }'`"
fi

# if the Munki software running on the system, who is using it
LISTOFUSERS="${LISTOFUSERS} `ps awux | grep "/Applications/Managed Software Center.app" | grep -v grep | awk -F ' ' '{ print $1 }'`"

# for all existing users
HOMES=''
for systemuser in `dscl . -list /Users | grep -v "^_"`
do
    HOME=`dscl . -read /Users/${systemuser} NFSHomeDirectory | awk '{ print $2 }' | grep -v '/etc/\|/var/\|/opt/local'`
    if [ -n "${HOME}" ]; then HOMES="${HOMES} ${HOME}"; fi
done    

# find the last user who work on the Mac 
LISTOFUSERS="${LISTOFUSERS} `ls -1td ${HOMES} | awk -F '/' '{ print $NF }' | tr '\n' ' '`"

echo "FOUND the following user accounts: ${LISTOFUSERS}"

# find the possible best account, who is really used on the mac
for systemuser in `echo ${LISTOFUSERS}`
do
    if [ "${systemuser}" != '' ] && [ "${systemuser}" != 'root' ] && [ "${systemuser}" != 'macports' ] && [ "${systemuser}" != 'daemon' ] && [ "${systemuser}" != 'nobody' ]
    then
        CURRENTUSER="${systemuser}"
        break
    fi
done

# do not use this user, if there is an existing configuration
if [ "$CURRENTUSER" == 'ignorethisuser' ] && [ "`grep USERANDGROUP /usr/local/default_user_and_group.cfg`" != '' ]; then exit 0; fi

# if found an user name, write is to the file /usr/local/default_user_and_group.cfg
if [ "$CURRENTUSER" != '' ]
then
    USERANDGROUP="$CURRENTUSER:staff"
    echo "DEFINE $USERANDGROUP as new standard user and group for some new apps"
    echo '# this value define the default user and group for some new apps (ask: mail@eaxmple.org)' > /usr/local/default_user_and_group.cfg || echo "ERROR: Run this script with sudo, please."
    echo 'USERANDGROUP="'$USERANDGROUP'"' >> /usr/local/default_user_and_group.cfg
	( set -x; cat /usr/local/default_user_and_group.cfg )
fi

exit 0
