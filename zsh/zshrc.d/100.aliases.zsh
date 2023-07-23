#LS variations
alias -g lt="ls -Gltrh"
alias -g ls="ls -G"

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

set_alias_if_program_exists 'gfind' 'find'
set_alias_if_program_exists 'gsed' 'sed'
