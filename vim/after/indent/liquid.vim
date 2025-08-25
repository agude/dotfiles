" This runs AFTER the vim-liquid indent script and resets the indentexpr
" because the plugin breaks `gq` formatting for bulleted lists.
setlocal indentexpr=
