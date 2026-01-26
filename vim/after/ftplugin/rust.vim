" Mappings that insert matching curly braces and star comment completion
runtime shared/brace_mapping.vim
runtime shared/c_comment_mapping.vim

" Remove trailing spaces on save
call ft#strip_trailing_spaces_on_save()

" Smart rustfmt integration for the = operator
"
" This provides intelligent formatting that:
"   - Uses rustfmt when given valid/complete Rust code (e.g., gg=G)
"   - Falls back to Vim's built-in indent when rustfmt fails (e.g., partial selections)
"
" This solves the problem where rustfmt errors on incomplete code fragments like:
"   // Keywords
"   Def,
"   Return,
"
" Usage:
"   gg=G     - Format entire file with rustfmt
"   =ip      - Format a paragraph (rustfmt if valid, else built-in indent)
"   V3j=     - Visual select + format (same fallback behavior)
"   ==       - Format current line

function! s:RustFmtOrIndent(type) abort
  " Determine the range based on how we were called:
  "   - From operatorfunc (normal mode =): a:type is 'line', 'char', or 'block'
  "     and '[ '] marks are set by g@
  "   - From visual mode: a:type is 'visual' and '< '> marks are set
  if a:type ==# 'visual'
    let l:start = line("'<")
    let l:end = line("'>")
  else
    let l:start = line("'[")
    let l:end = line("']")
  endif

  " Extract the lines to format
  let l:lines = getline(l:start, l:end)
  let l:input = join(l:lines, "\n")

  " Try rustfmt first
  let l:output = system('rustfmt --edition 2024', l:input)

  if v:shell_error == 0
    " rustfmt succeeded - use its output
    " split() with third arg 1 preserves trailing empty strings
    let l:formatted = split(l:output, "\n", 1)
    " Remove final empty element if rustfmt added trailing newline
    if len(l:formatted) > 0 && l:formatted[-1] ==# ''
      call remove(l:formatted, -1)
    endif
    " Handle line count differences (rustfmt may add/remove lines)
    silent execute l:start . ',' . l:end . 'delete _'
    call append(l:start - 1, l:formatted)
  else
    " rustfmt failed (probably incomplete code) - use Vim's built-in indent
    " Save cursor position
    let l:save_cursor = getcurpos()
    " Apply built-in indent to each line in range
    execute l:start . ',' . l:end . 'normal! =='
    " Restore cursor
    call setpos('.', l:save_cursor)
  endif
endfunction

if executable('rustfmt')
  " Normal mode: = waits for a motion, then calls our function
  nnoremap <buffer> <silent> = :set operatorfunc=<SID>RustFmtOrIndent<CR>g@

  " == formats current line (g@_ means "operate on current line")
  nnoremap <buffer> <silent> == :set operatorfunc=<SID>RustFmtOrIndent<CR>g@_

  " Visual mode: operate on selection
  " <C-u> clears the command line (removes '<,'> that Vim auto-inserts)
  xnoremap <buffer> <silent> = :<C-u>call <SID>RustFmtOrIndent('visual')<CR>
endif
