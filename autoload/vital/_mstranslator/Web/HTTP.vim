let s:save_cpo = &cpo
set cpo&vim


function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Prelude = s:V.import('Prelude')
  let s:Process = s:V.import('Process')
  let s:String = s:V.import('Data.String')
endfunction

function! s:_vital_depends() abort
  return ['Prelude', 'Data.String', 'Process']
endfunction

function! s:__urlencode_char(c) abort
  return printf('%%%02X', char2nr(a:c))
endfunction

function! s:decodeURI(str) abort
  let ret = a:str
  let ret = substitute(ret, '+', ' ', 'g')
  let ret = substitute(ret, '%\(\x\x\)', '\=printf("%c", str2nr(submatch(1), 16))', 'g')
  return ret
endfunction

function! s:escape(str) abort
  let result = ''
  for i in range(len(a:str))
    if a:str[i] =~# '^[a-zA-Z0-9_.~-]$'
      let result .= a:str[i]
    else
      let result .= s:__urlencode_char(a:str[i])
    endif
  endfor
  return result
endfunction

function! s:encodeURI(items) abort
  let ret = ''
  if s:Prelude.is_dict(a:items)
    for key in sort(keys(a:items))
      if strlen(ret)
        let ret .= '&'
      endif
      let ret .= key . '=' . s:encodeURI(a:items[key])
    endfor
  elseif s:Prelude.is_list(a:items)
    for item in sort(a:items)
      if strlen(ret)
        let ret .= '&'
      endif
      let ret .= item
    endfor
  else
    let ret = s:escape(a:items)
  endif
  return ret
endfunction

function! s:encodeURIComponent(items) abort
  let ret = ''
  if s:Prelude.is_dict(a:items)
    for key in sort(keys(a:items))
      if strlen(ret) | let ret .= '&' | endif
      let ret .= key . '=' . s:encodeURIComponent(a:items[key])
    endfor
  elseif s:Prelude.is_list(a:items)
    for item in sort(a:items)
      if strlen(ret) | let ret .= '&' | endif
      let ret .= item
    endfor
  else
    let items = iconv(a:items, &enc, 'utf-8')
    let len = strlen(items)
    let i = 0
    while i < len
      let ch = items[i]
      if ch =~# '[0-9A-Za-z-._~!''()*]'
        let ret .= ch
      elseif ch ==# ' '
        let ret .= '+'
      else
        let ret .= '%' . substitute('0' . s:String.nr2hex(char2nr(ch)), '^.*\(..\)$', '\1', '')
      endif
      let i = i + 1
    endwhile
  endif
  return ret
endfunction

function! s:request(...) abort
  let settings = s:_build_settings(a:000)
  let settings.method = toupper(settings.method)
  if !has_key(settings, 'url')
    throw 'vital: Web.HTTP: "url" parameter is required.'
  endif
  if !s:Prelude.is_list(settings.client)
    let settings.client = [settings.client]
  endif
  let client = s:_get_client(settings)
  if empty(client)
    throw 'vital: Web.HTTP: Available client not found: '
    \    . string(settings.client)
  endif
  if has_key(settings, 'contentType')
    let settings.headers['Content-Type'] = settings.contentType
  endif
  if has_key(settings, 'param')
    if s:Prelude.is_dict(settings.param)
      let getdatastr = s:encodeURI(settings.param)
    else
      let getdatastr = settings.param
    endif
    if strlen(getdatastr)
      let settings.url .= '?' . getdatastr
    endif
  endif
  if has_key(settings, 'data')
    let settings.data = s:_postdata(settings.data)
    let settings.headers['Content-Length'] = len(join(settings.data, "\n"))
  endif
  let settings._file = {}

  let responses = client.request(settings)

  for file in values(settings._file)
    if filereadable(file)
      call delete(file)
    endif
  endfor

  call map(responses, 's:_build_response(v:val[0], v:val[1])')
  return s:_build_last_response(responses)
endfunction

function! s:get(url, ...) abort
  let settings = {
  \    'url': a:url,
  \    'param': a:0 > 0 ? a:1 : {},
  \    'headers': a:0 > 1 ? a:2 : {},
  \ }
  return s:request(settings)
endfunction

