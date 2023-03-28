" From: https://stackoverflow.com/a/23034108
" Converts 'hard wrapped' text to single line
function! SoftWrap()
    let s:old_fo = &formatoptions
    let s:old_tw = &textwidth
    set fo=
    set tw=999999 " works for paragraphs up to 12k lines
    normal gggqG
    let &fo = s:old_fo
    let &tw = s:old_tw
endfunction
