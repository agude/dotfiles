"=============================================================================
" Vundle Settings
"=============================================================================

filetype off                   " required!
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

"-----------------------------------------------------------------------------
" List bundles to manage with Vundle
"-----------------------------------------------------------------------------

"Use Vundle to manage vundle
Plugin 'gmarik/vundle'
"Supertab
Plugin 'ervandew/supertab'
"Surround
Plugin 'tpope/vim-surround'
"Repeat (lets you use . with surround)
Plugin 'tpope/vim-repeat'
"Vimwiki
Plugin 'vimwiki/vimwiki'
"Tagbar
Plugin 'majutsushi/tagbar'
"ctrlp
Plugin 'kien/ctrlp.vim'
"Python Syntax Highlighting 
Plugin 'hdima/python-syntax'

"Filetype plugin indent on is required by vundle
filetype plugin indent on
