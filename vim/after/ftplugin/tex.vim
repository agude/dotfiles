" We are using Linux, so fileformat should be unix
setlocal fileformat=unix
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal fileformat<')

" Wrap text after N characters
setlocal textwidth=120
let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal textwidth<')

" One sentance per line
"function! MyFormatExpr(start, end)
"    silent execute a:start.','.a:end.'s/[.!?]\zs /\r/g'
"endfunction
"
"setlocal formatexpr=MyFormatExpr(v:lnum,v:lnum+v:count-1)
"let b:undo_ftplugin .= '| setlocal formatexpr<'

" Match TODO
syntax  region  texRefZone  matchgroup=texStatement  start="\\v\=cref{"  end="}\|%stopzone\>"  contains=@texRefGroup
