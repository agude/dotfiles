# Get the number of colors, and the formatting codes
# These use "bright" colors, for "normal" colors subtract 8
hash tput &>/dev/null \
    && COLORS=$(tput colors) \
    && BOLD=$(tput bold) \
    && FORMAT_RESET=$(tput sgr0) \
    && BLACK=$(tput setaf 8) \
    && RED=$(tput setaf 9) \
    && GREEN=$(tput setaf 10) \
    && YELLOW=$(tput setaf 11) \
    && BLUE=$(tput setaf 12) \
    && MAGENTA=$(tput setaf 13) \
    && CYAN=$(tput setaf 14) \
    && WHITE=$(tput setaf 15)

# Set colors based on how many we have
if [[ $COLORS -ge 256 ]]; then
    COLOR_DIR="${BLUE}"
    COLOR_ROOT="${RED}"
    COLOR_USER="${GREEN}"
    COLOR_SUDO="${YELLOW}"
    COLOR_SSH="${MAGENTA}"
elif [[ $COLORS -ge 8 ]]; then
    COLOR_DIR='\[\e[1;34m\]'  # Blue
    COLOR_ROOT='\[\e[1;31m\]' # Red
    COLOR_USER='\[\e[1;32m\]' # Green
    COLOR_SUDO='\[\e[1;33m\]' # Yellow
    COLOR_SSH='\[\e[1;35m\]'  # Magenta
else # No color support
    COLOR_DIR=
    COLOR_ROOT=
    COLOR_USER=
    COLOR_SUDO=
    COLOR_SSH=
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
PS1=${COLOR_USERNAME}'\u@\h'${FORMAT_RESET}':'${COLOR_DIR}'\w'${FORMAT_RESET}'\$ '${FORMAT_RESET}

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

# Unset the color and line part variables
unset -v COLORS BOLD FORMAT_RESET BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE COLOR_DIR COLOR_ROOT COLOR_USER COLOR_SUDO COLOR_SSH
