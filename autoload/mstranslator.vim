" @url http://docs.microsofttranslator.com/oauth-token.html
" @url https://msdn.microsoft.com/en-us/library/hh456380.aspx

let s:save_cpo = &cpo
set cpo&vim

"variable {{{
if !exists('g:mstranslator#Config') || !has_key(g:mstranslator#Config, 'subscription_key')
    echohl ErrorMsg | echomsg "vim-ms-translator: require g:mstranslator#Config = {'subscription_key'}" | echohl None
    finish
endif
let g:mstranslator#Config.to = !has_key(g:mstranslator#Config, 'to') ? 'en' : g:mstranslator#Config.to
let g:mstranslator#Config.from = !has_key(g:mstranslator#Config, 'from') ? 'ja' : g:mstranslator#Config.from

let s:token = ''

let s:V = vital#of('mstranslator').load('Web.HTTP', 'Web.XML')
lockvar! s:V
"}}}

function! mstranslator#setTo(to) abort "{{{
    let g:mstranslator#Config.to = a:to
endfunction "}}}

function! mstranslator#setFrom(from) abort "{{{
    let g:mstranslator#Config.from = a:from
endfunction "}}}

function! mstranslator#issueToken() abort "{{{
    let l:response = s:V.Web.HTTP.post('https://api.cognitive.microsoft.com/sts/v1.0/issueToken', '', {
    \     'Ocp-Apim-Subscription-Key': g:mstranslator#Config.subscription_key
    \ })
    let s:token = l:response.content
endfunction "}}}

function! mstranslator#request(retry, text) abort "{{{
    if len(s:token) ==# 0
        call mstranslator#issueToken()
    endif

    let l:to = g:mstranslator#Config.to
    if g:mstranslator#Config.to ==# 'en' && 0 <= match(a:text, '\w')
        let l:to = g:mstranslator#Config.from
    endif

    let l:responseRaw = s:V.Web.HTTP.get('http://api.microsofttranslator.com/v2/Http.svc/Translate?text=' . a:text .'&to=' . l:to, '', {
    \     'Authorization': 'Bearer ' . s:token
    \ })
    if len(l:responseRaw) ==# 0 || l:responseRaw.status !=# 200
        if 2 <= a:retry
            return ''
        endif

        let s:token = ''
        return mstranslator#request(a:retry + 1, a:text)
    endif

    let l:responseXml = s:V.Web.XML.parse(l:responseRaw.content)
    return l:responseXml.child
endfunction "}}}

function! mstranslator#execute(...) abort "{{{
    let l:text = join(a:000)
    if len(l:text) ==# 0
        let l:text = expand('<cword>')
        if len(l:text) ==# 0
            return
        endif
    endif

    let l:response = mstranslator#request(0, l:text)
    if 0 < len(l:response)
        cgetexpr l:response
        copen
    endif
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo
