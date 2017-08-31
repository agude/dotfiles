# From https://github.com/tejr/dotfiles

# Return appropriate options for ls
lsopts() {
    # Snarf the output of `ls --help` into a variable
    local lshelp
    lshelp=$(ls --help 2>/dev/null)

    # Start collecting available options
    local -a lsopts

    # If the --color option is available and we have a terminal that supports
    # at least eight colors, add --color=auto to the options
    local colors
    colors=$(tput colors)
    if [[ "${PLATFORM}" == "mac" ]] || [[ $lshelp == *--color* ]] && ((colors >= 8)) ; then
        lsopts=("${lsopts[@]}" "--color=auto")
    fi

    # Print the options as a single string, space-delimited
    printf %s "${lsopts[*]}"
}

# Alias ls with these options
if [[ "${PLATFORM}" == "mac" ]]; then
    alias ls="gls $(lsopts)"
else
    alias ls="ls $(lsopts)"
fi
alias dir="dir $(lsopts)"
alias vdir="vdir $(lsopts)"

# Unset helper function
unset -f lsopts
