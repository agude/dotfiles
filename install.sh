#!/usr/bin/env bash

set -e
set -u

# Set up the XDG Base Directory Specification
XDG_FILE="./bash/bashrc.d/001.xdg_base_directory.bash"
if [[ -f ${XDG_FILE} ]]; then
    echo "Running ${XDG_FILE}"
    source "${XDG_FILE}"
fi

# Helper functions
function link() {
    # Remove the taget file or link if it exists
    if [[ -f ${1} || -L ${1} ]]; then
        echo "Removing: ${1}"
        rm -r "${1}"
    fi
    # Link the dotfile to the target
    echo "Linking: ${PWD}/${2} -> ${1}"
    ln -s "${PWD}/${2}" "${1}"
}

# Copy bash config files

## bashrc
link "${HOME}/.bashrc" /bash/bashrc
link "${HOME}/.bash_profile" /bash/bashrc
link "${HOME}/.bash_login" /bash/bashrc

## bash_aliases
link "${HOME}/.bashrc.d" /bash/bashrc.d

## bash_logout
link "${HOME}/.bash_logout" /bash/bash_logout

# Xmodmap
link "${HOME}/.Xmodmap" /xmodmap/Xmodmap

# astyle
link "${HOME}/.astylerc" /astyle/astylerc

# terminfo
link "${HOME}/.terminfo" /terminfo

# EditorConfig
link "${HOME}/.editorconfig" /editorconfig/editorconfig

# $HOME/bin
mkdir -p "${HOME}/bin"

for full_path in "${PWD}/bin/"*; do
    # Take the file name from the path
    script_file=${full_path##*/}
    # Remove the suffix
    script_name=${script_file%%.*}
    link "${HOME}/bin/${script_name}" "/bin/${script_file}"
done

# $XDG_CONFIG_HOME
mkdir -p "${XDG_CONFIG_HOME}"

for config_sub_directory in "${PWD}/config/"*; do
    # Get the program name from the path, and make the corrisponding directory
    # in ${XDG_CONFIG_HOME}
    program_directory=${config_sub_directory##*/}
    mkdir -p "${XDG_CONFIG_HOME}/${program_directory}"
    # Link each file independently
    for full_file_path in "${config_sub_directory}/"*; do
        file_name="${full_file_path##*/}"
        link "${XDG_CONFIG_HOME}/${program_directory}/${file_name}" "/config/${program_directory}/${file_name}"
    done
done

# Vim

## Vim folder
link "${HOME}/.vim" /vim

## vimrc
link "${HOME}/.vimrc" /vim/vimrc

## gvimrc
link "${HOME}/.gvimrc" /vim/gvimrc

## neovim
link "${XDG_CONFIG_HOME}/nvim" /vim

## Idea vimrc
link "${HOME}/.ideavimrc" /vim/ideavimrc

## Install bundles from vimrc
vim -es -u "${HOME}/.vim/vimrc" -i NONE -c "PlugInstall" -c "qa"
