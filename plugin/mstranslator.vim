if &cp || (exists('g:loaded_mstranslator') && g:loaded_mstranslator)
    finish
endif
let g:loaded_mstranslator  = 1

command! -nargs=* Mstranslator :call mstranslator#execute(<f-args>)
command! -nargs=1 MstranslatorTo :call mstranslator#setTo(<f-args>)
command! -nargs=1 MstranslatorFrom :call mstranslator#setFrom(<f-args>)
command! -nargs=1 MstranslatorStrict :call mstranslator#setStrict(<f-args>)
