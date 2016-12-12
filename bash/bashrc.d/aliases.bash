#Reload .bashrc
alias reload="source ${HOME}/.bashrc"

#LS variations
alias lt="ls -ltrh"
alias la="ls -A"
alias ld="ls -dltrh ./*/ 2> /dev/null"

#Use git for diff
alias gdiff="git diff --no-index --"

#SSH Host Key Check
alias ssh-keyreport="ssh_keyreport"
ssh_keyreport(){
    for keyfile in $(ls /etc/ssh/ssh_host_*_key.pub); do
        ssh-keygen -f ${keyfile} -l
    done
}

#Run apt check
#alias apt-full="${HOME}/bin/apt_full"

#PEP8
alias pep8="pep8 --repeat"

#chmod pidgin log files
# We killall pidgin first so that we don't change the permissions on a log,
# sync them to another computer, and then keep writing, making future rsyncs
# fail because the file is read only
alias pidgin-chmod="killall pidgin > /dev/null 2>&1; find ${HOME}/.purple/logs/ -type f -perm -u+w -exec chmod u=r,go= {} \+"

#History search
alias hs=" history | grep"

#Suspend
alias suspend-gnome='dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend'

#Columns
ccol() { awk -- "{print \$$1}"; }

#Timestamp
alias now='date +"%Y%m%d"'

#Sync

## Pidgin
srpull="\n\nRemote Pull\n\n"
srpush="\n\nRemote Push\n\n"
slpull="\n\nLocal Pull\n\n"
slpush="\n\nLocal Push\n\n"
### Local
alias pidgin-pull="${HOME}/bin/pull -a -i ${HOME}/.purple/logs/"
alias pidgin-push="${HOME}/bin/push -a -i ${HOME}/.purple/logs/"
### External
alias pidgin-pullo="${HOME}/bin/pull -a -i -o ${HOME}/.purple/logs/"
alias pidgin-pusho="${HOME}/bin/push -a -i -o ${HOME}/.purple/logs/"
### Local windows
alias pidgin-winpull="printf '%b' '${slpull}' && rsync -rDvhh --modify-window=1 --itemize-changes --append-verify /mnt/win/c/Users/Alexander\ Gude/AppData/Roaming/.purple/logs/ ${HOME}/.purple/logs/"
alias pidgin-winpush="printf '%b' '${slpush}' && rsync -rDvhh --modify-window=1 --itemize-changes --append-verify ${HOME}/.purple/logs/ /mnt/win/c/Users/Alexander\ Gude/AppData/Roaming/.purple/logs/"
### Combined
alias pidgin-sync="pidgin-winpull && pidgin-pull && pidgin-push && pidgin-winpush"
alias pidgin-synco="pidgin-winpull && pidgin-pullo && pidgin-pusho && pidgin-winpush"

## Documents
### All - Email
alias docs-push="${HOME}/bin/push -d -y -i -x email ${HOME}/Documents/"
alias docs-pull="${HOME}/bin/pull -d -y -i -x email ${HOME}/Documents/"
alias docs-pusho="${HOME}/bin/push -d -y -i -o -x email ${HOME}/Documents/"
alias docs-pullo="${HOME}/bin/pull -d -y -i -o -x email ${HOME}/Documents/"
### Email
alias email-push="${HOME}/bin/push -d -y -i ${HOME}/Documents/email/"
alias email-pull="${HOME}/bin/pull -d -y -i ${HOME}/Documents/email/"
alias email-pusho="${HOME}/bin/push -d -y -i -o ${HOME}/Documents/email/"
alias email-pullo="${HOME}/bin/pull -d -y -i -o ${HOME}/Documents/email/"

## Projects
alias projects-push="${HOME}/bin/push -d -y -i ${HOME}/Projects/"
alias projects-pull="${HOME}/bin/pull -d -y -i ${HOME}/Projects/"
alias projects-pusho="${HOME}/bin/push -d -y -i -o ${HOME}/Projects/"
alias projects-pullo="${HOME}/bin/pull -d -y -i -o ${HOME}/Projects/"

## Music
alias music-push="${HOME}/bin/push -i -y -d ${HOME}/.config/banshee-1/ ${HOME}/Music/"
alias music-pull="${HOME}/bin/pull -i -y -d ${HOME}/.config/banshee-1/ ${HOME}/Music/"
alias music-pusho="${HOME}/bin/push -i -y -d -o ${HOME}/.config/banshee-1/ ${HOME}/Music/"
alias music-pullo="${HOME}/bin/pull -i -y -d -o ${HOME}/.config/banshee-1/ ${HOME}/Music/"

## Dotfiles
alias dot-push="${HOME}/bin/push -y -i -d -x tmp ${HOME}/.dotfiles/"
alias dot-pull="${HOME}/bin/pull -y -i -d -x tmp ${HOME}/.dotfiles/"
alias dot-pusho="${HOME}/bin/push -y -d -x tmp -i -o ${HOME}/.dotfiles/"
alias dot-pullo="${HOME}/bin/pull -y -d -x tmp -i -o ${HOME}/.dotfiles/"

## $HOME/bin
alias bin-push="${HOME}/bin/push -y -i -d ${HOME}/bin/"
alias bin-pull="${HOME}/bin/pull -y -i -d ${HOME}/bin/"
alias bin-pusho="${HOME}/bin/push -y -i -o -d ${HOME}/bin/"
alias bin-pullo="${HOME}/bin/pull -y -i -o -d ${HOME}/bin/"

## Systemfiles
alias system-push="${HOME}/bin/push -y -i -d ${HOME}/.systemfiles/"
alias system-pull="${HOME}/bin/pull -y -i -d ${HOME}/.systemfiles/"
alias system-pusho="${HOME}/bin/push -y -i -o -d ${HOME}/.systemfiles/"
alias system-pullo="${HOME}/bin/pull -y -i -o -d ${HOME}/.systemfiles/"

## Games
alias game-push="${HOME}/bin/push -y -i -d ${HOME}/Games/"
alias game-pull="${HOME}/bin/pull -y -i -d ${HOME}/Games/"
alias game-pusho="${HOME}/bin/push -y -i -o -d ${HOME}/Games/"
alias game-pullo="${HOME}/bin/pull -y -i -o -d ${HOME}/Games/"

# Sync Computers

## From Einstein
alias push-to-dirac="dot-push && bin-push && system-push && projects-push && docs-push && email-push && music-push && game-push"
alias pull-from-dirac="dot-pull && bin-pull && system-pull && projects-pull && docs-pull && music-pull && game-pull"
alias pusho-to-dirac="dot-pusho && bin-pusho && system-pusho && projects-pusho && docs-pusho && email-pusho && music-pusho && game-pusho"
alias pullo-from-dirac="dot-pullo && bin-pullo && system-pullo && projects-pullo && docs-pullo && music-pullo && game-pullo"

##From Newton
alias push-to-einstein="dot-push && bin-push && system-push && projects-push && docs-push && music-push"
alias pull-from-einstein="dot-pull && bin-pull && system-pull && projects-pull && docs-pull && email-pull && music-pull"
alias pusho-to-einstein="dot-pusho && bin-pusho && system-pusho && projects-pusho && docs-pusho && music-pusho"
alias pullo-from-einstein="dot-pullo && bin-pullo && system-pullo && projects-pullo && docs-pullo && email-pullo && music-pullo"
