scriptencoding utf-8

" Replace em dashes with --- and en dashes with -- throughout the whole file
function! dashes#ReplaceDashesNormal()
    :silent call Preserve("%s/—/---/ge | %s/–/--/ge")
endfunction

" Replace em dashes with --- and en dashes with -- in the visually selected area
function! dashes#ReplaceDashesVisual()
    :silent call Preserve("'<,'>s/—/---/ge | '<,'>s/–/--/ge")
endfunction
