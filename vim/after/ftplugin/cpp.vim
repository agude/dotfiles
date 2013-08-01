" Prevents reloading of the this file
if exists("b:did_load_filetypes_userafter")
    finish
endif
let b:did_load_filetypes_userafter = 1
augroup filetypedetect
    " au! commands to set the filetype go here
augroup END


" Add highlighting for function definition in C++
" from http://vim.wikia.com/wiki/Highlighting_of_method_names_in_the_definition
"function! EnhanceCppSyntax()
"    syn match cppFuncDef "::\~\?\zs\h\w*\ze([^)]*\()\s*\(const\)\?\)\?$"
"    hi def link cppFuncDef Special
"endfunction
"
"autocmd Syntax cpp call EnhanceCppSyntax()
