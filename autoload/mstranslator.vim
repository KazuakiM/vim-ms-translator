let s:save_cpo = &cpo
set cpo&vim

"variable {{{
if !exists('g:mstranslator#Config') || !has_key(g:mstranslator#Config, 'subscription_key')
    echohl ErrorMsg | echomsg "vim-ms-translator: require g:mstranslator#Config = {'subscription_key'}" | echohl None
    finish
endif
let g:mstranslator#Config.to = !has_key(g:mstranslator#Config, 'to') ? 'en' : g:mstranslator#Config.to

let s:token = ''

let s:V = vital#of('mstranslator').load('Web.HTTP', 'Web.XML')
lockvar! s:V
"}}}

function! mstranslator#setTo(to) abort "{{{
    let g:mstranslator#Config.to = a:to
endfunction "}}}

function! mstranslator#issueToken() abort "{{{
    " @url http://docs.microsofttranslator.com/oauth-token.html
    let l:response = s:V.Web.HTTP.post('https://api.cognitive.microsoft.com/sts/v1.0/issueToken', '', {
        \ 'Ocp-Apim-Subscription-Key': g:mstranslator#Config.subscription_key
        \ })
    let s:token = l:response.content
endfunction "}}}

function! mstranslator#request(str) abort "{{{
    if len(s:token) ==# 0
        call mstranslator#issueToken()
    endif

    let l:responseRaw = s:V.Web.HTTP.get('http://api.microsofttranslator.com/v2/Http.svc/Translate?text=' . a:str .'&to=' . g:mstranslator#Config.to, '', {
        \ 'Authorization': 'Bearer ' . s:token
        \ })
    if len(l:responseRaw) ==# 0 || l:responseRaw.status !=# 200
        if 2 <= s:retry
            return ''
        endif

        let s:retry += 1
        let s:token = ''
        return mstranslator#request(a:str)
    endif

    let l:responseXml = s:V.Web.XML.parse(l:responseRaw.content)
    return l:responseXml.child
endfunction "}}}

function! mstranslator#execute(...) abort "{{{
    let s:retry = 0

    let l:str = join(a:000)
    if len(l:str) ==# 0
        let l:str = expand('<cword>')
        if len(l:str) ==# 0
            return
        endif
    endif

    let l:response = mstranslator#request(l:str)
    if 0 < len(l:response)
        cgetexpr l:response
        copen
    endif
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo
