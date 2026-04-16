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
"   let g:llm_translate_map_optimize = 1               " set 0 to disable default <leader>o

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
let g:llm_translate_map_optimize = get(g:, 'llm_translate_map_optimize', 1)

command! -range LLMTranslate          call llm_translate#selection()
command!        LLMTranslateBuffer    call llm_translate#buffer()
command! -range LLMOptimize           call llm_translate#optimize()
command!        LLMOptimizeBuffer     call llm_translate#optimize_buffer()

if g:llm_translate_map
  if !hasmapto('<Plug>LLMTranslate', 'x')
    xnoremap <silent> <leader>t :<C-u>call llm_translate#selection()<CR>
  endif
endif

if g:llm_translate_map_optimize
  if !hasmapto('<Plug>LLMOptimize', 'x')
    xnoremap <silent> <leader>o :<C-u>call llm_translate#optimize()<CR>
  endif
endif
