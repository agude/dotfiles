"-------------------------------------------------------------------------------
" Always set the cursor to the first line, first column
"-------------------------------------------------------------------------------
augroup git_first_line
    autocmd!
    autocmd BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])
augroup END
