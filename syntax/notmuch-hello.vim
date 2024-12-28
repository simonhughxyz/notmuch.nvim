syntax match nmHelloTags "^.*$"
highlight link nmHelloTags Include

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
