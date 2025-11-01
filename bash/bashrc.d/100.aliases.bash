# shellcheck shell=bash
# Note: Common aliases (reload, ls variations, gdiff, etc.) are now in shared/sharedrc.d/100.aliases.sh

#SSH Host Key Check
alias ssh-keyreport="ssh_keyreport"
ssh_keyreport(){
    for keyfile in $(/etc/ssh/ssh_host_*_key.pub); do
        ssh-keygen -f "${keyfile}" -l
    done
}

#chmod pidgin log files
# We killall pidgin first so that we don't change the permissions on a log,
# sync them to another computer, and then keep writing, making future rsyncs
# fail because the file is read only
alias pidgin-chmod='killall pidgin > /dev/null 2>&1; find ${HOME}/.purple/logs/ -type f -perm -u+w -exec chmod u=r,go= {} \+'

# Note: History search alias (hs) is now in shared/sharedrc.d/100.aliases.sh

#Suspend
alias suspend-gnome='dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend'

#Columns
ccol() { awk -- "{print \$$1}"; }

#Timestamp
alias now='date +"%Y%m%d"'

## Python
alias wat='python -m pdb -c continue'
