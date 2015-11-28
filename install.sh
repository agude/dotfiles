#!/usr/bin/env bash

#  Copyright (C) 2013  Alexander Gude -
#  alex.public.account+dotfiles@gmail.com
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software Foundation,
#  Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#  The most recent version of this program is avaible at:
#  https://github.com/agude/dotfiles

# Set up the XDG Base Directory Specification
XDG_FILE="${HOME}"/.bashrc.d/xdg_base_directory.bash
if [[ -f ${XDG_FILE} ]]; then
    source ${XDG_FILE}
fi

# Helper functions
function link() {
    # Remove the taget file or link if it exists
    if [[ -f ${1} || -L ${1} ]]; then
        rm -r ${1}
    fi
    # Link the dotfile to the target
    ln -s ${PWD}/${2} ${1}
}

# Copy bash config files

## bashrc
link ${HOME}/.bashrc /bash/bashrc

## bash_profile
link ${HOME}/.bash_profile /bash/bashrc

## bash_login
link ${HOME}/.bash_login /bash/bashrc

## bash_aliases
link ${HOME}/.bashrc.d /bash/bashrc.d

## bash_logout
link ${HOME}/.bash_logout /bash/bash_logout

# Xmodmap
link ${HOME}/.Xmodmap /xmodmap/Xmodmap

# astyle
link ${HOME}/.astylerc /astyle/astylerc

# terminfo
link ${HOME}/.terminfo /terminfo

# EditorConfig
link ${HOME}/.editorconfig /editorconfig/editorconfig

# ~/bin
mkdir -p ${HOME}/bin

for full_path in ${PWD}/bin/*; do
    # Take the file name from the path
    script_file=${full_path##*/}
    # Remove the suffix
    script_name=${script_file%%.*}
    link ${HOME}/bin/${script_name} /bin/${script_file}
done

# $XDG_CONFIG_HOME
mkdir -p ${XDG_CONFIG_HOME}

for config_sub_directory in ${PWD}/config/*; do
    # Get the program name from the path, and make the corrisponding directory
    # in ${XDG_CONFIG_HOME}
    program_directory=${config_sub_directory##*/}
    mkdir -p ${XDG_CONFIG_HOME}/${program_directory}
    # Link each file independently
    for full_file_path in ${config_sub_directory}/*; do
        file_name=${full_file_path##*/}
        link ${XDG_CONFIG_HOME}/${program_directory}/${file_name} /config/${program_directory}/${file_name}
    done
done

# Vim

## Vim folder
link ${HOME}/.vim /vim

## vimrc
link ${HOME}/.vimrc /vim/vimrc

## gvimrc
link ${HOME}/.gvimrc /vim/gvimrc

## Install vim-plug
if [[ ! -f ${PWD}/vim/autoload/plug.vim ]]; then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

## Install bundles from vimrc
vim +PlugInstall +qall
