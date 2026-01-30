" Autoinstall install Plug.vim if doesn't exist
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif


call plug#begin('~/.vim/plugged')

"=============================================================================
" Color Scheme
"=============================================================================

Plug 'agude/vim-eldar'

"=============================================================================
" Completion
"=============================================================================

Plug 'https://git.sr.ht/~ackyshake/VimCompletesMe.vim'

"=============================================================================
" Text Objects and Operators
"=============================================================================

" Surround
Plug 'machakann/vim-sandwich'

" Text object to select within
xmap is <Plug>(textobj-sandwich-query-i)
xmap as <Plug>(textobj-sandwich-query-a)
omap is <Plug>(textobj-sandwich-query-i)
omap as <Plug>(textobj-sandwich-query-a)

xmap iss <Plug>(textobj-sandwich-auto-i)
xmap ass <Plug>(textobj-sandwich-auto-a)
omap iss <Plug>(textobj-sandwich-auto-i)
omap ass <Plug>(textobj-sandwich-auto-a)

xmap im <Plug>(textobj-sandwich-literal-query-i)
xmap am <Plug>(textobj-sandwich-literal-query-a)
omap im <Plug>(textobj-sandwich-literal-query-i)
omap am <Plug>(textobj-sandwich-literal-query-a)

" Repeat (lets you use . with surround)
Plug 'tpope/vim-repeat'

"=============================================================================
" Navigation and Search
"=============================================================================

" Tagbar
Plug 'majutsushi/tagbar'

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
    let g:tagbar_iconchars = ['▾', '▸']
endif

" CtrlP
Plug 'ctrlpvim/ctrlp.vim'

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
" Language Support
"=============================================================================

" Python Syntax Highlighting
Plug 'vim-python/python-syntax'

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

" PEP8 compliant indenting
Plug 'Vimjas/vim-python-pep8-indent'

" Rust
Plug 'rust-lang/rust.vim'

" Jekyll Liquid syntax
Plug 'tpope/vim-liquid'

" Conky Syntax
Plug 'smancill/conky-syntax.vim'

" Mediawiki Syntax
Plug 'chikamichi/mediawiki.vim'

"=============================================================================
" Git Integration
"=============================================================================

Plug 'tpope/vim-fugitive'

" Map various Fugitive commands to <Leader>g
nnoremap <silent> <Leader>gd :Gdiffsplit<CR>
nnoremap <silent> <Leader>gb :Git blame<CR>

"=============================================================================
" Neovim-only Plugins
"=============================================================================

if has('nvim')
    " Completion engine
    Plug 'hrsh7th/nvim-cmp'
    Plug 'hrsh7th/cmp-buffer'
    Plug 'hrsh7th/cmp-path'
    Plug 'hrsh7th/cmp-cmdline'

    " Asynchronous linting
    Plug 'dense-analysis/ale'

    " Toggle ALE
    nnoremap <silent> <Leader>l :ALEToggle<CR>
endif

call plug#end()

"=============================================================================
" nvim-cmp configuration (must be after plug#end)
"=============================================================================

if has('nvim')
lua <<EOF
    local cmp = require('cmp')

    -- Insert-mode completion: buffer words + file paths
    cmp.setup({
        sources = cmp.config.sources({
            { name = 'path' },
            { name = 'buffer', keyword_length = 3 },
        }),
        mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-e>']     = cmp.mapping.abort(),
            ['<CR>']      = cmp.mapping.confirm({ select = false }),
            ['<C-n>']     = cmp.mapping.select_next_item(),
            ['<C-p>']     = cmp.mapping.select_prev_item(),
        }),
    })

    -- Search (/ and ?) completion: buffer words
    cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
            { name = 'buffer' },
        },
    })

    -- Command-line (:) completion: paths + cmdline
    cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
            { name = 'path' },
        }, {
            { name = 'cmdline' },
        }),
    })
EOF
endif
