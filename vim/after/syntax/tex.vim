" Prevents reloading of the this file
if exists("b:did_load_sytanx_userafter")
  finish
endif
let b:did_load_sytanx_userafter = 1

" Match cref as ref
syntax region texRefZone matchgroup=texStatement start="\\v\=cref{" end="}\|%stopzone\>" contains=@texRefGroup
syntax region texRefZone matchgroup=texStatement start="\\v\=Cref{" end="}\|%stopzone\>" contains=@texRefGroup

