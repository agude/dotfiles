" Wrap text after 78 characters
setlocal textwidth=78
let b:undo_ftplugin = 'setlocal textwidth<'

" Insert en and em dash
if has('multi_byte')
    " en and em dash require utf-8
    scriptencoding utf-8
    inoremap <buffer> -- –
    inoremap <buffer> --- —
    scriptencoding
    " using an empty scriptencoding ends the condition (or rather, sets the
    " rest of the lines to the default
endif

" Insert timestamp with bullet, as used in my notes
if exists('*strftime')
    noremap <buffer> <F2> 0DI- <C-R>=strftime("%Y.%m.%d %H:%M:%S")<CR>: <Esc>
    inoremap <buffer> <F2> <ESC>0DI- <C-R>=strftime("%Y.%m.%d %H:%M:%S")<CR>:<Space>
endif
