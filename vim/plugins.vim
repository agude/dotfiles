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
let g:ctrlp_cache_dir = '~/.vim/tmp/ctrlp'

"=============================================================================
" Vimwiki Settings
"=============================================================================

let g:vimwiki_list = [
    \{'path': '~/Documents/wikis/cms/wiki/',
        \'path_html': '~/Documents/wikis/cms/html/',
        \'diary_rel_path': '',
        \'auto_export': 1,
        \'nested_syntaxes':  {'python': 'python', 'c++': 'cpp'}
    \},
        \{'path': '~/Documents/wikis/alex_campaign/player_wiki/wiki/',
        \'path_html': '~/Documents/wikis/alex_campaign/player_wiki/html/',
        \'auto_export': 1,
        \'template_path': '~/Documents/wikis/alex_campaign/templates',
        \'template_default': 'default_template',
        \'template_ext': '.html'
    \},
    \{'path': '~/Documents/wikis/alex_campaign/dm_wiki/wiki/',
        \'path_html': '~/Documents/wikis/alex_campaign/dm_wiki/html/',
        \'auto_export': 1,
        \'template_path': '~/Documents/wikis/alex_campaign/templates',
        \'template_default': 'default_template',
        \'template_ext': '.html'
    \},
    \{'path': '~/Projects/Coursera_Algorithms/notes_wiki/wiki/',
        \'path_html': '~/Projects/Coursera_Algorithms/notes_wiki/html/',
        \'auto_export': 1,
        \'nested_syntaxes':  {'python': 'python', 'c++': 'cpp'}
    \},
\]

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
let g:tagbar_iconchars = ['▾', '▸']
