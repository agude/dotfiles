" ------------------------------------------------------------------
" Vim color file
" ------------------------------------------------------------------
" Author: Alexander Gude

highlight clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "alex"

" Define colors
let s:red     = '#FF5555'
let s:yellow  = '#FFFF55'
let s:green   = '#55FF55'
let s:cyan    = '#55FFFF'
let s:blue    = '#5555FF'
let s:magenta = '#FF55FF'

" The ColourAssignment map and function to unpack it are from the bandit
" colorscheme by Al Bunden, avaliable here:
" http://www.cgtk.co.uk/vim-scripts/bandit

let ColourAssignment = {}

" Unspecified colours default to NONE, EXCEPT cterm(.*) which default to matching gui(.*)
"
" In most cases, only GUIFG is therefore important unless support for Black and White
" terminals is essential

" Set the Main Text and Background based on whether light or dark is selected.
" This theme does not work well on light backgrounds, but at least this will
" give you black text.
if &background == "dark"
    let s:fg = 'White'
    let s:bg = 'Black'
else
    let s:fg = 'Black'
    let s:bg = 'White'
endif


" Editor settings
" ---------------
let  ColourAssignment['Normal']        =  {"GUIFG":  s:fg,        "GUIBG":  s:bg}
let  ColourAssignment['Cursor']        =  {"GUI":    'Reverse'}
let  ColourAssignment['CursorLine']    =  {"GUI":    'NONE'}
let  ColourAssignment['LineNr']        =  {"GUIFG":  'DarkGray'}
let  ColourAssignment['CursorLineNr']  =  {"GUIFG":  'White'}


" Number column
" -------------
let  ColourAssignment['CursorColumn']  =  {"GUIBG":  'DarkGrey'}
let  ColourAssignment['Folded']        =  {"GUIFG":  'Cyan',      "GUIBG":  'DarkGrey'}
let  ColourAssignment['FoldColumn']    =  {"GUIBG":  'DarkGrey'}
highlight! link SignColumn FoldColumn


" Window/Tab delimiters
" ---------------------
let  ColourAssignment['VertSplit']    =  {"GUIFG":  'White',     "GUIBG":  'NONE'}
let  ColourAssignment['ColorColumn']  =  {"GUIBG":  'DarkGray'}
let  ColourAssignment['TabLine']      =  {"GUIFG":  'White',     "GUIBG":  'DarkGray'}
let  ColourAssignment['TabLineFill']  =  {"GUIBG":  'DarkGray'}
let  ColourAssignment['TabLineSel']   =  {"GUIFG":  'Black',     "GUIBG":  'Gray'}


" File Navigation / Searching
" ---------------------------
let  ColourAssignment['Directory']  =  {"GUIFG":  s:blue,     "CTERMFG":  'Blue',    "GUI":      'Bold'}
let  ColourAssignment['Search']     =  {"GUIFG":  'Black',    "GUIBG":    s:yellow,  "CTERMFG":  'yellow',  "CTERMBG":  'black',  "GUI":  'Bold',  "CTERM":  'Reverse,Bold'}
let  ColourAssignment['IncSearch']  =  {"GUI":    'Reverse'}


" Prompt/Status
" -------------
let  ColourAssignment['StatusLine']    =  {"GUI":    'Bold,Reverse'}
let  ColourAssignment['StatusLineNC']  =  {"GUI":    'Reverse'}
let  ColourAssignment['WildMenu']      =  {"GUIFG":  'White',         "GUIBG":    "DarkGrey",  "GUI":  'Bold'}
let  ColourAssignment['Question']      =  {"GUIFG":  s:blue,          "CTERMFG":  'Blue'}
let  ColourAssignment['Title']         =  {"GUI":    'Bold'}
let  ColourAssignment['ModeMsg']       =  {"GUI":    'Bold'}
let  ColourAssignment['MoreMsg']       =  {"GUIFG":  s:green,         "CTERMFG":  'Green'}


