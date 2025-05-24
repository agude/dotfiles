scriptencoding utf-8

" Replace ellipsis (…) with three periods (...) throughout the whole file
function! ellipsis#ReplaceEllipsisNormal()
    :silent call Preserve("%s/…/.../ge")
endfunction

" Replace ellipsis (…) with three periods (...) in the visually selected area
function! ellipsis#ReplaceEllipsisVisual()
    :silent call Preserve("'<,'>s/…/.../ge")
endfunction
