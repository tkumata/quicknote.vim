" QuickNote root can be overridden before sourcing this file:
"   let g:quicknote_root = '~/Documents/QuickNote'
if exists('g:loaded_quicknote')
  finish
endif
let g:loaded_quicknote = 1

let s:quicknote_root = substitute(expand(get(g:, 'quicknote_root', '~/Documents/QuickNote')), '/$', '', '')
let s:quicknote_repo_root = fnamemodify(expand('<sfile>:p'), ':h:h')

function! s:quicknote_path(...) abort
  return join([s:quicknote_root] + a:000, '/')
endfunction

function! s:template_path(name) abort
  return s:quicknote_path('Templates', a:name)
endfunction

function! s:repo_path(...) abort
  return join([s:quicknote_repo_root] + a:000, '/')
endfunction

" fzf
let $FZF_DEFAULT_COMMAND = 'find ' . shellescape(s:quicknote_root) . ' -type f -name "*.md"'

augroup quicknote
  autocmd!
  autocmd FileType markdown nnoremap <buffer> <Enter> :call <SID>open_wiki_link()<CR>
  autocmd FileType markdown inoremap <buffer> <expr> ( <SID>pair('(', ')')
  autocmd FileType markdown inoremap <buffer> <expr> [ <SID>pair('[', ']')
  autocmd FileType markdown inoremap <buffer> <expr> { <SID>pair('{', '}')
augroup END

command! NoteToday call s:open_daily_note()
command! NoteInit call s:note_init()
command! -nargs=1 NoteLiterature call s:create_literature_note(<f-args>)
command! -nargs=1 NoteFleet call s:open_collection_note('Fleet', <q-args>)
command! NoteSearch call s:note_search()
command! -nargs=* NoteGrep call s:note_grep(<q-args>)
command! NoteBacklinks call s:note_backlinks()
command! NoteUnlinkedMentions call s:note_unlinked_mentions()
command! NoteOrphans call s:note_orphans()
command! NoteRelated call s:note_related()
command! NoteRandom call s:note_random()
command! NoteBrokenLinks call s:note_broken_links()
command! -nargs=1 NoteTag call s:note_tag(<q-args>)
command! NoteTags call s:note_tags()
command! NoteHelp call s:note_help()

function! s:pair(open, close) abort
  return a:open . a:close . "\<Left>"
endfunction

function! s:note_init() abort
  try
    call s:ensure_directory(s:quicknote_root)
    for l:directory in ['Daily', 'Fleet', 'Literature']
      call s:ensure_directory(s:quicknote_path(l:directory))
    endfor

    call s:copy_templates()
    echo 'QuickNote initialized: ' . s:quicknote_root
  catch
    call s:show_error('NoteInit failed: ' . v:exception)
  endtry
endfunction

function! s:open_wiki_link() abort
  let l:link_text = s:link_under_cursor()

  if empty(l:link_text)
    echoerr 'No valid [[link]] found under cursor!'
    return
  endif

  let l:file = s:normalize_note_name(l:link_text)
  if empty(l:file)
    call s:show_error('No valid [[link]] found under cursor!')
    return
  endif

  let l:find_cmd = 'find ' . shellescape(s:quicknote_root) . ' -type f -name ' . shellescape(l:file)
  let l:found_files = systemlist(l:find_cmd)

  if len(l:found_files) == 0
    call s:open_collection_note('Fleet', l:link_text)
  elseif len(l:found_files) == 1
    execute 'edit ' . fnameescape(l:found_files[0])
  elseif s:has_fzf_picker()
    let l:previous_window = winnr('#')
    call fzf#run(fzf#wrap({
      \ 'source': l:found_files,
      \ 'sink': function('<SID>open_note_from_picker', [l:previous_window])
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
  let l:filename = s:normalize_note_name(a:name)
  if empty(l:filename)
    call s:show_error('Note name is empty')
    return
  endif

  let l:title = s:note_title_from_name(l:filename)
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

function! s:open_collection_note(collection, name) abort
  let l:filename = s:normalize_note_name(a:name)
  if empty(l:filename)
    call s:show_error('Note name is empty')
    return
  endif

  let l:title = s:note_title_from_name(l:filename)
  let l:target_dir = s:quicknote_path(a:collection)
  let l:filepath = s:quicknote_path(a:collection, l:filename)

  call s:ensure_directory(l:target_dir)

  if !filereadable(l:filepath)
    call s:create_basic_note(l:filepath, l:title)
    echo 'Note created: ' . l:filepath
  else
    echo 'Note already exists: ' . l:filepath
  endif

  execute 'edit ' . fnameescape(l:filepath)
endfunction

function! s:note_search() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteSearch')
    return
  endif

  let l:source = systemlist(s:markdown_find_command())
  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap({
    \ 'source': l:source,
    \ 'sink': function('<SID>open_note_from_picker', [l:previous_window]),
    \ 'options': '--prompt=NoteSearch> '
    \ }))
endfunction

function! s:note_grep(query) abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteGrep')
    return
  endif

  let l:query = s:trim(a:query)
  if empty(l:query)
    let l:query = input('NoteGrep: ')
    if empty(s:trim(l:query))
      return
    endif
  endif

  let l:results = systemlist(s:grep_command(l:query))
  if v:shell_error > 1
    call s:show_error('grep failed for :NoteGrep')
    return
  endif
  if empty(l:results)
    echo 'No matches: ' . l:query
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteGrep', {
    \ 'source': l:results,
    \ 'sink': function('<SID>open_grep_result', [l:previous_window]),
    \ 'options': ['--prompt=NoteGrep> ', '--delimiter=:', '--nth=1,2,3..']
    \ }))
