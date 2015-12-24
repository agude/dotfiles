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
" Always set the cursor to the first line, first column
"-------------------------------------------------------------------------------
augroup git_first_line
    autocmd!
    autocmd BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])
augroup END
