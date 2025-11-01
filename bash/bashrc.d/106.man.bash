# shellcheck shell=bash
# Add color to man pages

# Color codes and line parts
BLACK=0
RED=1
#GREEN=2
#YELLOW=3
BLUE=4
MAGENTA=5
#CYAN=6
WHITE=7
TEXT=setaf
BG=setab

# Definition of all of the two letter codes:
# https://www.gnu.org/software/termutils/manual/termcap-1.3/html_chapter/termcap_4.html

# Start blinking
export LESS_TERMCAP_mb
LESS_TERMCAP_mb=$(tput bold; tput ${TEXT} ${RED})
# Start bold mode
export LESS_TERMCAP_md
LESS_TERMCAP_md=$(tput bold; tput ${TEXT} ${BLUE})
# Start half bright mode
export LESS_TERMCAP_mh
LESS_TERMCAP_mh=$(tput dim)
# Start reverse mode
export LESS_TERMCAP_mr
LESS_TERMCAP_mr=$(tput rev)
# Start standout mode
export LESS_TERMCAP_so
LESS_TERMCAP_so=$(tput ${BG} ${WHITE}; tput ${TEXT} ${BLACK})
# End standout mode
export LESS_TERMCAP_se
LESS_TERMCAP_se=$(tput rmso; tput sgr0)
# Start underlining
export LESS_TERMCAP_us
LESS_TERMCAP_us=$(tput smul; tput bold; tput ${TEXT} ${MAGENTA})
# End underlining
export LESS_TERMCAP_ue
LESS_TERMCAP_ue=$(tput rmul; tput sgr0)
# End all mode like so, us, mb, md and mr
export LESS_TERMCAP_me
LESS_TERMCAP_me=$(tput sgr0)

# Cause man to show tags (<md>, <us>, etc.) in the man page text
#export LESS_TERMCAP_DEBUG=1

# Unset the color and line part variables
unset -v BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE TEXT BG
