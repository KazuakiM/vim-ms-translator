" @url http://docs.microsofttranslator.com/oauth-token.html
" @url https://msdn.microsoft.com/en-us/library/hh456380.aspx

let s:save_cpo = &cpo
set cpo&vim

"variable {{{
let s:token = ''
let s:V = vital#of('mstranslator').load('Web.HTTP', 'Web.XML')
"}}}

function! mstranslator#setTo(to) abort "{{{
    let g:mstranslator#Config.to = a:to
endfunction "}}}

function! mstranslator#setFrom(from) abort "{{{
    let g:mstranslator#Config.from = a:from
endfunction "}}}

function! mstranslator#setStrict(strict) abort "{{{
    let g:mstranslator#Config.strict = a:strict
endfunction "}}}

function! mstranslator#issueToken(...) abort "{{{
    let s:token = s:V.Web.HTTP.post('https://api.cognitive.microsoft.com/sts/v1.0/issueToken', '', {
    \     'Ocp-Apim-Subscription-Key': g:mstranslator#Config.subscription_key
    \ }).content
endfunction "}}}

function! mstranslator#request(retry, text, to) abort "{{{
    if len(s:token) ==# 0
        call mstranslator#issueToken()
    endif

    let l:responseRaw = s:V.Web.HTTP.get('http://api.microsofttranslator.com/v2/Http.svc/Translate?text=' . a:text .'&to=' . a:to, '', {
    \     'Authorization': 'Bearer ' . s:token
    \ })

    if len(l:responseRaw) ==# 0 || l:responseRaw.status !=# 200
        if 2 <= a:retry
            return ''
        endif

        let s:token = ''
        return mstranslator#request(a:retry + 1, a:text, a:to)
    endif

    return join(s:V.Web.XML.parse(l:responseRaw.content).child)
endfunction "}}}

function! mstranslator#checkLang(text) abort "{{{
    if g:mstranslator#Config.to ==# 'en' && g:mstranslator#Config.strict ==# 0
        for l:index in range(len(a:text))
            if match(a:text[l:index], "[\'\?\!\.\ 0-9A-Za-z_]") ==# -1
                return g:mstranslator#Config.to
            endif
        endfor
        return g:mstranslator#Config.from
    endif
    return g:mstranslator#Config.to
endfunction "}}}

function! mstranslator#execute(...) abort "{{{
    let l:text = join(a:000)
    if len(l:text) ==# 0
        let l:text = expand('<cword>')
        if len(l:text) ==# 0
            return
        endif
    endif

    let l:to = mstranslator#checkLang(l:text)

    let l:response = mstranslator#request(0, s:V.Web.HTTP.escape(l:text), l:to)
    if 0 < len(l:response)
        let l:return = [l:text, l:response]
        if l:to !=# g:mstranslator#Config.to
            call add(l:return, "\nWARNING: This translate is swapped \"from\" and \"to\".\n\n\tYou can execute strict mode.\n\t:MstranslatorStrict(1)")
        endif
        cgetexpr join(l:return, "\n")
        copen
    endif
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo
