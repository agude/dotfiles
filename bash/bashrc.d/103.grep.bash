# From https://github.com/tejr/dotfiles

# Return appropriate options for grep
grepopts() {

    # Start with ignoring binary files
    local -a grepopts=(-I)

    # Snarf the output of `grep --help` into a variable
    local grephelp
    grephelp=$(grep --help 2>/dev/null)

    # If the --exclude option is available, exclude some VCS files
    if [[ $grephelp == *--exclude* ]] ; then
        for exclude_file in .gitignore .gitmodules ; do
            grepopts=("${grepopts[@]}" "--exclude=$exclude_file")
        done
    fi

    # If the --exclude-dir option is available, exclude some VCS dirs
    if [[ $grephelp == *--exclude-dir* ]] ; then
        for exclude_dir in .cvs .git .hg .svn ; do
            grepopts=("${grepopts[@]}" "--exclude-dir=$exclude_dir")
        done
    fi

    # If the --color option is available and we have a terminal that supports
    # at least eight colors, add --color=auto to the options
    local colors
    colors=$(tput colors)
    if [[ $grephelp == *--color* ]] && ((colors >= 8)) ; then
        grepopts=("${grepopts[@]}" "--color=auto")
    fi

    # Print the options as a single string, space-delimited
    printf %s "${grepopts[*]}"
}

# Alias grep with those options
alias grep="grep $(grepopts)"
alias fgrep="fgrep $(grepopts)"
alias egrep="egrep $(grepopts)"

# Unset helper function
unset -f grepopts
