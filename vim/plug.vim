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

if !has('nvim')
    Plug 'https://git.sr.ht/~ackyshake/VimCompletesMe.vim'
endif

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

    " LSP (requires Neovim >= 0.11)
    if has('nvim-0.11')
        Plug 'neovim/nvim-lspconfig'
        Plug 'hrsh7th/cmp-nvim-lsp'
    endif

    " Asynchronous linting
    Plug 'dense-analysis/ale'

    " When native LSP is available, disable ALE's LSP features to avoid
    " conflicts (ALE still handles linting and fixing)
    if has('nvim') && luaeval('type(vim.lsp.enable) == "function"')
        let g:ale_disable_lsp = 1
    endif

    " Toggle ALE
    nnoremap <silent> <Leader>l :ALEToggle<CR>
endif

call plug#end()

"=============================================================================
" nvim-cmp configuration (must be after plug#end)
"=============================================================================

if has('nvim')
lua <<EOF
    -- vim.lsp.config / vim.lsp.enable require Neovim >= 0.11
    if vim.fn.has('nvim-0.11') == 1 then
        local ok, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
        if ok then
            -- Advertise nvim-cmp capabilities to every LSP server
            vim.lsp.config('*', {
                capabilities = cmp_nvim_lsp.default_capabilities(),
            })
        end

        -- Enable LSP servers (only activates if the binary is in PATH)
        vim.lsp.enable({ 'pyright', 'rust_analyzer' })

        -- Tame diagnostics: show signs and underlines but not inline virtual
        -- text, which is too noisy for rust-analyzer while typing incomplete code
        vim.diagnostic.config({
            virtual_text = false,
            signs = true,
            underline = true,
            update_in_insert = false,
        })

        -- LSP keybindings (buffer-local, only active when a server attaches)
        --
        -- Neovim 0.11 already provides these defaults (do NOT duplicate):
        --   K        hover           grn      rename
        --   gra      code action     grr      references
        --   gri      implementation  gO       document symbols
        --   [d / ]d  prev/next diagnostic     <C-w>d  diagnostic float
        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('UserLspKeybindings', { clear = true }),
            callback = function(ev)
                local opts = { buffer = ev.buf }
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gy', vim.lsp.buf.type_definition, opts)
                vim.keymap.set('i', '<C-s>', vim.lsp.buf.signature_help, opts)
            end,
        })
    end

    local cmp = require('cmp')

    -- Insert-mode completion: LSP + buffer words + file paths
    cmp.setup({
        sources = cmp.config.sources({
            { name = 'nvim_lsp' },
            { name = 'path' },
            { name = 'buffer', keyword_length = 3 },
        }),
        mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-e>']     = cmp.mapping.abort(),
            ['<CR>']      = cmp.mapping.confirm({ select = false }),
            ['<C-n>']     = cmp.mapping.select_next_item(),
            ['<C-p>']     = cmp.mapping.select_prev_item(),
            ['<Tab>']     = cmp.mapping.select_next_item(),
            ['<S-Tab>']   = cmp.mapping.select_prev_item(),
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
