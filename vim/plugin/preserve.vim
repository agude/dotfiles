" Preserve the view when running a command
function! Preserve(command)
    " Save the window information
    let l:saved_winview = winsaveview()
    " Run the command
    execute a:command
    " Restore previous window information
    call winrestview(l:saved_winview)
endfunction
