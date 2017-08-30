## Record the number of colors
hash tput &>/dev/null && COLORS=$(tput colors) && BOLD=$(tput bold) && NORMAL=$(tput sgr0) # Fails when running rsync via ssh to school

# Set colors based on how many we have
if [[ $COLORS -ge 256 ]]; then
    COLOR_DIR='\['$(tput setaf 12)'\]'  # Blue
    COLOR_ROOT='\['$(tput setaf 9)'\]'  # Red
    COLOR_USER='\['$(tput setaf 10)'\]' # Green
    COLOR_SUDO='\['$(tput setaf 11)'\]' # Yellow
    COLOR_SSH='\['$(tput setaf 13)'\]'  # Magenta
    COLOR_UNDO='\[\e[0m\]'
elif [[ $COLORS -ge 8 ]]; then
    COLOR_DIR='\[\e[1;34m\]'  # Blue
    COLOR_ROOT='\[\e[1;31m\]' # Red
    COLOR_USER='\[\e[1;32m\]' # Green
    COLOR_SUDO='\[\e[1;33m\]' # Yellow
    COLOR_SSH='\[\e[1;35m\]'  # Magenta
    COLOR_UNDO='\[\e[0m\]'
else # No color support
    COLOR_DIR=
    COLOR_ROOT=
    COLOR_USER=
    COLOR_SUDO=
    COLOR_UNDO=
fi

# Change the color of the user's name in the prompt based on the user
#
# Root
if [[ $EUID -eq 0 ]]; then
    COLOR_USERNAME=${COLOR_ROOT}
# Other users on the machine
elif [[ -n $SUDO_USER ]]; then
    COLOR_USERNAME=${COLOR_SUDO}
# When sshed to another machine
elif [[ -n "$SSH_CLIENT" ]]; then
    COLOR_USERNAME=${COLOR_SSH}
# Normal user
else
    COLOR_USERNAME=${COLOR_USER}
fi

# Set the prompt
PS1=${COLOR_USERNAME}'\u@\h'${COLOR_UNDO}':'${COLOR_DIR}'\w'${COLOR_UNDO}'\$ '${COLOR_UNDO}${NORM}

# If debian_chroot is set, display in prompt
if [[ -z "$debian_chroot" ]] && [[ -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi
PS1='${debian_chroot:+($debian_chroot)}'${PS1}

# If this is an xterm or rxvt set the title to user@host:dir
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *)
        ;;
esac
