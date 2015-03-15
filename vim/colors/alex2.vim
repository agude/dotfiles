" ------------------------------------------------------------------
" Vim color file
" ------------------------------------------------------------------

hi clear
if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "alex2"

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
" ctermfg will default to 'Blue' and ctermbg to 'NONE' if gui(.*) are RGB
"
" In most cases, only GUIFG is therefore important unless support for Black and White
" terminals is essential

if &background == "dark"
    let ColourAssignment['Normal'] = {"GUIFG": 'White', "GUIBG":  'Black'}
else
    let ColourAssignment['Normal'] = {"GUIFG": 'Black', "GUIBG":  'White'}
endif

" Comments are green
let  ColourAssignment['Comment']     =  {"GUIFG":  s:cyan,     "CTERMFG":  'cyan'}
let  ColourAssignment['String']      =  {"GUIFG":  s:magenta,  "CTERMFG":  'magenta'}
let  ColourAssignment['Statement']   =  {"GUIFG":  s:yellow,   "CTERMFG":  'yellow',   "GUI":      'Bold'}
let  ColourAssignment['PreProc']     =  {"GUIFG":  s:blue,     "CTERMFG":  'blue',     "GUI":      'Bold'}
let  ColourAssignment['Identifier']  =  {"GUIFG":  s:green,    "CTERMFG":  'green',    "GUI":      'Bold'}
let  ColourAssignment['Number']      =  {"GUIFG":  s:red,      "CTERMFG":  'red',      "GUI":      'Bold'}
let  ColourAssignment['Type']        =  {"GUIFG":  s:green,    "CTERMFG":  'green',    "GUI":      'Bold'}
let  ColourAssignment['Special']     =  {"GUIFG":  s:red,      "CTERMFG":  'red',      "GUI":      'Bold'}
let  ColourAssignment['Error']       =  {"GUIFG":  s:red,      "CTERMFG":  'red',      "GUI":      'Underline'}
let  ColourAssignment['SpellBad']    =  {"GUIFG":  'NONE',     "GUISP":    s:red,      "CTERMFG":  'red',        "GUI":  'undercurl'}
let  ColourAssignment['Structure']   =  {"GUIFG":  s:magenta,  "CTERMFG":  'magenta'}

" Python Specific
let  ColourAssignment['pythonBuiltinObj']  =  {"GUIFG":  s:magenta,  "CTERMFG":  'magenta'}

" ~ at the end of vim window
let  ColourAssignment['NonText']  =  {"GUIFG":  s:blue,  "CTERMFG":  'blue'}

" Cursors
let  ColourAssignment['CursorColumn']  =  {"GUIBG":  'DarkGrey'}
let  ColourAssignment['CursorLine']    =  {"GUIBG":  'DarkGrey'}
let  ColourAssignment['Cursor']        =  {"GUI":  'Reverse'}

" Searching
let  ColourAssignment['Search']     =  {"GUIFG": 'Black',  "GUIBG": s:yellow, "CTERMFG": 'yellow', "CTERMBG": 'black', "GUI": 'Bold', "CTERM": 'Reverse,Bold'}

" Diff Colors
let  ColourAssignment['DiffAdd']     =  {"GUIFG":  s:green,  "GUIBG":  'Black',  "CTERMFG":  'Green',  "GUI":  'Reverse,Bold'}
let  ColourAssignment['DiffText']    =  {"GUIFG":  s:blue,   "GUIBG":  'Black',  "CTERMFG":  'Blue',   "GUI":  'Reverse,Bold'}
let  ColourAssignment['DiffDelete']  =  {"GUIFG":  s:red,    "GUIBG":  'Black',  "CTERMFG":  'Red',    "GUI":  'Reverse,Bold'}
let  ColourAssignment['DiffChange']  =  {"GUIFG":  'NONE',   "CTERMFG":  'NONE',   "GUI":  'NONE'}

" Filesystem
let  ColourAssignment['Directory']     =  {"GUIFG":  s:blue,  "CTERMFG":  'Blue', "CTERM": 'Bold'}

" Completion
let  ColourAssignment['Pmenu']     =  {"GUIFG":  'Black', "GUIBG": 'Grey'}

" Colorcolum
let  ColourAssignment['ColorColumn']     =  {"GUIBG":  'Grey'}

" Splits
let  ColourAssignment['VertSplit']     =  {"GUIFG":  'White',  "GUIBG":  'NONE'}

" Function to translate the ColourAssignments to highlight lines
let s:colours = {}
let valid_cterm_colours =
            \ [
            \     'Black', 'DarkBlue', 'DarkGreen', 'DarkCyan',
            \     'DarkRed', 'DarkMagenta', 'Brown', 'DarkYellow',
            \     'LightGray', 'LightGrey', 'Gray', 'Grey',
            \     'DarkGray', 'DarkGrey', 'Blue', 'LightBlue',
            \     'Green', 'LightGreen', 'Cyan', 'LightCyan',
            \     'Red', 'LightRed', 'Magenta', 'LightMagenta',
            \     'Yellow', 'LightYellow', 'White',
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
            let ctermfg='Blue'
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
