" Remove trailing spaces on save
" This is a bit complicated, and a lot of it is stolen from here:
" https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
augroup TrailingSpacesRuby
    autocmd! * <buffer>
    autocmd BufWritePre <buffer> call spaces#StripTrailingNormal()
augroup END
" If the buffer changes filetype, we have to unload the autocmd
let b:undo_ftplugin = "exec 'autocmd! TrailingSpacesRuby * <buffer>'"
