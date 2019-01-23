" Remove spaces at the end of lines across the whole file
function! spaces#StripTrailingNormal()
    :call Preserve("%s/\\s\\+$//e")
endfunction

" Remove spaces at the end of lines in the visually selected area
function! spaces#StripTrailingVisual()
    :call Preserve("'<,'>s/\\s\\+$//e")
endfunction