function! s:post(url, ...) abort
  let settings = {
  \    'url': a:url,
  \    'data': a:0 > 0 ? a:1 : {},
  \    'headers': a:0 > 1 ? a:2 : {},
  \    'method': a:0 > 2 ? a:3 : 'POST',
  \ }
  return s:request(settings)
endfunction

function! s:_readfile(file) abort
  if filereadable(a:file)
    return join(readfile(a:file, 'b'), "\n")
  endif
  return ''
endfunction

function! s:_make_postfile(data) abort
  let fname = s:_tempname()
  call writefile(a:data, fname, 'b')
  return fname
endfunction

function! s:_tempname() abort
  return tr(tempname(), '\', '/')
endfunction

function! s:_postdata(data) abort
  if s:Prelude.is_dict(a:data)
    return [s:encodeURI(a:data)]
  elseif s:Prelude.is_list(a:data)
    return a:data
  else
    return split(a:data, "\n")
  endif
endfunction

function! s:_build_response(header, content) abort
  let response = {
  \   'header' : a:header,
  \   'content': a:content,
  \   'status': 0,
  \   'statusText': '',
  \   'success': 0,
  \ }

  if !empty(a:header)
    let status_line = get(a:header, 0)
    let matched = matchlist(status_line, '^HTTP/1\.\d\s\+\(\d\+\)\s\+\(.*\)')
    if !empty(matched)
      let [status, status_text] = matched[1 : 2]
      let response.status = status - 0
      let response.statusText = status_text
      let response.success = status =~# '^2'
      call remove(a:header, 0)
    endif
  endif
  return response
endfunction

function! s:_build_last_response(responses) abort
  let all_headers = []
  for response in a:responses
    call extend(all_headers, response.header)
  endfor
  let last_response = remove(a:responses, -1)
  let last_response.redirectInfo = a:responses
  let last_response.allHeaders = all_headers
  return last_response
endfunction

function! s:_build_settings(args) abort
  let settings = {
  \   'method': 'GET',
  \   'headers': {},
  \   'client': ['python', 'curl', 'wget'],
  \   'maxRedirect': 20,
  \   'retry': 1,
  \ }
  let args = copy(a:args)
  if len(args) == 0
    throw 'vital: Web.HTTP: request() needs one or more arguments.'
  endif
  if s:Prelude.is_dict(args[-1])
    call extend(settings, remove(args, -1))
  endif
  if len(args) == 2
    let settings.method = remove(args, 0)
  endif
  if !empty(args)
    let settings.url = args[0]
  endif

  return settings
endfunction

function! s:_make_header_args(headdata, option, quote) abort
  let args = ''
  for [key, value] in items(a:headdata)
    if s:Prelude.is_windows()
      let value = substitute(value, '"', '"""', 'g')
    endif
    let args .= ' ' . a:option . a:quote . key . ': ' . value . a:quote
  endfor
  return args
endfunction

function! s:parseHeader(headers) abort
  " FIXME: User should be able to specify the treatment method of the duplicate item.
  let header = {}
  for h in a:headers
    let matched = matchlist(h, '^\([^:]\+\):\s*\(.*\)$')
    if !empty(matched)
      let [name, value] = matched[1 : 2]
      let header[name] = value
    endif
  endfor
  return header
endfunction

" Clients
function! s:_get_client(settings) abort
  for name in a:settings.client
    if has_key(s:clients, name) && s:clients[name].available(a:settings)
      return s:clients[name]
    endif
  endfor
  return {}
endfunction
let s:clients = {}

let s:clients.python = {}

function! s:clients.python.available(settings) abort
  if !has('python')
    return 0
  endif
  if has_key(a:settings, 'outputFile')
    " 'outputFile' is not supported yet
    return 0
  endif
  if get(a:settings, 'retry', 0) != 1
    " 'retry' is not supported yet
    return 0
  endif
  if has_key(a:settings, 'authMethod')
    return 0
  endif
  return 1
endfunction

function! s:clients.python.request(settings) abort
  " TODO: retry, outputFile
  let responses = []
  python << endpython
try:
    class DummyClassForLocalScope:
        def main():
            try:
                from StringIO import StringIO
            except ImportError:
                from io import StringIO
            import vim, urllib2, socket, gzip

            responses = vim.bindeval('responses')

            class CustomHTTPRedirectHandler(urllib2.HTTPRedirectHandler):
                def __init__(self, max_redirect):
                    self.max_redirect = max_redirect

                def redirect_request(self, req, fp, code, msg, headers, newurl):
                    if self.max_redirect == 0:
                        return None
                    if 0 < self.max_redirect:
                        self.max_redirect -= 1
                    header_list = filter(None, str(headers).split("\r\n"))
                    responses.extend([[[status(code, msg)] + header_list, fp.read()]])
                    return urllib2.HTTPRedirectHandler.redirect_request(self, req, fp, code, msg, headers, newurl)

            def vimlist2str(list):
                if not list:
                    return None
                return "\n".join([s.replace("\n", "\0") for s in list])

            def status(code, msg):
                return "HTTP/1.0 %d %s\r\n" % (code, msg)

            def access():
                settings = vim.eval('a:settings')
                data = vimlist2str(settings.get('data'))
                timeout = settings.get('timeout')
                if timeout:
                    timeout = float(timeout)
                request_headers = settings.get('headers')
                max_redirect = int(settings.get('maxRedirect'))
                director = urllib2.build_opener(CustomHTTPRedirectHandler(max_redirect))
                if settings.has_key('username'):
                    passman = urllib2.HTTPPasswordMgrWithDefaultRealm()
                    passman.add_password(
                        None,
                        settings['url'],
                        settings['username'],
                        settings.get('password', ''))
                    basicauth = urllib2.HTTPBasicAuthHandler(passman)
                    digestauth = urllib2.HTTPDigestAuthHandler(passman)
                    director.add_handler(basicauth)
                    director.add_handler(digestauth)
                req = urllib2.Request(settings['url'], data, request_headers)
                req.get_method = lambda: settings['method']
                default_timeout = socket.getdefaulttimeout()
                try:
                    # for Python 2.5 or before
                    socket.setdefaulttimeout(timeout)
                    res = director.open(req, timeout=timeout)
                except urllib2.HTTPError as res:
                    pass
                except urllib2.URLError:
                    return ('', '')
                except socket.timeout:
                    return ('', '')
                finally:
                    socket.setdefaulttimeout(default_timeout)

                st = status(res.code, res.msg)
                response_headers = st + ''.join(res.info().headers)
                response_body = res.read()

                gzip_decompress = settings.get('gzipDecompress', False)
                if gzip_decompress:
                    buf = StringIO(response_body)
                    f = gzip.GzipFile(fileobj=buf)
                    response_body = f.read()[:-1]

                return (response_headers, response_body)

            (header, body) = access()
            responses.extend([[header.split("\r\n"), body]])

        main()
        raise RuntimeError("Exit from local scope")

except RuntimeError as exception:
    if exception.args != ("Exit from local scope",):
        raise exception

endpython
  return responses
endfunction

let s:clients.curl = {}

let s:clients.curl.errcode = {}
let s:clients.curl.errcode[1] = 'Unsupported protocol. This build of curl has no support for this protocol.'
let s:clients.curl.errcode[2] = 'Failed to initialize.'
let s:clients.curl.errcode[3] = 'URL malformed. The syntax was not correct.'
let s:clients.curl.errcode[4] = 'A feature or option that was needed to perform the desired request was not enabled or was explicitly disabled at buildtime. To make curl able to do this, you probably need another build of libcurl!'
let s:clients.curl.errcode[5] = 'Couldn''t resolve proxy. The given proxy host could not be resolved.'
let s:clients.curl.errcode[6] = 'Couldn''t resolve host. The given remote host was not resolved.'
let s:clients.curl.errcode[7] = 'Failed to connect to host.'
let s:clients.curl.errcode[8] = 'FTP weird server reply. The server sent data curl couldn''t parse.'
let s:clients.curl.errcode[9] = 'FTP access denied. The server denied login or denied access to the particular resource or directory you wanted to reach. Most often you tried to change to a directory that doesn''t exist on the server.'
let s:clients.curl.errcode[11] = 'FTP weird PASS reply. Curl couldn''t parse the reply sent to the PASS request.'
let s:clients.curl.errcode[13] = 'FTP weird PASV reply, Curl couldn''t parse the reply sent to the PASV request.'
let s:clients.curl.errcode[14] = 'FTP weird 227 format. Curl couldn''t parse the 227-line the server sent.'
let s:clients.curl.errcode[15] = 'FTP can''t get host. Couldn''t resolve the host IP we got in the 227-line.'
let s:clients.curl.errcode[17] = 'FTP couldn''t set binary. Couldn''t change transfer method to binary.'
let s:clients.curl.errcode[18] = 'Partial file. Only a part of the file was transferred.'
let s:clients.curl.errcode[19] = 'FTP couldn''t download/access the given file, the RETR (or similar) command failed.'
let s:clients.curl.errcode[21] = 'FTP quote error. A quote command returned error from the server.'
let s:clients.curl.errcode[22] = 'HTTP page not retrieved. The requested url was not found or returned another error with the HTTP error code being 400 or above. This return code only appears if -f, --fail is used.'
let s:clients.curl.errcode[23] = 'Write error. Curl couldn''t write data to a local filesystem or similar.'
let s:clients.curl.errcode[25] = 'FTP couldn''t STOR file. The server denied the STOR operation, used for FTP uploading.'
let s:clients.curl.errcode[26] = 'Read error. Various reading problems.'
let s:clients.curl.errcode[27] = 'Out of memory. A memory allocation request failed.'
let s:clients.curl.errcode[28] = 'Operation timeout. The specified time-out period was reached according to the conditions.'
let s:clients.curl.errcode[30] = 'FTP PORT failed. The PORT command failed. Not all FTP servers support the PORT command, try doing a transfer using PASV instead!'
let s:clients.curl.errcode[31] = 'FTP couldn''t use REST. The REST command failed. This command is used for resumed FTP transfers.'
let s:clients.curl.errcode[33] = 'HTTP range error. The range "command" didn''t work.'
let s:clients.curl.errcode[34] = 'HTTP post error. Internal post-request generation error.'
let s:clients.curl.errcode[35] = 'SSL connect error. The SSL handshaking failed.'
let s:clients.curl.errcode[36] = 'FTP bad download resume. Couldn''t continue an earlier aborted download.'
let s:clients.curl.errcode[37] = 'FILE couldn''t read file. Failed to open the file. Permissions?'
let s:clients.curl.errcode[38] = 'LDAP cannot bind. LDAP bind operation failed.'
let s:clients.curl.errcode[39] = 'LDAP search failed.'
let s:clients.curl.errcode[41] = 'Function not found. A required LDAP function was not found.'
let s:clients.curl.errcode[42] = 'Aborted by callback. An application told curl to abort the operation.'
let s:clients.curl.errcode[43] = 'Internal error. A function was called with a bad parameter.'
let s:clients.curl.errcode[45] = 'Interface error. A specified outgoing interface could not be used.'
let s:clients.curl.errcode[47] = 'Too many redirects. When following redirects, curl hit the maximum amount.'
let s:clients.curl.errcode[48] = 'Unknown option specified to libcurl. This indicates that you passed a weird option to curl that was passed on to libcurl and rejected. Read up in the manual!'
let s:clients.curl.errcode[49] = 'Malformed telnet option.'
let s:clients.curl.errcode[51] = 'The peer''s SSL certificate or SSH MD5 fingerprint was not OK.'
let s:clients.curl.errcode[52] = 'The server didn''t reply anything, which here is considered an error.'
let s:clients.curl.errcode[53] = 'SSL crypto engine not found.'
let s:clients.curl.errcode[54] = 'Cannot set SSL crypto engine as default.'
let s:clients.curl.errcode[55] = 'Failed sending network data.'
let s:clients.curl.errcode[56] = 'Failure in receiving network data.'
let s:clients.curl.errcode[58] = 'Problem with the local certificate.'
let s:clients.curl.errcode[59] = 'Couldn''t use specified SSL cipher.'
let s:clients.curl.errcode[60] = 'Peer certificate cannot be authenticated with known CA certificates.'
let s:clients.curl.errcode[61] = 'Unrecognized transfer encoding.'
let s:clients.curl.errcode[62] = 'Invalid LDAP URL.'
let s:clients.curl.errcode[63] = 'Maximum file size exceeded.'
let s:clients.curl.errcode[64] = 'Requested FTP SSL level failed.'
let s:clients.curl.errcode[65] = 'Sending the data requires a rewind that failed.'
let s:clients.curl.errcode[66] = 'Failed to initialise SSL Engine.'
let s:clients.curl.errcode[67] = 'The user name, password, or similar was not accepted and curl failed to log in.'
let s:clients.curl.errcode[68] = 'File not found on TFTP server.'
let s:clients.curl.errcode[69] = 'Permission problem on TFTP server.'
let s:clients.curl.errcode[70] = 'Out of disk space on TFTP server.'
let s:clients.curl.errcode[71] = 'Illegal TFTP operation.'
let s:clients.curl.errcode[72] = 'Unknown TFTP transfer ID.'
let s:clients.curl.errcode[73] = 'File already exists (TFTP).'
let s:clients.curl.errcode[74] = 'No such user (TFTP).'
let s:clients.curl.errcode[75] = 'Character conversion failed.'
let s:clients.curl.errcode[76] = 'Character conversion functions required.'
let s:clients.curl.errcode[77] = 'Problem with reading the SSL CA cert (path? access rights?).'
let s:clients.curl.errcode[78] = 'The resource referenced in the URL does not exist.'
let s:clients.curl.errcode[79] = 'An unspecified error occurred during the SSH session.'
let s:clients.curl.errcode[80] = 'Failed to shut down the SSL connection.'
let s:clients.curl.errcode[82] = 'Could not load CRL file, missing or wrong format (added in 7.19.0).'
let s:clients.curl.errcode[83] = 'Issuer check failed (added in 7.19.0).'
let s:clients.curl.errcode[84] = 'The FTP PRET command failed'
let s:clients.curl.errcode[85] = 'RTSP: mismatch of CSeq numbers'
let s:clients.curl.errcode[86] = 'RTSP: mismatch of Session Identifiers'
let s:clients.curl.errcode[87] = 'unable to parse FTP file list'
let s:clients.curl.errcode[88] = 'FTP chunk callback reported error'
let s:clients.curl.errcode[89] = 'No connection available, the session will be queued'
let s:clients.curl.errcode[90] = 'SSL public key does not matched pinned public key'


function! s:clients.curl.available(settings) abort
  return executable(self._command(a:settings))
endfunction

function! s:clients.curl._command(settings) abort
  return get(get(a:settings, 'command', {}), 'curl', 'curl')
endfunction

function! s:clients.curl.request(settings) abort
  let quote = s:_quote()
  let command = self._command(a:settings)
  let a:settings._file.header = s:_tempname()
  let command .= ' --dump-header ' . quote . a:settings._file.header . quote
  let has_output_file = has_key(a:settings, 'outputFile')
  if has_output_file
    let output_file = a:settings.outputFile
  else
    let output_file = s:_tempname()
    let a:settings._file.content = output_file
  endif
  let command .= ' --output ' . quote . output_file . quote
  if has_key(a:settings, 'gzipDecompress') && a:settings.gzipDecompress
    let command .= ' --compressed '
  endif
  let command .= ' -L -s -k -X ' . a:settings.method
  let command .= ' --max-redirs ' . a:settings.maxRedirect
  let command .= s:_make_header_args(a:settings.headers, '-H ', quote)
  let timeout = get(a:settings, 'timeout', '')
  let command .= ' --retry ' . a:settings.retry
  if timeout =~# '^\d\+$'
    let command .= ' --max-time ' . timeout
  endif
  if has_key(a:settings, 'username')
    let auth = a:settings.username . ':' . get(a:settings, 'password', '')
    let auth = escape(auth, quote)
    if has_key(a:settings, 'authMethod')
      if index(['basic', 'digest', 'ntlm', 'negotiate'], a:settings.authMethod) == -1
        throw 'vital: Web.HTTP: Invalid authorization method: ' . a:settings.authMethod
      endif
      let method = a:settings.authMethod
    else
      let method = 'anyauth'
    endif
    let command .= ' --' . method . ' --user ' . quote . auth . quote
  endif
  if has_key(a:settings, 'data')
    let a:settings._file.post = s:_make_postfile(a:settings.data)
    let command .= ' --data-binary @' . quote . a:settings._file.post . quote
  endif
  let command .= ' ' . quote . a:settings.url . quote

  call s:Process.system(command)
  let retcode = s:Process.get_last_status()

  let headerstr = s:_readfile(a:settings._file.header)
  let header_chunks = split(headerstr, "\r\n\r\n")
  let headers = map(header_chunks, 'split(v:val, "\r\n")')
  if retcode != 0 && empty(headers)
    if has_key(s:clients.curl.errcode, retcode)
      throw 'vital: Web.HTTP: ' . s:clients.curl.errcode[retcode]
    else
      throw 'vital: Web.HTTP: Unknown error code has occured in curl: code=' . retcode
    endif
  endif
  if !empty(headers)
    let responses = map(headers, '[v:val, ""]')
  else
    let responses = [[[], '']]
  endif
  if has_output_file
    let content = ''
  else
    let content = s:_readfile(output_file)
  endif
  let responses[-1][1] = content
  return responses
endfunction

let s:clients.wget = {}
let s:clients.wget.errcode = {}
let s:clients.wget.errcode[1] = 'Generic error code.'
let s:clients.wget.errcode[2] = 'Parse error---for instance, when parsing command-line options, the .wgetrc or .netrc...'
let s:clients.wget.errcode[3] = 'File I/O error.'
let s:clients.wget.errcode[4] = 'Network failure.'
let s:clients.wget.errcode[5] = 'SSL verification failure.'
let s:clients.wget.errcode[6] = 'Username/password authentication failure.'
let s:clients.wget.errcode[7] = 'Protocol errors.'
let s:clients.wget.errcode[8] = 'Server issued an error response.'


function! s:clients.wget.available(settings) abort
  if has_key(a:settings, 'authMethod')
    return 0
  endif
  return executable(self._command(a:settings))
endfunction

function! s:clients.wget._command(settings) abort
  return get(get(a:settings, 'command', {}), 'wget', 'wget')
endfunction

function! s:clients.wget.request(settings) abort
  let quote = s:_quote()
  let command = self._command(a:settings)
  let method = a:settings.method
  if method ==# 'HEAD'
    let command .= ' --spider'
  elseif method !=# 'GET' && method !=# 'POST'
    let a:settings.headers['X-HTTP-Method-Override'] = a:settings.method
  endif
  let a:settings._file.header = s:_tempname()
  let command .= ' -o ' . quote . a:settings._file.header . quote
  let has_output_file = has_key(a:settings, 'outputFile')
  if has_output_file
    let output_file = a:settings.outputFile
  else
    let output_file = s:_tempname()
    let a:settings._file.content = output_file
  endif
  let command .= ' -O ' . quote . output_file . quote
  let command .= ' --server-response -q -L '
  let command .= ' --max-redirect=' . a:settings.maxRedirect
  let command .= s:_make_header_args(a:settings.headers, '--header=', quote)
  let timeout = get(a:settings, 'timeout', '')
  let command .= ' --tries=' . a:settings.retry
  if timeout =~# '^\d\+$'
    let command .= ' --timeout=' . timeout
  endif
  if has_key(a:settings, 'username')
    let command .= ' --http-user=' . quote . escape(a:settings.username, quote) . quote
  endif
  if has_key(a:settings, 'password')
    let command .= ' --http-password=' . quote . escape(a:settings.password, quote) . quote
  endif
  let command .= ' ' . quote . a:settings.url . quote
  if has_key(a:settings, 'data')
    let a:settings._file.post = s:_make_postfile(a:settings.data)
    let command .= ' --post-file=' . quote . a:settings._file.post . quote
  endif

  call s:Process.system(command)
  let retcode = s:Process.get_last_status()

  if filereadable(a:settings._file.header)
    let header_lines = readfile(a:settings._file.header, 'b')
    call map(header_lines, 'matchstr(v:val, "^\\s*\\zs.*")')
    let headerstr = join(header_lines, "\r\n")
    let header_chunks = split(headerstr, '\r\n\zeHTTP/1\.\d')
    let headers = map(header_chunks, 'split(v:val, "\r\n")')
    let responses = map(headers, '[v:val, ""]')
  else
    let headers = []
    let responses = [[[], '']]
  endif
  if has_key(s:clients.wget.errcode, retcode) && empty(headers)
    throw 'vital: Web.HTTP: ' . s:clients.wget.errcode[retcode]
  endif
  if has_output_file
    let content = ''
  else
    let content = s:_readfile(output_file)
  endif
  let responses[-1][1] = content
  return responses
endfunction

function! s:_quote() abort
  return &shellxquote ==# '"' ?  "'" : '"'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
