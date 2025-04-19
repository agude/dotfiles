scriptencoding utf-8

" Replace smart double and single quotes with straight quotes throughout the
" whole file
function! quotes#ReplaceSmartQuotesNormal()
    :silent call Preserve("%s/[“”]/\"/ge | %s/[‘’]/'/ge")
endfunction

" Replace smart double and single quotes with straight quotes in the visually
" selected area
function! quotes#ReplaceSmartQuotesVisual()
    :silent call Preserve("'<,'>s/[“”]/\"/ge | '<,'>s/[‘’]/'/ge")
endfunction
