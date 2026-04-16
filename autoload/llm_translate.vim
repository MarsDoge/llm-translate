" autoload/llm_translate.vim — lazy-loaded implementation
" Loaded on first call to llm_translate#* functions.

function! s:BuildCmd(task) abort
  let l:parts = [shellescape(g:llm_translate_cmd),
        \ '-p', shellescape(g:llm_translate_provider),
        \ '--task', shellescape(a:task)]
  if a:task ==# 'translate'
    call extend(l:parts, [
          \ '-t', shellescape(g:llm_translate_target),
          \ '-s', shellescape(g:llm_translate_source)])
  endif
  if !empty(g:llm_translate_model)
    call extend(l:parts, ['-m', shellescape(g:llm_translate_model)])
  endif
  return join(l:parts, ' ')
endfunction

function! s:FillScratch(lines, title, ft) abort
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  execute 'setlocal filetype=' . a:ft
  call setline(1, a:lines)
  normal! gg
  execute 'file ' . fnameescape(a:title)
endfunction

function! s:OpenResultBuffer(lines, title) abort
  execute g:llm_translate_split . ' new'
  call s:FillScratch(a:lines, a:title, g:llm_translate_filetype)
endfunction

function! s:CaptureSelection() abort
  let l:save_reg  = getreg('"')
  let l:save_type = getregtype('"')
  silent normal! gvy
  let l:text = @"
  call setreg('"', l:save_reg, l:save_type)
  return l:text
endfunction

function! s:Run(text) abort
  if empty(a:text)
    echohl WarningMsg | echo 'llm-translate: empty input' | echohl None
    return
  endif
  let l:cmd = s:BuildCmd('translate')
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
  call s:Run(s:CaptureSelection())
endfunction

function! llm_translate#buffer() abort
  call s:Run(join(getline(1, '$'), "\n"))
endfunction

" --- optimize --------------------------------------------------------------

function! s:RunOptimize(text, ft) abort
  if empty(a:text)
    echohl WarningMsg | echo 'llm-translate: empty input' | echohl None
    return
  endif
  let l:cmd = s:BuildCmd('optimize')
  echo 'llm-translate: optimizing via ' . g:llm_translate_provider . '…'
  let l:result = system(l:cmd, a:text)
  redraw | echo ''
  if v:shell_error != 0
    echohl ErrorMsg
    echo 'llm-translate failed (' . v:shell_error . '): ' . l:result
    echohl None
    return
  endif
  let l:before = split(a:text, "\n", 1)
  let l:after  = split(l:result, "\n", 1)
  let l:ft = empty(a:ft) ? 'text' : a:ft
  " Open a dedicated tab so the user's layout stays intact. :tabclose to exit.
  tabnew
  call s:FillScratch(l:before, '[optimize:original]', l:ft)
  diffthis
  vnew
  call s:FillScratch(l:after,
        \ '[optimize:' . g:llm_translate_provider . ']',
        \ l:ft)
  diffthis
  wincmd h
endfunction

function! llm_translate#optimize() range abort
  call s:RunOptimize(s:CaptureSelection(), &filetype)
endfunction

function! llm_translate#optimize_buffer() abort
  call s:RunOptimize(join(getline(1, '$'), "\n"), &filetype)
endfunction
