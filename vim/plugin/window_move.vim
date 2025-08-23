" --- Include Guard ---
" Prevent this script from being loaded more than once per session.
if exists('g:loaded_window_move')
    finish
endif
let g:loaded_window_move = 1

" --- Function Definition ---

" A script-local function for seamless window navigation, inspired by tmux.
" It allows moving between splits and intelligently wraps around edges.
function! s:WinMove(key)
    let current_win = winnr()
    execute 'wincmd' a:key

    " If the window number hasn't changed, we hit an edge and need to wrap.
    if current_win == winnr()
        if a:key ==# 'j' || a:key ==# 'k' " If a VERTICAL move failed...
            wincmd s " ...wrap to the next HORIZONTAL split (row).
        else " If a HORIZONTAL move failed...
            wincmd v " ...wrap to the next VERTICAL split (column).
        endif
        " After wrapping to the new column/row, try the original move again.
        execute 'wincmd' a:key
    endif
endfunction

" --- Mappings ---

" Use <Cmd> for cleaner execution than :
" Use <SID> to call the script-local s:WinMove function.
nnoremap <silent> <C-j> <Cmd>call <SID>WinMove('j')<CR>
nnoremap <silent> <C-k> <Cmd>call <SID>WinMove('k')<CR>
nnoremap <silent> <C-h> <Cmd>call <SID>WinMove('h')<CR>
nnoremap <silent> <C-l> <Cmd>call <SID>WinMove('l')<CR>
