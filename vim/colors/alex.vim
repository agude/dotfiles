" ------------------------------------------------------------------
" local syntax file - set colors on a per-machine basis:
" vim: tw=0 ts=4 sw=4
" Vim color file
" Maintainer: Alex Gude
" Filename:	alex.vim
" Copyright: 2013 Alex Gude
" ------------------------------------------------------------------

hi clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "alex"

" Main Text and Window Background
if &background == "dark"
    highlight Normal       ctermfg=White   ctermbg=None   cterm=None        term=None       guibg=black guifg=white
else
    highlight Normal       ctermfg=Black   ctermbg=None   cterm=None        term=None       guibg=white guifg=black
endif

" Other Text
highlight Comment      ctermfg=Cyan    ctermbg=None   cterm=None        term=None
highlight Statement	   ctermfg=Yellow  ctermbg=None   cterm=Bold        term=Bold
highlight PreProc	   ctermfg=Blue    ctermbg=None   cterm=Bold        term=Bold
highlight Identifier   ctermfg=Green   ctermbg=None   cterm=Bold        term=None
highlight Number       ctermfg=Red     ctermbg=None   cterm=None        term=Underline
highlight Constant     ctermfg=Magenta ctermbg=None   cterm=None        term=Underline
highlight Type         ctermfg=Green   ctermbg=None   cterm=Bold        term=None
highlight Special      ctermfg=Red     ctermbg=None   cterm=Bold        term=None
highlight Error        ctermfg=Red     ctermbg=None   cterm=Underline   term=Underline
highlight SpellBad     ctermfg=Red     ctermbg=None   cterm=Underline   term=Underline
highlight Structure    ctermfg=Magenta ctermbg=None   cterm=None        term=Underline

" Python Specific
highlight pythonBuiltinObj    ctermfg=Magenta ctermbg=None   cterm=None term=Underline

" ~ at the end of vim window
highlight NonText      ctermfg=Blue    ctermbg=None   cterm=None        term=None

" Cursors
highlight CursorColumn ctermfg=None    ctermbg=None   cterm=Reverse     term=Reverse
highlight CursorLine   ctermfg=None    ctermbg=None   cterm=Underline   term=Underline
highlight Cursor       ctermfg=None    ctermbg=None   cterm=Underline   term=Underline

" Searching
highlight Search       ctermfg=Yellow  ctermbg=Black cterm=Reverse,bold term=StandOut

" Filesystem
highlight Directory    ctermfg=Blue    ctermbg=None   cterm=Bold        term=Bold

" Completion
highlight Pmenu        ctermfg=Black   ctermbg=Grey   cterm=None        term=None

" Colorcolum
highlight ColorColumn                  ctermbg=Grey   guibg=Grey

" Splits
highlight VertSplit    ctermfg=White ctermbg=None   cterm=None        term=Underline
