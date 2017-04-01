if &cp || (exists('g:loaded_mstranslator') && g:loaded_mstranslator)
    finish
endif
let g:loaded_mstranslator  = 1

if !exists('g:mstranslator#Config') || !has_key(g:mstranslator#Config, 'subscription_key')
    echohl ErrorMsg | echomsg "vim-ms-translator: require g:mstranslator#Config = {'subscription_key'}" | echohl None
    finish
endif
let g:mstranslator#Config.to = !has_key(g:mstranslator#Config, 'to') ? 'en' : g:mstranslator#Config.to
let g:mstranslator#Config.from = !has_key(g:mstranslator#Config, 'from') ? 'ja' : g:mstranslator#Config.from
let g:mstranslator#Config.strict = !has_key(g:mstranslator#Config, 'strict') ? 0 : g:mstranslator#Config.strict
let g:mstranslator#Config.timers = !has_key(g:mstranslator#Config, 'timers') ? 0 : g:mstranslator#Config.timers

if has('timers') && g:mstranslator#Config.timers ==# 1
    let s:timer = timer_start(480000, 'mstranslator#issueToken', {'repeat': -1})
endif

command! -nargs=* Mstranslator :call mstranslator#execute(<f-args>)
command! -nargs=1 MstranslatorTo :call mstranslator#setTo(<f-args>)
command! -nargs=1 MstranslatorFrom :call mstranslator#setFrom(<f-args>)
command! -nargs=1 MstranslatorStrict :call mstranslator#setStrict(<f-args>)
