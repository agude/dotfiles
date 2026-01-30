# shellcheck shell=bash
# Add color to man pages
#
# Termcap two-letter codes:
# https://www.gnu.org/software/termutils/manual/termcap-1.3/html_chapter/termcap_4.html

# tput capability names
_text=setaf
_bg=setab

# ANSI color numbers
_black=0
_red=1
_blue=4
_magenta=5
_white=7

LESS_TERMCAP_mb=$(tput bold; tput ${_text} ${_red})                # Start blinking
export LESS_TERMCAP_mb
LESS_TERMCAP_md=$(tput bold; tput ${_text} ${_blue})               # Start bold mode
export LESS_TERMCAP_md
LESS_TERMCAP_mh=$(tput dim)                                        # Start half bright mode
export LESS_TERMCAP_mh
LESS_TERMCAP_mr=$(tput rev)                                        # Start reverse mode
export LESS_TERMCAP_mr
LESS_TERMCAP_so=$(tput ${_bg} ${_white}; tput ${_text} ${_black})  # Start standout mode
export LESS_TERMCAP_so
LESS_TERMCAP_se=$(tput rmso; tput sgr0)                            # End standout mode
export LESS_TERMCAP_se
LESS_TERMCAP_us=$(tput smul; tput bold; tput ${_text} ${_magenta}) # Start underlining
export LESS_TERMCAP_us
LESS_TERMCAP_ue=$(tput rmul; tput sgr0)                            # End underlining
export LESS_TERMCAP_ue
LESS_TERMCAP_me=$(tput sgr0)                                       # End all modes
export LESS_TERMCAP_me

unset -v _text _bg _black _red _blue _magenta _white
