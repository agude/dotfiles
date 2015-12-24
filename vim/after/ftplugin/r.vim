" Prevents reloading of the this file
if exists('b:did_load_filetypes_userafter')
  finish
endif
let b:did_load_filetypes_userafter = 1
augroup filetypedetect
  " au! commands to set the filetype go here
augroup END
"
"-------------------------------------------------------------------------------
" additional mapping : {<CR> always opens a block
"-------------------------------------------------------------------------------
imap  <buffer>  {<CR>    {<CR>}<Esc>O
vmap  <buffer>  {<CR>   S{<CR>}<Esc>Pk=iB
