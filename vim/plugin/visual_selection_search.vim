" Allow search for visual selection with * and #
function! VSetSearch()
    let l:temp = @@
    norm! gvy
    let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
    let @@ = l:temp
endfunction
