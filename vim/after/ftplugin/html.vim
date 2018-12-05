" Indent only 2 spaces
setlocal shiftwidth=2   " number of spaces to use for each step of indent
let b:undo_ftplugin .= '| setlocal shiftwidth<'
setlocal softtabstop=2  " <Tab> counts for 2 spaces, allows easier deleting
let b:undo_ftplugin .= '| setlocal softtabstop<'
setlocal tabstop=2      " number of spaces that a <Tab> counts for
let b:undo_ftplugin .= '| setlocal tabstop<'

" Wrap text after 78 characters
setlocal textwidth=78
let b:undo_ftplugin .= '| setlocal textwidth<'
