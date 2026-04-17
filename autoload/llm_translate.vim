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

" --- code tasks (optimize, bugfix) ----------------------------------------
" Both open a two-pane diff in a fresh tab: left = original, right = rewritten.

function! s:RunCodeTask(task, text, ft) abort
  if empty(a:text)
    echohl WarningMsg | echo 'llm-translate: empty input' | echohl None
    return
  endif
  let l:cmd = s:BuildCmd(a:task)
  echo 'llm-translate: ' . a:task . ' via ' . g:llm_translate_provider . '…'
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
  " Dedicated tab so the user's layout stays intact. :tabclose to exit.
  tabnew
  call s:FillScratch(l:before, '[' . a:task . ':original]', l:ft)
  diffthis
  vnew
  call s:FillScratch(l:after,
        \ '[' . a:task . ':' . g:llm_translate_provider . ']',
        \ l:ft)
  diffthis
  wincmd h
endfunction

function! llm_translate#optimize() range abort
  call s:RunCodeTask('optimize', s:CaptureSelection(), &filetype)
endfunction

function! llm_translate#optimize_buffer() abort
  call s:RunCodeTask('optimize', join(getline(1, '$'), "\n"), &filetype)
endfunction

function! llm_translate#bugfix() range abort
  call s:RunCodeTask('bugfix', s:CaptureSelection(), &filetype)
endfunction

function! llm_translate#bugfix_buffer() abort
  call s:RunCodeTask('bugfix', join(getline(1, '$'), "\n"), &filetype)
endfunction

" --- mindmap task ---------------------------------------------------------
" Gather ctags / cscope / grep context for a symbol and ask the LLM to emit
" a Mermaid flowchart of its callers and callees. The scratch buffer holds
" the raw Mermaid source. If g:llm_translate_mindmap_render is 'png' and
" `mmdc` is on $PATH, render to a temp PNG and open it with xdg-open.

function! s:GatherSymbolContext(sym) abort
  let l:lines = ['SYMBOL: ' . a:sym, '']

  " 1. Definitions via Vim's own tag database (populated by ctags).
  try
    let l:tags = taglist('^' . a:sym . '$')
  catch
    let l:tags = []
  endtry
  if !empty(l:tags)
    call add(l:lines, 'DEFINITIONS (ctags):')
    for l:t in l:tags[:9]
      let l:kind = get(l:t, 'kind', '?')
      let l:file = get(l:t, 'filename', '?')
      let l:cmd  = substitute(get(l:t, 'cmd', ''), '^/\^\?\|\$\?/$', '', 'g')
      call add(l:lines, printf('  %s  %s  %s  %s', l:kind, l:file, a:sym, l:cmd))
    endfor
    call add(l:lines, '')
  endif

  " 2. cscope callers/callees, if a cscope.out is reachable.
  if has('cscope') && filereadable(findfile('cscope.out', '.;'))
    let l:callers = systemlist('cscope -dL -3 ' . shellescape(a:sym) . ' 2>/dev/null')
    if !empty(l:callers)
      call add(l:lines, 'CALLERS (cscope):')
      for l:c in l:callers[:14]
        call add(l:lines, '  ' . l:c)
      endfor
      call add(l:lines, '')
    endif
    let l:callees = systemlist('cscope -dL -2 ' . shellescape(a:sym) . ' 2>/dev/null')
    if !empty(l:callees)
      call add(l:lines, 'CALLEES (cscope):')
      for l:c in l:callees[:14]
        call add(l:lines, '  ' . l:c)
      endfor
      call add(l:lines, '')
    endif
  endif

  " 3. Fallback: coarse reference list via grep. Bounded so the prompt
  "    doesn't explode on common identifiers.
  if executable('grep')
    let l:grep = 'grep -rn --binary-files=without-match'
          \ . " --exclude-dir=.git --exclude-dir=node_modules"
          \ . ' -w ' . shellescape(a:sym) . ' . 2>/dev/null | head -30'
    let l:refs = systemlist(l:grep)
    if !empty(l:refs)
      call add(l:lines, 'REFERENCES (grep -w):')
      for l:r in l:refs
        call add(l:lines, '  ' . l:r)
      endfor
    endif
  endif

  return join(l:lines, "\n")
