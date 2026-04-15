" llm-translate.vim — translate selection / buffer via llm-translate CLI
" https://github.com/MarsDoge/llm-translate
"
" Configuration (set in your .vimrc before loading):
"   let g:llm_translate_cmd      = 'llm-translate'     " absolute path if not on $PATH
"   let g:llm_translate_provider = 'deepseek'          " deepseek | openai | claude | ollama
"   let g:llm_translate_model    = ''                  " empty → provider default
"   let g:llm_translate_target   = 'Simplified Chinese'
"   let g:llm_translate_source   = 'auto'
"   let g:llm_translate_split    = 'belowright'        " split modifier
"   let g:llm_translate_filetype = 'markdown'
"   let g:llm_translate_map      = 1                   " set 0 to disable default <leader>t

if exists('g:loaded_llm_translate')
  finish
endif
let g:loaded_llm_translate = 1

let g:llm_translate_cmd      = get(g:, 'llm_translate_cmd', 'llm-translate')
let g:llm_translate_provider = get(g:, 'llm_translate_provider', 'deepseek')
let g:llm_translate_model    = get(g:, 'llm_translate_model', '')
let g:llm_translate_target   = get(g:, 'llm_translate_target', 'Simplified Chinese')
let g:llm_translate_source   = get(g:, 'llm_translate_source', 'auto')
let g:llm_translate_split    = get(g:, 'llm_translate_split', 'belowright')
let g:llm_translate_filetype = get(g:, 'llm_translate_filetype', 'markdown')
let g:llm_translate_map      = get(g:, 'llm_translate_map', 1)

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

command! -range LLMTranslate       call llm_translate#selection()
command!        LLMTranslateBuffer call llm_translate#buffer()

if g:llm_translate_map
  if !hasmapto('<Plug>LLMTranslate', 'x')
    xnoremap <silent> <leader>t :<C-u>call llm_translate#selection()<CR>
  endif
endif
