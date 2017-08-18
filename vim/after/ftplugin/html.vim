" Prevents reloading of the this file
if exists('b:did_load_filetypes_userafter')
    finish
endif
let b:did_load_filetypes_userafter = 1
augroup filetypedetect
    " au! commands to set the filetype go here
augroup END

" Indent only 2 spaces
set shiftwidth=2   " number of spaces to use for each step of indent
set softtabstop=2  " <Tab> counts for 2 spaces, allows easier deleting
set tabstop=2      " number of spaces that a <Tab> counts for

" Wrap text after 78 characters
setlocal textwidth=78