" Visual aid
" ----------
let  ColourAssignment['MatchParen']  =  {"GUIBG": s:cyan, "CTERMBG": "cyan"}
let  ColourAssignment['Visual']      =  {"GUIBG":  'DarkGrey'}
highlight! link VisualNOS Visual
let  ColourAssignment['NonText']  =  {"GUIFG":  s:blue,  "CTERMFG":  'blue'}

let  ColourAssignment['Todo']        =  {"GUIFG":  'Black',  "GUIBG":    s:yellow,  "CTERMBG":  'yellow'}
let  ColourAssignment['Underlined']  =  {"GUIFG":  s:cyan,   "CTERMFG":  'cyan',    "GUI":      'Underline'}
let  ColourAssignment['Error']       =  {"GUIFG":  s:red,    "GUIBG":    'Black',   "CTERMFG":  'red',        "GUI":  'Reverse,Bold'}
let  ColourAssignment['ErrorMsg']    =  {"GUIFG":  s:red,    "GUIBG":    'White',   "CTERMFG":  'red',        "GUI":  'Reverse,Bold'}
let  ColourAssignment['WarningMsg']  =  {"GUIFG":  s:red,    "CTERMFG":  'red'}
let  ColourAssignment['Ignore']      =  {"GUIFG":  'bg',     "CTERMFG":  s:bg}
let  ColourAssignment['SpecialKey']  =  {"GUIFG":  s:cyan,   "CTERMFG":  'Cyan'}


" Variable types
" --------------
let  ColourAssignment['Constant']  =  {"GUIFG":  s:magenta,  "CTERMFG":  'magenta'}
let  ColourAssignment['Number']    =  {"GUIFG":  s:red,      "CTERMFG":  'red'}
highlight! link String Constant
highlight! link Boolean Constant
highlight! link Float Number

let  ColourAssignment['Identifier']  =  {"GUIFG":  s:green,  "CTERMFG":  'green',  "GUI":  'Bold'}
highlight! link Function Identifier


" Comments
" --------
let  ColourAssignment['Comment']  =  {"GUIFG":  s:cyan,  "CTERMFG":  'cyan'}
highlight! link SpecialComment Special


" Language constructs
" -------------------
let  ColourAssignment['Statement']  =  {"GUIFG":  s:yellow,  "CTERMFG":  'yellow',  "GUI":  'Bold'}
highlight! link Conditional Statement
highlight! link Repeat Statement
highlight! link Label Statement
highlight! link Operator Statement
highlight! link Keyword Statement
highlight! link Exception Statement

let  ColourAssignment['Special']  =  {"GUIFG":  s:red,  "CTERMFG":  'red'}
highlight! link SpecialChar Special
highlight! link Tag Special
highlight! link Delimiter Special
highlight! link Debug Special


" C like
" ------
let  ColourAssignment['PreProc']  =  {"GUIFG":  s:blue,  "CTERMFG":  'blue',  "GUI":  'Bold'}
highlight! link Include PreProc
highlight! link Define PreProc
highlight! link Macro PreProc
highlight! link PreCondit PreProc

let  ColourAssignment['Type']       =  {"GUIFG":  s:green,    "CTERMFG":  'green',    "GUI":  'Bold'}
let  ColourAssignment['Structure']  =  {"GUIFG":  s:magenta,  "CTERMFG":  'magenta'}
highlight! link StorageClass Type
highlight! link Typedef Type


" Diff
" ----
let  ColourAssignment['DiffAdd']     =  {"GUIFG":  s:green,  "GUIBG":    'Black',  "CTERMFG":  'Green',  "GUI":  'Reverse,Bold'}
let  ColourAssignment['DiffChange']  =  {"GUIFG":  'NONE'}
let  ColourAssignment['DiffDelete']  =  {"GUIFG":  s:red,    "GUIBG":    'Black',  "CTERMFG":  'Red',    "GUI":  'Reverse,Bold'}
let  ColourAssignment['DiffText']    =  {"GUIFG":  s:blue,   "GUIBG":    'Black',  "CTERMFG":  'Blue',   "GUI":  'Reverse,Bold'}


