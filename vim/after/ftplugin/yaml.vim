" Prevents reloading of the this file
if exists('b:did_load_filetypes_yaml_userafter')
  finish
endif
let b:did_load_filetypes_yaml_userafter = 1
augroup filetypedetect
  " au! commands to set the filetype go here
augroup END

"-------------------------------------------------------------------------------
" Set indentation levels to 2 spaces
"-------------------------------------------------------------------------------
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal tabstop=2