endfunction

function! s:note_backlinks() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteBacklinks')
    return
  endif

  let l:names = s:current_note_names()
  if empty(l:names)
    call s:show_error('Current buffer is not a QuickNote markdown file')
    return
  endif

  let l:results = []
  for l:name in l:names
    let l:results += systemlist(s:grep_fixed_command('[[' . l:name . ']]'))
    if v:shell_error > 1
      call s:show_error('grep failed for :NoteBacklinks')
      return
    endif
  endfor

  let l:results = s:unique_lines(l:results)
  if empty(l:results)
    echo 'No backlinks: ' . join(l:names, ', ')
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteBacklinks', {
    \ 'source': l:results,
    \ 'sink': function('<SID>open_grep_result', [l:previous_window]),
    \ 'options': ['--prompt=NoteBacklinks> ', '--delimiter=:', '--nth=1,2,3..']
    \ }))
endfunction

function! s:note_unlinked_mentions() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteUnlinkedMentions')
    return
  endif

  if !s:is_discovery_note_file()
    call s:show_error('Current buffer is not an eligible QuickNote markdown file')
    return
  endif

  let l:names = s:current_note_names()
  let l:files = s:discovery_markdown_files()
  if v:shell_error != 0
    call s:show_error('find failed for :NoteUnlinkedMentions')
    return
  endif

  let l:results = s:unlinked_mention_results(l:files, expand('%:p'), l:names)
  if empty(l:results)
    echo 'No unlinked mentions: ' . join(l:names, ', ')
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteUnlinkedMentions', {
    \ 'source': l:results,
    \ 'sink': function('<SID>open_grep_result', [l:previous_window]),
    \ 'options': ['--prompt=NoteUnlinkedMentions> ', '--delimiter=:', '--nth=1,2,3..']
    \ }))
endfunction

function! s:note_orphans() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteOrphans')
    return
  endif

  let l:files = s:discovery_markdown_files()
  if v:shell_error != 0
    call s:show_error('find failed for :NoteOrphans')
    return
  endif

  let l:source = s:orphan_note_files(l:files)
  if empty(l:source)
    echo 'No orphan notes'
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteOrphans', {
    \ 'source': l:source,
    \ 'sink': function('<SID>open_note_from_picker', [l:previous_window]),
    \ 'options': '--prompt=NoteOrphans> '
    \ }))
endfunction

