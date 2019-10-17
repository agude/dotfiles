#Reload .bashrc
alias reload='source ${HOME}/.bashrc'

#LS variations
alias lt="ls -ltrh"
alias la="ls -A"
alias ld="ls -dltrh ./*/ 2> /dev/null"

#Use git for diff
alias gdiff="git diff --no-index --"

#SSH Host Key Check
alias ssh-keyreport="ssh_keyreport"
ssh_keyreport(){
    for keyfile in $(/etc/ssh/ssh_host_*_key.pub); do
        ssh-keygen -f "${keyfile}" -l
    done
}

#Run apt check
#alias apt-full='${HOME}/bin/apt_full'

#PEP8
alias pep8="pep8 --repeat"

#chmod pidgin log files
# We killall pidgin first so that we don't change the permissions on a log,
# sync them to another computer, and then keep writing, making future rsyncs
# fail because the file is read only
alias pidgin-chmod='killall pidgin > /dev/null 2>&1; find ${HOME}/.purple/logs/ -type f -perm -u+w -exec chmod u=r,go= {} \+'

#History search
alias hs=" history | grep"

#Suspend
alias suspend-gnome='dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend'

#Columns
ccol() { awk -- "{print \$$1}"; }

#Timestamp
alias now='date +"%Y%m%d"'
