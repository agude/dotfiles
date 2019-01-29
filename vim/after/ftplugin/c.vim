" Mappings that insert matching curly braces and star comment completion
runtime shared/brace_mapping.vim
runtime shared/c_comment_mapping.vim

" Q applies astyle
setlocal formatprg=astyle
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal formatprg<')

" = applies astlye and then indents with vim's default indenter
xnoremap <buffer> = gqgv=

" Run astyle on the whole file
nnoremap <buffer> <Leader>ff :call Preserve("normal gggqG")<CR>

" Remove trailing spaces on save
" This is a bit complicated, and a lot of it is stolen from here:
" https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
augroup TrailingSpacesC
    autocmd! * <buffer>
    autocmd BufWritePre <buffer> call spaces#StripTrailingNormal()
augroup END
" If the buffer changes filetype, we have to unload the autocmd
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("exec 'autocmd! TrailingSpacesC * <buffer>'")
