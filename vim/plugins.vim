"=============================================================================
" Plugin Settings

"=============================================================================
" Python highlighting settings
"=============================================================================

" Color 'print' as a keyword
let g:python_highlight_builtins = 1
let g:python_highlight_builtin_objs = 1
let g:python_highlight_builtin_funcs = 1
"let g:python_highlight_exceptions = 0
"let g:python_highlight_string_formatting = 0
"let g:python_highlight_string_format = 0
"let g:python_highlight_string_templates = 0
"let g:python_highlight_indent_errors = 0
"let g:python_highlight_space_errors = 0
"let g:python_highlight_doctests = 0
"let g:python_print_as_function = 1
"let g:python_highlight_all = 1

"=============================================================================
" Ctrlp Settings
"=============================================================================

let g:ctrlp_working_path_mode = 'ra' " Use the nearest version controlled dir
" Custom ignore
let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/]\.(git|hg|svn)$',
  \ 'file': '\v\.(exe|so|dll|html|htm)$',
  \ }
" Cache directory location
let g:ctrlp_cache_dir = $XDG_CACHE_HOME . '/vim/ctrlp'
if !isdirectory(g:ctrlp_cache_dir)
    call mkdir(g:ctrlp_cache_dir, 'p', '0700')
endif

"=============================================================================
" TagBar Settings
"=============================================================================

" Toggle TagBar
nnoremap <silent> <Leader>tt :TagbarToggle<CR>
" Open TagBar and jump to it
nnoremap <silent> <Leader>tf :TagbarOpen f<CR>
" Jump to open TagBar
nnoremap <silent> <Leader>tj :TagbarOpen j<CR>
" Autoclose once a tag is selected
let g:tagbar_autoclose = 1
" Sort tags by name, not location
"let g:tagbar_sort = 0
" Change symbols
if has('multi_byte')
    scriptencoding utf-8
    " Separate VertSplits with a solid line
    let g:tagbar_iconchars = ['▾', '▸']
endif

"=============================================================================
" Fugitive Settings
"=============================================================================

" Map various Fugitive commands to <Leader>g
nnoremap <silent> <Leader>gd :Gvdiff<CR>
nnoremap <silent> <Leader>gb :Gblame<CR>

"=============================================================================
" EnchancedDiff
"=============================================================================

" Always use Patience Diff
if &diff
    let &diffexpr='EnhancedDiff#Diff("git diff", "--diff-algorithm=patience")'
endif

