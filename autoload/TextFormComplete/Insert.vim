" TextFormComplete.vim: Convert textual options into completion candidates.
"
" DEPENDENCIES:
"   - TextFormComplete.vim autoload script
"
" Copyright: (C) 2012-2013 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.007	03-Jul-2013	Abort q| on error.
"				Refactoring: Pass around 1-based column values
"				instead of 0-based byte indices, this better
"				fits the majority of consumers and variable
"				naming.
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

function! TextFormComplete#Insert#Complete( findstart, base )
    if a:findstart
	let [l:type, l:col] = TextFormComplete#Search('ben')
	let l:isCursorAtEndOfFormText = search('\%'.l:col.'c.\%#', 'bn', line('.'))
	return (l:isCursorAtEndOfFormText ? TextFormComplete#Search('bn', l:type)[1] - 1 : -1) " Return byte index, not column.
    else
	return TextFormComplete#Matches(a:base)
    endif
endfunction

function! TextFormComplete#Insert#Expr()
    set completefunc=TextFormComplete#Insert#Complete
    return "\<C-x>\<C-u>"
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
