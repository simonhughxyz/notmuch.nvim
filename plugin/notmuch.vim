command -complete=custom,notmuch#CompSearchTerms -nargs=* NmSearch :call v:lua.require('notmuch').search_terms("<args>")
command ComposeMail :call v:lua.require('notmuch.send').compose()

" vim: tabstop=2:shiftwidth=2:expandtab
