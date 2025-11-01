" ~/.vim/after/ftplugin/ruby.vim

" Set indentation to 2 spaces for Ruby files
setlocal shiftwidth=2
setlocal tabstop=2
setlocal softtabstop=2
setlocal expandtab

" Remove trailing spaces on save
" This is a bit complicated, and a lot of it is stolen from here:
" https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
augroup TrailingSpacesRuby
    autocmd! * <buffer>
    autocmd BufWritePre <buffer> call spaces#StripTrailingNormal()
augroup END

" If the buffer changes filetype, we have to unload everything.
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("exec 'autocmd! TrailingSpacesRuby * <buffer>'")
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("setlocal shiftwidth<")
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("setlocal tabstop<")
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("setlocal softtabstop<")
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("setlocal expandtab<")
