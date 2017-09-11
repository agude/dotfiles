" Based on an answer by Tim Friske:
" https://stackoverflow.com/a/13445254/1342354
au BufRead,BufNewFile *bash* let b:is_bash=1 | set filetype=sh