function! s:note_related() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteRelated')
    return
  endif

  if !s:is_discovery_note_file()
    call s:show_error('Current buffer is not an eligible QuickNote markdown file')
    return
  endif

  let l:tags = s:frontmatter_tags(expand('%:p'))
  if empty(l:tags)
    echo 'Current note has no tags'
    return
  endif

  let l:files = s:discovery_markdown_files()
  if v:shell_error != 0
    call s:show_error('find failed for :NoteRelated')
    return
  endif

  let l:source = s:related_note_files(l:files, expand('%:p'), l:tags)
  if empty(l:source)
    echo 'No related notes'
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteRelated', {
    \ 'source': l:source,
    \ 'sink': function('<SID>open_note_from_picker', [l:previous_window]),
    \ 'options': '--prompt=NoteRelated> '
    \ }))
endfunction

function! s:note_random() abort
  let l:files = s:discovery_markdown_files()
  if v:shell_error != 0
    call s:show_error('find failed for :NoteRandom')
    return
  endif
  if empty(l:files)
    echo 'No notes available for :NoteRandom'
    return
  endif

  execute 'edit ' . fnameescape(l:files[rand() % len(l:files)])
endfunction

function! s:note_broken_links() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteBrokenLinks')
    return
  endif

  let l:files = systemlist(s:markdown_find_command())
  if v:shell_error != 0
    call s:show_error('find failed for :NoteBrokenLinks')
    return
  endif

  let l:results = s:broken_link_results(l:files)
  if empty(l:results)
    echo 'No broken links'
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteBrokenLinks', {
    \ 'source': l:results,
    \ 'sink': function('<SID>open_grep_result', [l:previous_window]),
    \ 'options': ['--prompt=NoteBrokenLinks> ', '--delimiter=:', '--nth=1,2,3..']
    \ }))
endfunction

function! s:note_tag(tag) abort
  let l:tag = s:trim(a:tag)
  if empty(l:tag)
    call s:show_error('Tag is empty')
    return
  endif

  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteTag')
    return
  endif

  let l:previous_window = winnr('#')
  call s:open_tagged_notes(l:tag, l:previous_window)
endfunction

function! s:note_tags() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteTags')
    return
  endif

  let l:source = s:all_note_tags()
  if empty(l:source)
    echo 'No tags found'
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteTags', {
    \ 'source': l:source,
    \ 'sink': function('<SID>open_tag_from_picker', [l:previous_window]),
    \ 'options': '--prompt=NoteTags> '
    \ }))
endfunction

function! s:note_help() abort
  if !s:has_fzf_picker()
    call s:show_error('FZF is required for :NoteHelp')
    return
  endif

  let l:previous_window = winnr('#')
  call fzf#run(fzf#wrap('NoteHelp', {
    \ 'source': s:note_help_lines(),
    \ 'sink': function('<SID>ignore_selection'),
    \ 'exit': function('<SID>restore_previous_window', [l:previous_window]),
    \ 'options': '--prompt=NoteHelp> '
    \ }))
endfunction

function! s:note_help_lines() abort
  return [
    \ ':NoteInit                    QuickNote root と標準ディレクトリ、template を初期化する',
    \ ':NoteToday                   今日の Daily note を開く',
    \ ':NoteLiterature {name}       指定名の Literature note を開く',
    \ ':NoteFleet {name}            指定名の Fleet note を開く',
    \ ':NoteSearch                  markdown note をファイル名から検索して開く',
    \ ':NoteGrep [query]            note 本文を検索して該当行を開く',
    \ ':NoteBacklinks               現在の note への wiki link を検索する',
    \ ':NoteUnlinkedMentions        現在の note 名の未リンク言及を検索する',
    \ ':NoteOrphans                 backlink のない note を検索する',
    \ ':NoteRelated                 現在の note と tag が共通する note を検索する',
    \ ':NoteRandom                  対象 note から1件をランダムに開く',
    \ ':NoteBrokenLinks             存在しない wiki link を検索する',
    \ ':NoteTag {tag}               指定 tag を持つ note を検索する',
    \ ':NoteTags                    tag を選択して該当 note を検索する',
    \ ':NoteHelp                    QuickNote コマンド一覧を表示する'
    \ ]
endfunction

function! s:ignore_selection(selection) abort
endfunction

function! s:open_tag_from_picker(previous_window, tag) abort
  call s:open_tagged_notes(a:tag, a:previous_window)
endfunction

