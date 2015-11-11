" Prevents reloading of the this file
if exists("b:did_load_filetypes_userafter")
    finish
endif
let b:did_load_filetypes_userafter = 1
augroup filetypedetect
    " au! commands to set the filetype go here
augroup END

" Use enter to follow links in Vim's help
nnoremap <buffer> <cr> <c-]>
