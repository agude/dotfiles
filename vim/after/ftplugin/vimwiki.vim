" Wrap text after 78 characters
setlocal textwidth=78

" Insert en and em dash
if has('multi_byte')
    scriptencoding utf-8
    inoremap -- –
    inoremap --- —
endif

" Insert timestamp with bullet, as used in my notes
if exists('*strftime')
    noremap <F2> 0DI* <C-R>=strftime("%Y.%m.%d %H:%M:%S")<CR>: <Esc>
    inoremap <F2> <ESC>0DI* <C-R>=strftime("%Y.%m.%d %H:%M:%S")<CR>:<Space>
endif
