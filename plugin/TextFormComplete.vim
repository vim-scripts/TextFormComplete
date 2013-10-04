" TextFormComplete.vim: Convert textual options into completion candidates.
"
" DEPENDENCIES:
"   - TextFormComplete.vim autoload script
"   - ingo/err.vim autoload script
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.004	04-Jul-2013	Make the deselection value of a single [option]
"				configurable.
"	003	03-Jul-2013	Abort q| on error.
"				ENH: Add visual q| and select mode <C-x>|
"				mappings.
"	002	21-Aug-2012	ENH: Add normal-mode q| mapping.
"	001	20-Aug-2012	file creation

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_TextFormComplete') || (v:version < 700)
    finish
endif
let g:loaded_TextFormComplete = 1

"- configuration ---------------------------------------------------------------

if ! exists('g:TextFormComplete_DeselectionExpr')
    let g:TextFormComplete_DeselectionExpr = 'substitute(v:val, ".", "-", "g")'
endif


"- mappings --------------------------------------------------------------------

inoremap <silent> <expr> <Plug>(TextFormComplete) TextFormComplete#Insert#Expr()
if ! hasmapto('<Plug>(TextFormComplete)', 'i')
    imap <C-x><Bar> <Plug>(TextFormComplete)
endif

nnoremap <silent> <Plug>(TextFormComplete)      :<C-u>call setline('.', getline('.'))<Bar>if ! TextFormComplete#Normal#ChooseAround(v:count)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
if ! hasmapto('<Plug>(TextFormComplete)', 'n')
    nmap q<Bar> <Plug>(TextFormComplete)
endif
xnoremap <silent> <Plug>(TextFormComplete)      :<C-u>call setline('.', getline('.'))<Bar>if ! TextFormComplete#Normal#ChooseVisual(v:count)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
snoremap <silent> <Plug>(TextFormComplete) <C-g>:<C-u>call setline('.', getline('.'))<Bar>if ! TextFormComplete#Normal#ChooseVisual(v:count)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
" Note: Need a separate select mode mapping because without it, the query won't
" show.
if ! hasmapto('<Plug>(TextFormComplete)', 'x')
    xmap q<Bar> <Plug>(TextFormComplete)
endif
if ! hasmapto('<Plug>(TextFormComplete)', 's')
    smap <C-x><Bar> <Plug>(TextFormComplete)
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
