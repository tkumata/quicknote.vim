" QuickNote root can be overridden before sourcing this file:
"   let g:quicknote_root = '~/Documents/QuickNote'
let s:quicknote_root = substitute(expand(get(g:, 'quicknote_root', '~/Documents/QuickNote')), '/$', '', '')

function! s:quicknote_path(...) abort
  return join([s:quicknote_root] + a:000, '/')
endfunction

function! s:template_path(name) abort
  return s:quicknote_path('Templates', a:name)
endfunction

" Vimwiki
let g:vimwiki_list = [{
  \ 'path': s:quicknote_root . '/',
  \ 'syntax': 'markdown',
  \ 'ext': '.md'
  \}]
let g:vimwiki_key_mappings = { 'all_maps': 0 }

" fzf
let $FZF_DEFAULT_COMMAND = 'find ' . shellescape(s:quicknote_root) . ' -type f -name "*.md"'

augroup quicknote
  autocmd!
  autocmd FileType markdown nnoremap <buffer> <Enter> :call <SID>open_wiki_link()<CR>
augroup END

command! NoteToday call s:open_daily_note()
command! -nargs=1 NoteLiterature call s:create_literature_note(<f-args>)

function! s:open_wiki_link() abort
  let l:link_text = s:link_under_cursor()

  if empty(l:link_text)
    echoerr 'No valid [[link]] found under cursor!'
    return
  endif

  let l:file = l:link_text . '.md'
  let l:find_cmd = 'find ' . shellescape(s:quicknote_root) . ' -type f -name ' . shellescape(l:file)
  let l:found_files = systemlist(l:find_cmd)

  if len(l:found_files) == 0
    echoerr 'File ' . l:file . ' not found in ' . s:quicknote_root
  elseif len(l:found_files) == 1
    execute 'edit ' . fnameescape(l:found_files[0])
  elseif exists(':FZF')
    call fzf#run(fzf#wrap({
      \ 'source': l:found_files,
      \ 'sink': 'edit'
      \ }))
  else
    echo 'Multiple files found: ' . join(l:found_files, ', ')
  endif
endfunction

function! s:link_under_cursor() abort
  let l:line = getline('.')
  let l:cursor_col = col('.') - 1
  let l:start = 0

  while 1
    let l:matches = matchlist(l:line, '\[\[\(.\{-}\)\]\]', l:start)
    if empty(l:matches)
      return ''
    endif

    let l:link_start = match(l:line, '\[\[\(.\{-}\)\]\]', l:start)
    let l:link_end = l:link_start + strlen(l:matches[0])
    if l:cursor_col >= l:link_start && l:cursor_col <= l:link_end
      return l:matches[1]
    endif

    let l:start = l:link_end
  endwhile
endfunction

function! s:open_daily_note() abort
  let l:target_dir = s:quicknote_path('Daily')
  let l:title = strftime('%Y-%m-%d')
  let l:filepath = s:quicknote_path('Daily', l:title . '.md')

  call s:ensure_directory(l:target_dir)

  if !filereadable(l:filepath)
    let l:template = s:template_path('Daily.md')
    if filereadable(l:template)
      call s:write_template(l:template, l:filepath, l:title)
    endif
  endif

  execute 'edit ' . fnameescape(l:filepath)
  call s:jump_to_cursor_token()
endfunction

function! s:create_literature_note(name) abort
  let l:target_dir = s:quicknote_path('Literature')
  let l:title = a:name
  let l:filename = l:title =~# '\.md$' ? l:title : l:title . '.md'
  let l:filepath = s:quicknote_path('Literature', l:filename)
  let l:template = s:template_path('Literature.md')

  call s:ensure_directory(l:target_dir)

  if !filereadable(l:filepath)
    if filereadable(l:template)
      call s:write_template(l:template, l:filepath, l:title)
      echo 'Note created: ' . l:filepath
    else
      echohl ErrorMsg
      echom 'Template not found: ' . l:template
      echohl None
      return
    endif
  else
    echo 'Note already exists: ' . l:filepath
  endif

  execute 'edit ' . fnameescape(l:filepath)
endfunction

function! s:ensure_directory(path) abort
  if !isdirectory(a:path)
    call mkdir(a:path, 'p')
  endif
endfunction

function! s:write_template(template, filepath, title) abort
  let l:lines = readfile(a:template)
  let l:processed = map(l:lines, { _, line -> s:apply_template(line, a:title) })
  call writefile(l:processed, a:filepath)
endfunction

function! s:jump_to_cursor_token() abort
  let l:lnum = search('{{cursor}}', 'nw')
  if l:lnum > 0
    execute l:lnum
    normal! ^
    execute 'normal! "_d2f{2x'
  endif
endfunction

function! s:apply_template(line, title) abort
  let l:line = a:line
  let l:line = substitute(l:line, '{{date:\(.\{-}\)}}', '\=strftime(s:convert_obsidian_date_format(submatch(1)))', 'g')
  let l:line = substitute(l:line, '{{date}}', strftime('%Y-%m-%d'), 'g')
  let l:line = substitute(l:line, '{{time:\(.\{-}\)}}', '\=strftime(s:convert_obsidian_date_format(submatch(1)))', 'g')
  let l:line = substitute(l:line, '{{time}}', strftime('%H:%M'), 'g')
  let l:line = substitute(l:line, '{{title}}', a:title, 'g')
  return l:line
endfunction

function! s:convert_obsidian_date_format(fmt) abort
  let l:format = a:fmt
  let l:format = substitute(l:format, 'YYYY', '%Y', 'g')
  let l:format = substitute(l:format, 'MM', '%m', 'g')
  let l:format = substitute(l:format, 'DD', '%d', 'g')
  let l:format = substitute(l:format, 'HH', '%H', 'g')
  let l:format = substitute(l:format, 'mm', '%M', 'g')
  let l:format = substitute(l:format, 'ss', '%S', 'g')
  let l:format = substitute(l:format, 'dddd', '%A', 'g')
  let l:format = substitute(l:format, 'ddd', '%a', 'g')
  return l:format
endfunction
