" Highlight fenced code blocks
let g:markdown_fenced_languages = [
            \'json=javascript',
            \'python',
            \'bash=sh',
            \'sh',
            \'cpp',
            \]

" Remove smart quotes on save
" This is a bit complicated, and a lot of it is stolen from here:
" https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
augroup SmartQuoteReplaceMarkdown
    autocmd! * <buffer>
    autocmd BufWritePre <buffer> call quotes#ReplaceSmartQuotesNormal()
augroup END
" If the buffer changes filetype, we have to unload the autocmd
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("exec 'autocmd! SmartQuoteReplaceMarkdown * <buffer>'")