" Completion menu
" ---------------
let  ColourAssignment['Pmenu']       =  {"GUIFG":  'Black',     "GUIBG":  'Grey'}
let  ColourAssignment['PmenuSel']    =  {"GUIFG":  s:yellow,    "GUIBG":  'DarkGrey',  "GUI":  'Bold',  "CTERMFG":  'yellow'}
let  ColourAssignment['PmenuThumb']  =  {"GUIBG":  'DarkGrey'}
highlight! link PmenuSbar Pmenu


" Spelling
" --------
let  ColourAssignment['SpellBad']    =  {"GUIFG":  'NONE',  "GUISP":  s:red,     "CTERMFG":  'red',     "GUI":  'undercurl'}
let  ColourAssignment['SpellCap']    =  {"GUIFG":  'NONE',  "GUISP":  s:blue,    "CTERMFG":  'blue',    "GUI":  'undercurl'}
let  ColourAssignment['SpellLocal']  =  {"GUIFG":  'NONE',  "GUISP":  s:yellow,  "CTERMFG":  'yellow',  "GUI":  'undercurl'}
let  ColourAssignment['SpellRare']   =  {"GUIFG":  'NONE',  "GUISP":  s:green,   "CTERMFG":  'green',   "GUI":  'undercurl'}


" Text Formatting
" ---------------
let  ColourAssignment['Italic']      =  {"GUIFG":  'White',  "GUI":  'Italic'}
let  ColourAssignment['Bold']        =  {"GUIFG":  'White',  "GUI":  'Bold'}
let  ColourAssignment['BoldItalic']  =  {"GUIFG":  'White',  "GUI":  'Italic,Bold'}
highlight! link htmlItalic Italic
highlight! link htmlBold Bold
highlight! link htmlBoldItalic BoldItalic


" Function to translate the ColourAssignments to highlight lines
let s:colours = {}
let valid_cterm_colours =
        \ [
        \  'Black',      'DarkBlue',     'DarkGreen',  'DarkCyan',
        \  'DarkRed',    'DarkMagenta',  'Brown',      'DarkYellow',
        \  'LightGray',  'LightGrey',    'Gray',       'Grey',
        \  'DarkGray',   'DarkGrey',     'Blue',       'LightBlue',
        \  'Green',      'LightGreen',   'Cyan',       'LightCyan',
        \  'Red',        'LightRed',     'Magenta',    'LightMagenta',
        \  'Yellow',     'LightYellow',  'White',
        \ ]

for key in keys(ColourAssignment)
    let s:colours = ColourAssignment[key]
    if has_key(s:colours, 'TERM')
        let term = s:colours['TERM']
    else
        let term = 'NONE'
    endif
    if has_key(s:colours, 'GUI')
        let gui = s:colours['GUI']
    else
        let gui='NONE'
    endif
    if has_key(s:colours, 'GUIFG')
        let guifg = s:colours['GUIFG']
    else
        let guifg='NONE'
    endif
    if has_key(s:colours, 'GUIBG')
        let guibg = s:colours['GUIBG']
    else
        let guibg='NONE'
    endif
    if has_key(s:colours, 'CTERM')
        let cterm = s:colours['CTERM']
    else
        let cterm=gui
    endif
    if has_key(s:colours, 'CTERMFG')
        let ctermfg = s:colours['CTERMFG']
    else
        if index(valid_cterm_colours, guifg) != -1
            let ctermfg=guifg
        else
            let ctermfg='NONE'
        endif
    endif
    if has_key(s:colours, 'CTERMBG')
        let ctermbg = s:colours['CTERMBG']
    else
        if index(valid_cterm_colours, guibg) != -1
            let ctermbg=guibg
        else
            let ctermbg='NONE'
        endif
    endif
    if has_key(s:colours, 'GUISP')
        let guisp = s:colours['GUISP']
    else
        let guisp='NONE'
    endif

    if key =~ '^\k*$'
        execute "highlight ".key." term=".term." cterm=".cterm." gui=".gui." ctermfg=".ctermfg." guifg=".guifg." ctermbg=".ctermbg." guibg=".guibg." guisp=".guisp
    endif
endfor
