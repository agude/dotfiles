" Indent only 2 spaces
call ft#set_indent(2)

" Wrap text after 78 characters
setlocal textwidth=78
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal textwidth<')
