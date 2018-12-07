" Mappings that insert matching curly braces and star comment completion
runtime shared/brace_mapping.vim
runtime shared/c_comment_mapping.vim

" Q applies astyle
setlocal formatprg=astyle
let b:undo_ftplugin .= '|setlocal formatprg<'

" = applies astlye and then indents with vim's default indenter
vnoremap <buffer> = gqgv=

" Run astyle on the whole file
nnoremap <buffer> <Leader>ff :call Preserve("normal gggqG")<CR>
