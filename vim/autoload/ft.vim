" Autoload script for filetype-specific helper functions

" Sets up an autocommand to strip trailing whitespace on save for the current buffer.
" Also configures b:undo_ftplugin to clean up the autocommand.
function! ft#strip_trailing_spaces_on_save()
  augroup StripTrailingSpaces
    autocmd! * <buffer>
    autocmd BufWritePre <buffer> call spaces#StripTrailingNormal()
  augroup END
  let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin("exec 'autocmd! StripTrailingSpaces * <buffer>'")
endfunction

" Sets buffer-local indentation settings (shiftwidth, softtabstop, tabstop)
" to a given width and enables expandtab.
" Also configures b:undo_ftplugin to revert these settings.
function! ft#set_indent(width)
  execute 'setlocal shiftwidth=' . a:width
  execute 'setlocal softtabstop=' . a:width
  execute 'setlocal tabstop=' . a:width
  setlocal expandtab

  let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal shiftwidth<')
  let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal softtabstop<')
  let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal tabstop<')
  let b:undo_ftplugin = undo_ftplugin#SetUndoFTPlugin('setlocal expandtab<')
endfunction
