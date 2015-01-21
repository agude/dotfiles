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
"VimCompletesMe
Plugin 'ajh17/VimCompletesMe'
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
"Gnuplot Syntax Highlighting
Plugin 'vim-scripts/gnuplot-syntax-highlighting'
"Git support
Plugin 'tpope/vim-fugitive'

"Filetype plugin indent on is required by vundle
filetype plugin indent on
