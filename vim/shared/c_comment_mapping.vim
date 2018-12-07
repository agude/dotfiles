" complete a classical C comment: '/*' => '/* | */'
inoremap  <buffer>  /*              /*<Space><Space>*/<Left><Left><Left>
inoremap  <buffer>  /*<Space>       /*<Space><Space>*/<Left><Left><Left>
vnoremap  <buffer>  /*              s/*<Space><Space>*/<Left><Left><Left><Esc>p

" complete a classical C multi-line comment:
"                      '/*<CR>' =>  /*
"                                    * |
"                                    */
inoremap  <buffer>  /*<CR>  /*<CR><CR>/<Esc>kA<Space>
