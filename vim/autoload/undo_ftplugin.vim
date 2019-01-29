" More easily update the b:undo_ftplugin variable. This function:
"
" 1. Creates the variable if it doesn't exist
" 2. Separates new commands with `|` if it does already
"
function! undo_ftplugin#SetUndoFTPlugin(argstr)
    " Copy the buffer version of `undo_ftplugin`, or default to the empty
    " string
    let l:undo_ftplugin = get(b:, 'undo_ftplugin', '')
    
    " If l:undo_ftplugin is empty, add our string, otherwise append with `|`
    let l:append_char = (empty(l:undo_ftplugin) ? '' : ' | ')

    " Append our string
    let l:undo_ftplugin .= l:append_char . a:argstr

    return l:undo_ftplugin
endfunction
