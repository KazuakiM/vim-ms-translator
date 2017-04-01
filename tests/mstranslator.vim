let s:suite  = themis#suite('mstranslator')
let s:assert = themis#helper('assert')

function! s:suite.before_each() abort "{{{
    let g:mstranslator#Config = {
    \     'to': 'en',
    \     'from': 'ja',
    \     'strict': 0,
    \     'subscription_key': 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    \     'timers': 0
    \ }
endfunction "}}}

function! s:suite.setTo() abort "{{{
    call mstranslator#setTo('ja')

    call s:assert.equals(g:mstranslator#Config.to, 'ja')
endfunction "}}}

function! s:suite.setFrom() abort "{{{
    call mstranslator#setFrom('en')

    call s:assert.equals(g:mstranslator#Config.from, 'en')
endfunction "}}}

function! s:suite.setStrict() abort "{{{
    call mstranslator#setStrict(1)

    call s:assert.equals(g:mstranslator#Config.strict, 1)
endfunction "}}}

function! s:suite.checkLangJa() abort "{{{
    call s:assert.equals(mstranslator#checkLang('I use Vim.'),      'ja')
    call s:assert.equals(mstranslator#checkLang('I''m Vimmer!'),    'ja')
    call s:assert.equals(mstranslator#checkLang('Are you Vimmer?'), 'ja')
endfunction "}}}

function! s:suite.checkLangEn() abort "{{{
    call s:assert.equals(mstranslator#checkLang('私はVimを使います。'),   'en')
    call s:assert.equals(mstranslator#checkLang('私はVimmerです!'),       'en')
    call s:assert.equals(mstranslator#checkLang('あなたはVimmerですか?'), 'en')
endfunction "}}}

function! s:suite.checkLangStrict() abort "{{{
    call mstranslator#setStrict(1)

    call s:assert.equals(mstranslator#checkLang('I use Vim.'),      'en')
    call s:assert.equals(mstranslator#checkLang('I''m Vimmer!'),    'en')
    call s:assert.equals(mstranslator#checkLang('Are you Vimmer?'), 'en')
endfunction "}}}

function! s:suite.checkLangEs() abort "{{{
    call mstranslator#setTo('es')

    call s:assert.equals(mstranslator#checkLang('私はVimを使います。'),   'es')
    call s:assert.equals(mstranslator#checkLang('私はVimmerです!'),       'es')
    call s:assert.equals(mstranslator#checkLang('あなたはVimmerですか?'), 'es')
endfunction "}}}