function! s:open_tagged_notes(tag, previous_window) abort
  let l:tag = s:trim(a:tag)
  if empty(l:tag)
    call s:show_error('Tag is empty')
    return
  endif

  let l:source = s:tagged_note_files(l:tag)
  if empty(l:source)
    echo 'No notes tagged: ' . l:tag
    return
  endif

  call fzf#run(fzf#wrap('NoteTag', {
    \ 'source': l:source,
    \ 'sink': function('<SID>open_note_from_picker', [a:previous_window]),
    \ 'options': '--prompt=NoteTag> '
    \ }))
endfunction

function! s:ensure_directory(path) abort
  if !isdirectory(a:path)
    call mkdir(a:path, 'p')
  endif
  if !isdirectory(a:path)
    throw 'Could not create directory: ' . a:path
  endif
endfunction

function! s:copy_templates() abort
  let l:source_dir = s:repo_path('Templates')
  let l:target_dir = s:quicknote_path('Templates')

  if !isdirectory(l:source_dir)
    throw 'Template directory not found: ' . l:source_dir
  endif

  call s:ensure_directory(l:target_dir)
  for l:name in readdir(l:source_dir)
    let l:source = l:source_dir . '/' . l:name
    let l:target = l:target_dir . '/' . l:name
    if filereadable(l:source) && !filereadable(l:target)
      call writefile(readfile(l:source), l:target)
    endif
  endfor
endfunction

function! s:create_basic_note(filepath, title) abort
  call writefile(['# ' . a:title, '', 'Created: ' . strftime('%Y-%m-%d %H:%M'), ''], a:filepath)
endfunction

function! s:write_template(template, filepath, title) abort
  let l:lines = readfile(a:template)
  let l:processed = map(l:lines, { _, line -> s:apply_template(line, a:title) })
  call writefile(l:processed, a:filepath)
endfunction

function! s:normalize_note_name(name) abort
  let l:name = s:trim(a:name)
  let l:name = substitute(l:name, '[\\/]', '-', 'g')
  if empty(l:name)
    return ''
  endif

  return l:name =~# '\.md$' ? l:name : l:name . '.md'
endfunction

function! s:note_title_from_name(name) abort
  return substitute(a:name, '\.md$', '', '')
endfunction

function! s:current_note_names() abort
  let l:filename = expand('%:t')
  if !s:is_quicknote_markdown_file() || empty(l:filename)
    return []
  endif

  return s:unique_trimmed_values([
    \ s:note_title_from_name(l:filename),
    \ s:first_markdown_title()
    \ ])
endfunction

function! s:is_quicknote_markdown_file() abort
  let l:filepath = expand('%:p')
  if empty(l:filepath) || expand('%:e') !=# 'md'
    return 0
  endif

  let l:root = substitute(fnamemodify(s:quicknote_root, ':p'), '/$', '', '') . '/'
  return l:filepath[:strlen(l:root) - 1] ==# l:root
endfunction

function! s:is_discovery_note_file() abort
  return s:is_quicknote_markdown_file() && !s:is_discovery_excluded_path(expand('%:p'))
endfunction

function! s:first_markdown_title() abort
  for l:line in getline(1, '$')
    if l:line =~# '^#\s\+'
      return s:trim(substitute(l:line, '^#\s\+', '', ''))
    endif
  endfor

  return ''
endfunction

function! s:unique_trimmed_values(values) abort
  let l:seen = {}
  let l:unique = []
  for l:value in a:values
    let l:value = s:trim(l:value)
    if empty(l:value) || has_key(l:seen, l:value)
      continue
    endif
    let l:seen[l:value] = 1
    call add(l:unique, l:value)
  endfor

  return l:unique
endfunction

function! s:unique_lines(lines) abort
  let l:seen = {}
  let l:unique = []
  for l:line in a:lines
    if empty(l:line) || has_key(l:seen, l:line)
      continue
    endif
    let l:seen[l:line] = 1
    call add(l:unique, l:line)
  endfor

  return l:unique
endfunction

