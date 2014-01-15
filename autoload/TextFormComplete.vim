" TextFormComplete.vim: Convert textual options into completion candidates.
"
" DEPENDENCIES:
"   - ingo/escape.vim autoload script
"   - SwapIt.vim plugin (optional)
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.10.009	04-Oct-2013	ENH: Add support for sliders [---#-----].
"   1.00.008	04-Jul-2013	Don't add a single option to SwapIt.
"				Allow to deselect a single [option] instead of
"				just stupidly offering no choice.
"	007	03-Jul-2013	Abort q| on error.
"				Refactoring: Pass around 1-based column values
"				instead of 0-based byte indices, this better
"				fits the majority of consumers and variable
"				naming.
"				Split off start and end column determination
"				from TextFormComplete#Choose() and use two
"				strategies implemented in
"				TextFormComplete#ChooseAround() (old) and
"				TextFormComplete#ChooseVisual() (for the new
"				visual mode mappings).
"				ENH: Enable repeat of q|.
"				Separate insert and normal mode implementations
"				from the generic stuff.
"	006	15-Jun-2013	Implement s:Unescape() with generic
"				ingo#escape#Unescape().
"	005	31-May-2013	Move ingouserquery#Get...() functions into
"				ingo-library.
"	004	22-Aug-2012	I18N: Allow for non-ASCII characters in the
"				non-bracketed text form. Modify the s:chars
"				regexps to include non-ASCII characters. Because
"				we only have the endCol of the text form (and
"				cannot easily match beyond that; the line may
"				end there), we cannot simply use strpart(), but
"				have to use matchstr() with /\%c/ to correctly
"				deal with a final non-ASCII character. Same for
"				determining l:isCursorAtEndOfFormText; simply
"				adding 1 to endCol won't do, use search()
"				instead to verify that the cursor is directly
"				after the form text.
"	003	21-Aug-2012	ENH: Also offer normal-mode q| mapping that
"				prints list or used supplied [count].
"				FIX: With the use of the \%# addendum, the
"				backwards match spans multiple text forms
"				(despite \{-}!). Do away with the \%# anchor and
"				instead check for the end match at the cursor
"				position first, then do the search for the
"				beginning of the text form.
"				FIX: Handle corner cases when there's only a [ /
"				] at the beginning / end; this should then not
"				be included in the first / last alternative.
"				Have s:Search() return the text form type (0/1),
"				and pass that in to the second search for the
"				other side, to avoid matches with the other
"				pattern.
"	002	21-Aug-2012	ENH: Define completed alternatives in SwapIt, so
"				that the choice made can be corrected via
"				CTRL-A / CTRL-X.
"	001	20-Aug-2012	file creation

let s:SwapItFormCnt = 0
function! s:AddToSwapIt( matches )
    if ! exists('g:swap_lists')
	" The SwapIt plugin is not installed.
	return
    endif

    let l:options = map(copy(a:matches), 'v:val.word')

    " Avoid defining the form twice, or SwapIt will ask for the option each
    " time.
    let l:swapLists = map(copy(g:swap_lists), 'v:val.options')
    if index(l:swapLists, l:options) != -1
	" The same set of options is already defined.
	return
    endif

    " Add the new options directly to the variable, not through :SwapList; this
    " way, multi-word swaps can be used, too.
    let s:SwapItFormCnt += 1
    call add(g:swap_lists, {'name': 'form' . s:SwapItFormCnt, 'options': l:options})
endfunction

let s:unescaped = '\%(\%(^\|[^\\]\)\%(\\\\\)*\\\)\@<!'
function! s:Unescape( text )
    return ingo#escape#Unescape(a:text, '][|(\')
endfunction
function! s:FormItemToMatch( formItem )
    let [l:item, l:explanation] = matchlist(a:formItem, '^\(.\{-}\)\%( '.s:unescaped.'(\([^)]*\))\)\?$')[1:2]
    let l:match = {'word': s:Unescape(l:item)}
    if ! empty(l:explanation)
	let l:match.menu = s:Unescape(l:explanation)
    endif
    return l:match
endfunction
let s:chars = '\%([][()|\\0-9A-Za-z_+-]\|[^\x00-\x7F]\)'
"              01234567
let s:startChars = s:chars[0:4].s:chars[6:].s:chars.'*'
let s:endChars = s:chars.'*'.s:chars[0:3].s:chars[5:]
function! TextFormComplete#Search( flags, ... )
    let l:type = 0

    if ! a:0 || a:1 == 0
	" Locate the start of a text form in the format "[foo bar|quux]".
	let l:col = searchpos(s:unescaped.'\[.\{-}'.s:unescaped.']', a:flags, line('.'))[1]
    endif
    if a:0 && a:1 == 1 || ! a:0 && l:col == 0
	let l:type = 1

	" Locate the start of a text form in the format "foo|quux".
	let l:col = searchpos(s:startChars.'\%('.s:unescaped.'|'.s:chars.'\+'.'\)*'.s:unescaped.'|'.s:endChars, a:flags, line('.'))[1]
    endif
    return [l:type, l:col]
endfunction
function! s:SliderStepMatch( width, step )
    return {
    \   'word': printf('[%s#%s]',
    \       repeat('-', a:step),
    \       repeat('-', a:width - a:step - 1),
    \   ),
    \   'menu': printf('%2d-%2d%%', 100 * a:step / a:width, 100 * (a:step + 1) / a:width)
    \}
endfunction
function! s:MatchesForSlider( formText )
    let l:formWidth = len(a:formText)   " Since # and - are in the ASCII range and always represented by a single byte, we can simply use the length for a character count.
    return map(range(l:formWidth), 's:SliderStepMatch(l:formWidth, v:val)')
endfunction
function! TextFormComplete#Matches( formText )
    if a:formText =~# '^\[.*]$'
	let l:isEnclosed = 1
	let l:formText = a:formText[1:-2]   " Since [ and ] are in the ASCII range and always represented by a single byte, we can use simple array slicing to remove them.
    else
	let l:isEnclosed = 0
	let l:formText = a:formText
    endif

    if l:isEnclosed && l:formText =~# '^\%(-*#-\+\|-\+#-*\)$'
	let l:matches = s:MatchesForSlider(l:formText)
    else
	let l:formItems = split(l:formText, s:unescaped.'|')
	let l:matches = map(l:formItems, 's:FormItemToMatch(v:val)')
    endif

    if len(l:matches) == 1
	" Allow to deselect a single [option] instead of just stupidly offering
	" no choice.
	call add(l:matches, {'word': ingo#actions#EvaluateWithVal(g:TextFormComplete_DeselectionExpr, l:matches[0].word), 'menu': printf('deselect "%s"', l:matches[0].word) })
    elseif len(l:matches) > 1
	call s:AddToSwapIt(l:matches)
    endif

    return l:matches
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
