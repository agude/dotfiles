" Prevents reloading of the this file
if exists("b:did_load_filetypes_userafter")
  finish
endif
let b:did_load_filetypes_userafter = 1
augroup filetypedetect
  " au! commands to set the filetype go here
augroup END

" Wrap text after 78 characters
setlocal textwidth=78

" Highlight fenced code blocks
let g:markdown_fenced_languages = [
            \'json=javascript',
            \'python',
            \'bash=sh',
            \'sh',
            \'cpp',
            \]