endfunction

function! s:MindmapCmd(fmt) abort
  let l:parts = [shellescape(g:llm_translate_cmd),
        \ '-p', shellescape(g:llm_translate_provider),
        \ '--task', shellescape('mindmap'),
        \ '--format', shellescape(a:fmt)]
  if !empty(g:llm_translate_model)
    call extend(l:parts, ['-m', shellescape(g:llm_translate_model)])
  endif
  return join(l:parts, ' ')
endfunction

function! s:MaybeRenderGraph(src_path, fmt) abort
  if g:llm_translate_mindmap_render !=# 'png'
    return
  endif
  if a:fmt ==# 'mermaid'
    let l:tool = 'mmdc'
    let l:png = substitute(a:src_path, '\.mmd$', '.png', '')
    let l:cmd = 'mmdc -i ' . shellescape(a:src_path)
          \ . ' -o ' . shellescape(l:png) . ' 2>&1'
  else
    let l:tool = 'dot'
    let l:png = substitute(a:src_path, '\.dot$', '.png', '')
    let l:cmd = 'dot -Tpng ' . shellescape(a:src_path)
          \ . ' -o ' . shellescape(l:png) . ' 2>&1'
  endif
  if !executable(l:tool)
    echohl WarningMsg
    echo 'llm-translate: g:llm_translate_mindmap_render=png but '
          \ . l:tool . ' not found on $PATH'
    echohl None
    return
  endif
  let l:out = system(l:cmd)
  if v:shell_error != 0
    echohl ErrorMsg | echo l:tool . ' failed: ' . l:out | echohl None
    return
  endif
  let l:opener = executable('xdg-open') ? 'xdg-open'
        \ : (executable('open') ? 'open' : '')
  if empty(l:opener)
    echo 'llm-translate: rendered ' . l:png . ' (no opener on $PATH; open it manually)'
    return
  endif
  call system(l:opener . ' ' . shellescape(l:png) . ' >/dev/null 2>&1 &')
  echo 'llm-translate: opened ' . l:png
endfunction

function! s:RunMindmap(sym) abort
  let l:sym = trim(a:sym)
  if empty(l:sym)
    echohl WarningMsg | echo 'llm-translate: no symbol under cursor' | echohl None
    return
  endif
  let l:fmt = g:llm_translate_mindmap_format
  if l:fmt !=# 'mermaid' && l:fmt !=# 'dot'
    echohl ErrorMsg
    echo 'llm-translate: g:llm_translate_mindmap_format must be "mermaid" or "dot" (got '
          \ . l:fmt . ')'
    echohl None
    return
  endif
  echo 'llm-translate: mindmap (' . l:fmt . ') for ' . l:sym
        \ . ' via ' . g:llm_translate_provider . '…'
  let l:context = s:GatherSymbolContext(l:sym)
  let l:result = system(s:MindmapCmd(l:fmt), l:context)
  redraw | echo ''
  if v:shell_error != 0
    echohl ErrorMsg
    echo 'llm-translate mindmap failed (' . v:shell_error . '): ' . l:result
    echohl None
    return
  endif

  let l:lines = split(l:result, "\n", 1)
  let l:ext = l:fmt ==# 'mermaid' ? '.mmd' : '.dot'
  let l:tmp = tempname() . l:ext
  call writefile(l:lines, l:tmp)

  execute g:llm_translate_split . ' new'
  call s:FillScratch(l:lines, '[mindmap:' . l:fmt . ':' . l:sym . ']', l:fmt)

  call s:MaybeRenderGraph(l:tmp, l:fmt)
endfunction

function! llm_translate#mindmap() abort
  call s:RunMindmap(expand('<cword>'))
endfunction

function! llm_translate#mindmap_selection() range abort
  call s:RunMindmap(s:CaptureSelection())
endfunction
