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
set formatprg=astyle

" = applies astlye and then indents with vim's default indenter
vnoremap = gqgv=

" Run astyle on the whole file
nnoremap <Leader>ff :call Preserve("normal gggqG")<CR>
