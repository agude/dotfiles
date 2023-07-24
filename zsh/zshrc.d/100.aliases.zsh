#LS variations
alias -g lt="gls --color=auto -ltrh"
alias -g ls="gls --color=auto"

#Use git for diff
alias -g gdiff="git diff --no-index --"

# Shadowing aliases
set_alias_if_program_exists() {
    PROGRAM=$1
    ALIAS_NAME=$2

    # Check if the command exists, and if so aliases
    if [ -x "$(command -v ${PROGRAM})" ]; then
        alias ${ALIAS_NAME}="${PROGRAM}"
    fi
}

# On MacOS shadow the builtin find
if [[ "${PLATFORM}" == "mac" ]]; then
    set_alias_if_program_exists 'gfind' 'find'
    set_alias_if_program_exists 'gsed' 'sed'
    set_alias_if_program_exists 'ggrep' 'grep'
    set_alias_if_program_exists 'gcat' 'cat'
fi

# Set aliases for the renamed MATE applications
set_alias_if_program_exists 'atril' 'evince'
set_alias_if_program_exists 'caja' 'nautilus'
set_alias_if_program_exists 'eom' 'eog'
set_alias_if_program_exists 'pluma' 'gedit'

# Add in drop-in replacements for common programs
set_alias_if_program_exists 'bat' 'cat'
