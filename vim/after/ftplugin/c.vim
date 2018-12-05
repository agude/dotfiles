"-------------------------------------------------------------------------------
" additional mapping : complete a classical C comment: '/*' => '/* | */'
"-------------------------------------------------------------------------------
imap  <buffer>  /*              /*<Space><Space>*/<Left><Left><Left>
imap  <buffer>  /*<Space>       /*<Space><Space>*/<Left><Left><Left>
vmap  <buffer>  /*              s/*<Space><Space>*/<Left><Left><Left><Esc>p

"-------------------------------------------------------------------------------
" additional mapping : complete a classical C multi-line comment:
"                      '/*<CR>' =>  /*
"                                    * |
"                                    */
"-------------------------------------------------------------------------------
imap  <buffer>  /*<CR>  /*<CR><CR>/<Esc>kA<Space>

"-------------------------------------------------------------------------------
" additional mapping : {<CR> always opens a block
"-------------------------------------------------------------------------------
imap  <buffer>  {<CR>    {<CR>}<Esc>O
vmap  <buffer>  {<CR>   S{<CR>}<Esc>Pk=iB

"-------------------------------------------------------------------------------
" additional mapping : use astyle for formatting
"-------------------------------------------------------------------------------

" Q applies astyle
setlocal formatprg=astyle
let b:undo_ftplugin .= '|setlocal formatprg<'

" = applies astlye and then indents with vim's default indenter
vnoremap <buffer> = gqgv=

" Run astyle on the whole file
nnoremap <buffer> <Leader>ff :call Preserve("normal gggqG")<CR>