function! s:unlinked_mention_results(files, current_file, names) abort
  let l:current_file = fnamemodify(a:current_file, ':p')
  let l:results = []

  for l:file in a:files
    if fnamemodify(l:file, ':p') ==# l:current_file || !filereadable(l:file)
      continue
    endif

    try
      let l:lines = readfile(l:file)
    catch
      continue
    endtry

    for l:index in range(len(l:lines))
      let l:text = s:line_without_wiki_links(l:lines[l:index])
      for l:name in a:names
        if stridx(l:text, l:name) >= 0
          call add(l:results, l:file . ':' . (l:index + 1) . ':' . l:lines[l:index])
          break
        endif
      endfor
    endfor
  endfor

  return s:unique_lines(l:results)
endfunction

function! s:line_without_wiki_links(line) abort
  return substitute(a:line, '\[\[.\{-}\]\]', '', 'g')
endfunction

function! s:orphan_note_files(files) abort
  " ponytail: scan per candidate; build an incoming-name index only if Vault size makes this slow.
  let l:orphans = []
  for l:file in a:files
    let l:names = s:note_names_from_file(l:file)
    if !empty(l:names) && !s:has_backlink(a:files, l:file, l:names)
      call add(l:orphans, l:file)
    endif
  endfor
  return sort(l:orphans)
endfunction

function! s:note_names_from_file(file) abort
  if !filereadable(a:file)
    return []
  endif

  try
    let l:lines = readfile(a:file)
  catch
    return []
  endtry

  let l:names = [s:note_title_from_name(fnamemodify(a:file, ':t'))]
  for l:line in l:lines
    if l:line =~# '^#\s\+'
      call add(l:names, s:trim(substitute(l:line, '^#\s\+', '', '')))
      break
    endif
  endfor
  return s:unique_trimmed_values(l:names)
endfunction

function! s:has_backlink(files, candidate, names) abort
  let l:candidate = fnamemodify(a:candidate, ':p')
  for l:file in a:files
    if fnamemodify(l:file, ':p') ==# l:candidate || !filereadable(l:file)
      continue
    endif

    try
      let l:text = join(readfile(l:file), "\n")
    catch
      continue
    endtry

    for l:name in a:names
      if stridx(l:text, '[[' . l:name . ']]') >= 0
        return 1
      endif
    endfor
  endfor
  return 0
endfunction

function! s:related_note_files(files, current_file, tags) abort
  let l:current_file = fnamemodify(a:current_file, ':p')
  let l:related = []
  for l:file in a:files
    if fnamemodify(l:file, ':p') ==# l:current_file
      continue
    endif
    for l:tag in s:frontmatter_tags(l:file)
      if index(a:tags, l:tag) >= 0
        call add(l:related, l:file)
        break
      endif
    endfor
  endfor
  return sort(s:unique_lines(l:related))
endfunction

function! s:broken_link_results(files) abort
  let l:note_names = s:note_file_name_index(a:files)
  let l:results = []

  for l:file in a:files
    if !filereadable(l:file)
      continue
    endif

    try
      let l:lines = readfile(l:file)
    catch
      continue
    endtry

    for l:index in range(0, len(l:lines) - 1)
      for l:link in s:wiki_links_in_line(l:lines[l:index])
        let l:filename = s:normalize_note_name(l:link)
        if !empty(l:filename) && !has_key(l:note_names, l:filename)
          call add(l:results, l:file . ':' . (l:index + 1) . ':' . l:lines[l:index])
          break
        endif
      endfor
    endfor
  endfor

  return s:unique_lines(l:results)
endfunction

function! s:note_file_name_index(files) abort
  let l:names = {}
  for l:file in a:files
    let l:names[fnamemodify(l:file, ':t')] = 1
  endfor
  return l:names
endfunction

function! s:wiki_links_in_line(line) abort
  let l:links = []
  let l:start = 0

  while 1
    let l:matches = matchlist(a:line, '\[\[\(.\{-}\)\]\]', l:start)
    if empty(l:matches)
      return l:links
    endif

    call add(l:links, s:trim(l:matches[1]))
    let l:link_start = match(a:line, '\[\[\(.\{-}\)\]\]', l:start)
    let l:start = l:link_start + strlen(l:matches[0])
  endwhile
endfunction

function! s:tagged_note_files(tag) abort
  let l:files = systemlist(s:markdown_find_command())
  if v:shell_error != 0
    return []
  endif

  let l:tagged_files = []
  for l:file in l:files
    if s:note_has_frontmatter_tag(l:file, a:tag)
      call add(l:tagged_files, l:file)
    endif
  endfor

  return l:tagged_files
