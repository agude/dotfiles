# Get the number of colors, and the formatting codes
#
# These use "bright" colors, for "normal" colors subtract 8
#
# The wrapping \[ \] tell bash to ignore the non-printing characters when
# figuring out the size of the prompt
hash tput &>/dev/null \
    && COLORS=$(tput colors) \
    && BOLD="\[$(tput bold)\]" \
    && FORMAT_RESET="\[$(tput sgr0)\]" \
    && BLACK="\[$(tput setaf 8)\]" \
    && RED="\[$(tput setaf 9)\]" \
    && GREEN="\[$(tput setaf 10)\]" \
    && YELLOW="\[$(tput setaf 11)\]" \
    && BLUE="\[$(tput setaf 12)\]" \
    && MAGENTA="\[$(tput setaf 13)\]" \
    && CYAN="\[$(tput setaf 14)\]" \
    && WHITE="\[$(tput setaf 15)\]"

# Set colors based on how many we have
if [[ $COLORS -ge 256 ]]; then
    COLOR_DIR="${BLUE}"
    COLOR_ROOT="${RED}"
    COLOR_USER="${GREEN}"
    COLOR_SUDO="${YELLOW}"
    COLOR_SSH="${MAGENTA}"
    COLOR_GIT="${RED}"
elif [[ $COLORS -ge 8 ]]; then
    COLOR_DIR='\[\e[1;34m\]'  # Blue
    COLOR_ROOT='\[\e[1;31m\]' # Red
    COLOR_USER='\[\e[1;32m\]' # Green
    COLOR_SUDO='\[\e[1;33m\]' # Yellow
    COLOR_SSH='\[\e[1;35m\]'  # Magenta
    COLOR_GIT='\[\e[1;31m\]'  # Red
else # No color support
    COLOR_DIR=
    COLOR_ROOT=
    COLOR_USER=
    COLOR_SUDO=
    COLOR_SSH=
    COLOR_GIT=
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

# Add git branch to the prompt
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Set the prompt
#
# The part in " " expand when the variable is defined while the part in ' ' is
# left as is and hence rerun every time $PS1 is called
PS1="${COLOR_USERNAME}\u@\h${FORMAT_RESET}:${COLOR_DIR}\w${FORMAT_RESET}${COLOR_GIT}"'$(parse_git_branch)'"${FORMAT_RESET}\$ ${FORMAT_RESET}"

# If debian_chroot is set, display in prompt
if [[ -z "$debian_chroot" ]] && [[ -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi
PS1='${debian_chroot:+($debian_chroot)}'${PS1}

# You can set various resources in xterm, rxvt, and some other terminals by
# printing a string of the form:
#
#     \[\e]N;New Title\a\]
#
# Where the enclosing \[ \] tells bash to ignore it when calculating prompt
# size and the \e]; and \a are literal Operating System Command (OSC) and BEL
# sequences. The N is used by the terminal to control what resource is set,
# where 0 is the "icon name and window title", 1 is the "icon name", and 2 is
# the "window title". For more see man console_codes.
#
# A convenient way to print this to the terminal this is to put it in the $PS1
# prompt.
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *)
        ;;
esac

# Unset the color and line part variables
unset -v COLORS BOLD FORMAT_RESET BLACK RED GREEN YELLOW BLUE MAGENTA CYAN \
         WHITE COLOR_DIR COLOR_ROOT COLOR_USER COLOR_SUDO COLOR_SSH
