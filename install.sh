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


# Copy bash config files

## bashrc
if [[ -f ${HOME}/.bashrc || -L ${HOME}/.bashrc ]]; then
    rm -f ${HOME}/.bashrc
fi
ln -s ${PWD}/bash/bashrc ${HOME}/.bashrc

## bash_profile
if [[ -f ${HOME}/.bash_profile || -L ${HOME}/.bash_profile ]]; then
    rm -f ${HOME}/.bash_profile
fi
ln -s ${PWD}/bash/bashrc ${HOME}/.bash_profile

## bash_login
if [[ -f ${HOME}/.bash_login || -L ${HOME}/.bash_login ]]; then
    rm -f ${HOME}/.bash_login
fi
ln -s ${PWD}/bash/bashrc ${HOME}/.bash_login

## bash_aliases
if [[ -d ${HOME}/.bashrc.d || -L ${HOME}/.bashrc.d ]]; then
    rm -f ${HOME}/.bashrc.d
fi
ln -s ${PWD}/bash/bashrc.d ${HOME}/.bashrc.d

## bash_logout
if [[ -f ${HOME}/.bash_logout || -L ${HOME}/.bash_logout ]]; then
    rm -f ${HOME}/.bash_logout
fi
ln -s ${PWD}/bash/bash_logout ${HOME}/.bash_logout

# Readline
if [[ -f ${HOME}/.inputrc || -L ${HOME}/.inputrc ]]; then
    rm -f ${HOME}/.inputrc
fi
ln -s ${PWD}/readline/inputrc ${HOME}/.inputrc

# Git
## Global configurations
if [[ -f ${HOME}/.gitconfig || -L ${HOME}/.gitconfig ]]; then
    rm -f ${HOME}/.gitconfig
fi
ln -s ${PWD}/git/gitconfig ${HOME}/.gitconfig

## Ignore List
if [[ -f ${HOME}/.gitignore || -L ${HOME}/.gitignore ]]; then
    rm -f ${HOME}/.gitignore
fi
ln -s ${PWD}/git/gitignore ${HOME}/.gitignore

# Screen
if [[ -f ${HOME}/.screenrc || -L ${HOME}/.screenrc ]]; then
    rm -f ${HOME}/.screenrc
fi
ln -s ${PWD}/screen/screenrc ${HOME}/.screenrc

# Xmodmap
if [[ -f ${HOME}/.Xmodmap || -L ${HOME}/.Xmodmap ]]; then
    rm -f ${HOME}/.Xmodmap
fi
ln -s ${PWD}/xmodmap/Xmodmap ${HOME}/.Xmodmap

# astyle
if [[ -f ${HOME}/.astylerc || -L ${HOME}/.astylerc ]]; then
    rm -f ${HOME}/.astylerc
fi
ln -s ${PWD}/astyle/astylerc ${HOME}/.astylerc

# terminfo
if [[ -f ${HOME}/.terminfo || -L ${HOME}/.terminfo ]]; then
    rm -f ${HOME}/.terminfo
fi
ln -s ${PWD}/terminfo ${HOME}/.terminfo

# EditorConfig
if [[ -f ${HOME}/.editorconfig || -L ${HOME}/.editorconfig ]]; then
    rm -f ${HOME}/.editorconfig
fi
ln -s ${PWD}/editorconfig/editorconfig ${HOME}/.editorconfig

# ~/bin
mkdir -p ${HOME}/bin

for full_path in ${PWD}/bin/*; do
    # Take the file name from the path
    script_file=${full_path##*/}
    # Remove the suffix
    script_name=${script_file%%.*}
    if [[ -f ${HOME}/bin/${script_name} || -L ${HOME}/bin/${script_name} ]]; then
        rm -f ${HOME}/bin/${script_name}
    fi
    ln -s ${PWD}/bin/${script_file} ${HOME}/bin/${script_name}
done

# Vim

## Vim folder
if [[ -d ${HOME}/.vim || -L ${HOME}/.vim ]]; then
    rm -rf ${HOME}/.vim
fi
ln -s ${PWD}/vim ${HOME}/.vim

## vimrc
if [[ -f ${HOME}/.vimrc || -L ${HOME}/.vimrc ]]; then
    rm -f ${HOME}/.vimrc
fi
ln -s ${PWD}/vim/vimrc ${HOME}/.vimrc

## gvimrc
if [[ -f ${HOME}/.gvimrc || -L ${HOME}/.gvimrc ]]; then
    rm -f ${HOME}/.gvimrc
fi
ln -s ${PWD}/vim/gvimrc ${HOME}/.gvimrc

## Install vim-plug
if [[ ! -f ${PWD}/vim/autoload/plug.vim ]]; then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

## Install bundles from vimrc
vim +PlugInstall +qall
