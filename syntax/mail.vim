" mail.vim -- notmuch.nvim
" -----------------------------------------------------------------------------
" This file contains the syntax pattern matching required to highlight selected
" tags from the headline in the mail view. For more information, check:
"   :h syntax
"   :h syn-contained
"   :h syn-contains
"   :h highlight
" This is split into 3 sections for readability and future understanding sake
" -----------------------------------------------------------------------------

" Section (1) -- Keywords = Tags
" Set up keywords for all the notmuch 'tags' that you want highlighted
" The colors and visuals for each tag is customized in (3)
syntax keyword nmTagInbox inbox contained
syntax keyword nmTagUnread unread contained
syntax keyword nmTagFlagged flagged contained

" Section (2) -- Match the tags list
" Create a regex match for the list of tags (surrounded by parentheses)
" This 'contains' the keywords from (1) so that vim can detect the tags
syntax match nmTagsList /)\s(.*)$/ contains=nmTagInbox,nmTagUnread,nmTagFlagged

" Section (3) -- Customize Visuals
" Highlight and change visuals for the keyword tags from (1) to make them stand out
highlight nmTagInbox guifg=Orange
highlight nmTagUnread guifg=Cyan
highlight nmTagFlagged guifg=Red

" ----------------------------------------------------------
" nmHints:
" First line always contains the Hints with key combinations
" ----------------------------------------------------------

syntax region nmHints		start=/^Hints:/ end=/$/		oneline	contains=nmHintsIdentifier
syntax match nmHintsIdentifier	"^Hints:"			contained nextgroup=nmHintsKey
syntax match nmHintsKey		"\s\+[^:\s]\+"			contained nextgroup=nmHintsKVDelimiter
syntax match nmHintsKVDelimiter	":"				contained nextgroup=nmHintsValue
syntax match nmHintsValue	"\s\+[A-Za-z0-9\ ]\+"		contained nextgroup=nmHintsDelimiter
syntax match nmHintsDelimiter	"|"				contained nextgroup=nmHintsKey

highlight link nmHintsIdentifier	Comment
highlight link nmHintsKey		Include
highlight link nmHintsKVDelimiter	Comment
highlight link nmHintsValue		Normal
highlight link nmHintsDelimiter		Comment
