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

" Insert en and em dash
inoremap -- –
inoremap --- —

" Insert timestamp with bullet, as used in my notes
if exists("*strftime")
    noremap <F2> 0DI* <C-R>=strftime("%Y.%m.%d %H:%M:%S")<CR>: <Esc>
    inoremap <F2> <ESC>0DI* <C-R>=strftime("%Y.%m.%d %H:%M:%S")<CR>:<Space>
endif
