"-------------------------------------------------------------------------------
" additional mapping : complete a classical C comment: '/*' => '/* | */'
"-------------------------------------------------------------------------------
inoremap  <buffer>  /*              /*<Space><Space>*/<Left><Left><Left>
inoremap  <buffer>  /*<Space>       /*<Space><Space>*/<Left><Left><Left>
vnoremap  <buffer>  /*              s/*<Space><Space>*/<Left><Left><Left><Esc>p

"-------------------------------------------------------------------------------
" additional mapping : complete a classical C multi-line comment:
"                      '/*<CR>' =>  /*
"                                    * |
"                                    */
"-------------------------------------------------------------------------------
inoremap  <buffer>  /*<CR>  /*<CR><CR>/<Esc>kA<Space>

"-------------------------------------------------------------------------------
" additional mapping : {<CR> always opens a block
"-------------------------------------------------------------------------------
inoremap  <buffer>  {<CR>    {<CR>}<Esc>O
vnoremap  <buffer>  {<CR>   S{<CR>}<Esc>Pk=iB

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
