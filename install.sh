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
if [[ -f ${HOME}/.bash_aliases || -L ${HOME}/.bash_aliases ]]; then
    rm -f ${HOME}/.bash_aliases
fi
ln -s ${PWD}/bash/bash_aliases ${HOME}/.bash_aliases

## bashx
if [[ -f ${HOME}/.bashx || -L ${HOME}/.bashx ]]; then
    rm -f ${HOME}/.bashx
fi
ln -s ${PWD}/bash/bashx ${HOME}/.bashx

## bash_logout
if [[ -f ${HOME}/.bash_logout || -L ${HOME}/.bash_logout ]]; then
    rm -f ${HOME}/.bash_logout
fi
ln -s ${PWD}/bash/bash_logout ${HOME}/.bash_logout

# Root
## rootrc
if [[ -f ${HOME}/.rootrc || -L ${HOME}/.rootrc ]]; then
    rm -f ${HOME}/.rootrc
fi
ln -s ${PWD}/root/rootrc ${HOME}/.rootrc

## rootlogon.C
if [[ -f ${HOME}/.rootlogon.C || -L ${HOME}/.rootlogon.C ]]; then
    rm -f ${HOME}/.rootlogon.C
fi
ln -s ${PWD}/root/rootlogon.C ${HOME}/.rootlogon.C

# Readline
if [[ -f ${HOME}/.inputrc || -L ${HOME}/.inputrc ]]; then
    rm -f ${HOME}/.inputrc
fi
ln -s ${PWD}/readline/inputrc ${HOME}/.inputrc

# Git
if [[ -f ${HOME}/.gitconfig || -L ${HOME}/.gitconfig ]]; then
    rm -f ${HOME}/.gitconfig
fi
ln -s ${PWD}/git/gitconfig ${HOME}/.gitconfig

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

## Install vundle
if [[ ! -d ${PWD}/vim/bundle/vundle ]]; then
    git clone https://github.com/gmarik/vundle.git ${PWD}/vim/bundle/vundle
fi

## Install bundles from vimrc
vim +PluginInstall +qall
