" Remove spaces at the end of lines across the whole file
function! quotes#ReplaceSmartQuotesNormal()
    :silent call Preserve("%s/[“”]/\"/ge | %s/[‘’]/'/ge")
endfunction

" Remove spaces at the end of lines in the visually selected area
function! quotes#ReplaceSmartQuotesVisual()
    :silent call Preserve("'<,'>s/[“”]/\"/ge | '<,'>s/[‘’]/'/ge")
endfunction
