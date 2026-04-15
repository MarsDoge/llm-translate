" autoload/llm_translate.vim — lazy-loaded implementation
" Loaded on first call to llm_translate#* functions.

function! s:BuildCmd() abort
  let l:parts = [shellescape(g:llm_translate_cmd),
        \ '-p', shellescape(g:llm_translate_provider),
        \ '-t', shellescape(g:llm_translate_target),
        \ '-s', shellescape(g:llm_translate_source)]
  if !empty(g:llm_translate_model)
    call extend(l:parts, ['-m', shellescape(g:llm_translate_model)])
  endif
  return join(l:parts, ' ')
endfunction

function! s:OpenResultBuffer(lines, title) abort
  execute g:llm_translate_split . ' new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  execute 'setlocal filetype=' . g:llm_translate_filetype
  call setline(1, a:lines)
  normal! gg
  execute 'file ' . fnameescape(a:title)
endfunction

function! s:Run(text) abort
  if empty(a:text)
    echohl WarningMsg | echo 'llm-translate: empty input' | echohl None
    return
  endif
  let l:cmd = s:BuildCmd()
  let l:result = system(l:cmd, a:text)
  if v:shell_error != 0
    echohl ErrorMsg
    echo 'llm-translate failed (' . v:shell_error . '): ' . l:result
    echohl None
    return
  endif
  call s:OpenResultBuffer(split(l:result, "\n", 1),
        \ '[llm-translate:' . g:llm_translate_provider . ']')
endfunction

function! llm_translate#selection() range abort
  let l:save_reg  = getreg('"')
  let l:save_type = getregtype('"')
  silent normal! gvy
  let l:text = @"
  call setreg('"', l:save_reg, l:save_type)
  call s:Run(l:text)
endfunction

function! llm_translate#buffer() abort
  call s:Run(join(getline(1, '$'), "\n"))
endfunction
