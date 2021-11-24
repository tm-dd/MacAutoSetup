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


# check of root rights
if [ $USER != "root" ]
then
	echo "THIS SCRIPT MUST RUN AS USER root !!!"
        exec sudo $0
fi

date
sleep 1
diskutil eject /Volumes/USB_VOLUME 2> /dev/null
diskutil eject /Volumes/TimeMachine 2> /dev/null
tput bel
say "starting munki updates"
sudo /usr/local/munki/managedsoftwareupdate
sudo /usr/local/munki/managedsoftwareupdate --installonly
sudo /usr/local/munki/managedsoftwareupdate
sudo /usr/local/munki/managedsoftwareupdate --installonly
sudo /usr/local/munki/managedsoftwareupdate
sudo /usr/local/munki/managedsoftwareupdate --installonly
sudo /usr/local/munki/managedsoftwareupdate
sleep 10
tput bel
sleep 3
say "starting system updates"
softwareupdate -i -a --restart
say "updates installed"
date
exit 0
