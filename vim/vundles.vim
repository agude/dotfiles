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
Bundle 'gmarik/vundle'
"Supertab
Bundle 'ervandew/supertab'
"Surround
Bundle 'tpope/vim-surround'
"Repeat (lets you use . with surround)
Bundle 'tpope/vim-repeat'
"Vimwiki
Bundle 'vimwiki/vimwiki'
"Tagbar
Bundle 'majutsushi/tagbar'
"ctrlp
Bundle 'kien/ctrlp.vim'

"Filetype plugin indent on is required by vundle
filetype plugin indent on