endfunction

function! s:all_note_tags() abort
  let l:files = systemlist(s:markdown_find_command())
  if v:shell_error != 0
    return []
  endif

  let l:tags = []
  for l:file in l:files
    let l:tags += s:frontmatter_tags(l:file)
  endfor

  return sort(s:unique_trimmed_values(l:tags))
endfunction

function! s:note_has_frontmatter_tag(file, tag) abort
  return index(s:frontmatter_tags(a:file), a:tag) >= 0
endfunction

function! s:frontmatter_tags(file) abort
  if !filereadable(a:file)
    return []
  endif

  try
    let l:lines = readfile(a:file)
  catch
    return []
  endtry

  if empty(l:lines) || l:lines[0] !~# '^---\s*$'
    return []
  endif

  let l:in_tags = 0
  let l:tags = []
  for l:line in l:lines[1:]
    if l:line =~# '^---\s*$'
      return l:tags
    endif

    if !l:in_tags
      if l:line =~# '^\s*tags:\s*$'
        let l:in_tags = 1
      endif
      continue
    endif

    let l:tag_match = matchlist(l:line, '^\s*-\s*\(.\{-}\)\s*$')
    if !empty(l:tag_match)
      call add(l:tags, s:trim(l:tag_match[1]))
      continue
    endif

    if l:line =~# '^\S.\{-}:\s*.*$'
      return l:tags
    endif
  endfor

  return l:tags
endfunction

function! s:trim(value) abort
  return substitute(a:value, '^\s*\|\s*$', '', 'g')
endfunction

function! s:markdown_find_command() abort
  return 'find ' . shellescape(s:quicknote_root) . ' -type f -name ' . shellescape('*.md')
endfunction

function! s:discovery_markdown_files() abort
  return filter(systemlist(s:markdown_find_command()), '!s:is_discovery_excluded_path(v:val)')
endfunction

function! s:is_discovery_excluded_path(path) abort
  let l:path = fnamemodify(a:path, ':p')
  let l:root = substitute(fnamemodify(s:quicknote_root, ':p'), '/$', '', '')
  for l:directory in ['Daily', 'Templates']
    let l:prefix = l:root . '/' . l:directory . '/'
    if l:path[:strlen(l:prefix) - 1] ==# l:prefix
      return 1
    endif
  endfor
  return 0
endfunction

function! s:grep_command(query) abort
  return 'grep -RIn --include=' . shellescape('*.md') . ' -- ' . shellescape(a:query) . ' ' . shellescape(s:quicknote_root)
endfunction

function! s:grep_fixed_command(query) abort
  return 'grep -RInF --include=' . shellescape('*.md') . ' -- ' . shellescape(a:query) . ' ' . shellescape(s:quicknote_root)
endfunction

function! s:has_fzf_picker() abort
  return exists(':FZF')
endfunction

function! s:show_error(message) abort
  echohl ErrorMsg
  echom a:message
  echohl None
endfunction

function! s:open_note_from_picker(previous_window, file) abort
  execute 'edit ' . fnameescape(a:file)
  call s:restore_previous_window(a:previous_window)
endfunction

function! s:restore_previous_window(previous_window, ...) abort
  let l:current_window = winnr()
  if a:previous_window <= 0 || a:previous_window > winnr('$') || a:previous_window == l:current_window
    return
  endif

  execute a:previous_window . 'wincmd w'
  execute l:current_window . 'wincmd w'
endfunction

function! s:open_grep_result(previous_window, line) abort
  let l:match = matchlist(a:line, '^\(.\{-}\):\([0-9]\+\):')
  if empty(l:match)
    call s:show_error('Invalid grep result: ' . a:line)
    return
  endif

  let l:file = l:match[1]
  let l:line_number = str2nr(l:match[2])
  if !filereadable(l:file)
    call s:show_error('Grep result file not found: ' . l:file)
    return
  endif

  execute 'edit ' . fnameescape(l:file)
  execute l:line_number
  normal! zz
  call s:restore_previous_window(a:previous_window)
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
