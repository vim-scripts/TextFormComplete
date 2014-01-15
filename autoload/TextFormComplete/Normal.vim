" TextFormComplete.vim: Convert textual options into completion candidates.
"
" DEPENDENCIES:
"   - TextFormComplete.vim autoload script
"   - ingo/selection/position.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/query/get.vim autoload script
"   - repeat.vim (vimscript #2136) autoload script (optional)
"   - visualrepeat.vim (vimscript #3848) autoload script (optional)
"
" Copyright: (C) 2012-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.10.010	09-Jan-2014	Set change marks when replacing the text form
"				with a match.
"   1.10.009	28-Nov-2013	Cosmetics: Add one more padding between the
"				number and the alternative in the query; looks
"				better this way.
"   1.00.008	04-Jul-2013	Factor out handling of selection to
"				ingo#selection#position#Get().
"				Handle linewise selected text forms.
"				Deal with multiple selected lines by showing
"				error.
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

function! s:GetChoice( matches )
    echohl Title
    echo ' #  alternative'
    echohl None
    for i in range(1, len(a:matches))
	let l:explanation = get(a:matches[i - 1], 'menu', '')
	echo printf('%2d  %s', i, a:matches[i - 1].word)
	if ! empty(l:explanation)
	    echohl Directory
	    echon "\t" . l:explanation
	    echohl None
	endif
    endfor
    echo 'Type number (<Enter> cancels): '
    let l:choice = ingo#query#get#Number(len(a:matches))
    redraw	" Somehow need this to avoid the hit-enter prompt.
    return l:choice
endfunction
function! s:ReplaceWithMatch( startCol, endCol, match )
    let l:line = getline('.')
    call setline('.', strpart(l:line, 0, a:startCol - 1) . a:match.word . matchstr(l:line, '\%>'.a:endCol.'c.*$'))    " Indices in strpart() are 0-based, columns in /\%c/ are 1-based.

    " Set the change marks to the first and last character of the replaced
    " match, like e.g. the "p" command.
    call setpos("'[", [0, line('.'), a:startCol, 0])
    call setpos("']", [0, line('.'), a:startCol + len(a:match.word) - 1, 0])
endfunction
function! TextFormComplete#Normal#ChooseAround( count )
    " Try before / at the cursor.
    let [l:type, l:startCol] = TextFormComplete#Search('bc')
    if l:startCol == -1
	" Try after the cursor.
	let [l:type, l:startCol] = TextFormComplete#Search('')
    endif
    if l:startCol == -1
	call ingo#err#Set('No text form under cursor')
	return 0
    endif

    let l:endCol = TextFormComplete#Search('cen', l:type)[1]
    return TextFormComplete#Normal#Choose(a:count, l:startCol, l:endCol)
endfunction
function! TextFormComplete#Normal#ChooseVisual( count )
    let [l:startPos, l:endPos] = ingo#selection#position#Get()
    if l:startPos[0] != l:endPos[0]
	call ingo#err#Set('Select a single line text form')
	return 0
    endif

    " Must convert the 0x7FFFFFFF value from a linewise visual selection to the
    " actual length; TextFormComplete#Normal#Choose() can only deal with that.
    return TextFormComplete#Normal#Choose(a:count, l:startPos[1], min([l:endPos[1], len(getline("'<"))]))
endfunction
function! TextFormComplete#Normal#Choose( count, startCol, endCol )
    let l:formText = matchstr(getline('.'), '\%'.a:startCol.'c.*\%'.a:endCol.'c.')
    let l:matches = TextFormComplete#Matches(l:formText)
    if empty(l:matches)
	call ingo#err#Set('No text form alternatives')
	return 0
    endif

    let l:count = (a:count ? a:count : s:GetChoice(l:matches))

    if l:count == -1
	return 1
    elseif l:count > len(l:matches)
	call ingo#err#Set(printf('Only %d alternatives', len(l:matches)))
	return 0
    endif

    call s:ReplaceWithMatch(a:startCol, a:endCol, l:matches[l:count - 1])

    silent! call       repeat#set("\<Plug>(TextFormComplete)", l:count)
    silent! call visualrepeat#set("\<Plug>(TextFormComplete)", l:count)

    return 1
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
