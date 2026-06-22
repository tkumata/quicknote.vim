let s:repo = fnamemodify(expand('<sfile>:p'), ':h:h')
let g:quicknote_root = tempname()

execute 'source ' . fnameescape(s:repo . '/plugin/quicknote.vim')
call assert_equal(2, exists(':NoteHelp'))

call assert_match('FZF is required for :NoteHelp', execute('NoteHelp'))

let s:autoload = tempname()
call mkdir(s:autoload . '/autoload', 'p')
call writefile([
  \ 'function! fzf#wrap(...) abort',
  \ '  return a:0 == 1 ? a:1 : a:2',
  \ 'endfunction',
  \ 'function! fzf#run(spec) abort',
  \ '  let g:note_help_spec = a:spec',
  \ '  new',
  \ '  close',
  \ '  call call(a:spec.exit, [0])',
  \ '  call call(a:spec.sink, [a:spec.source[0]])',
  \ 'endfunction'
  \ ], s:autoload . '/autoload/fzf.vim')
execute 'set runtimepath^=' . fnameescape(s:autoload)
command! FZF echo

let s:buffer = bufnr('%')
let s:file = expand('%:p')
new
let s:window = winnr()
let s:previous_window = winnr('#')
NoteHelp

call assert_equal(15, len(g:note_help_spec.source))
call assert_equal(['--prompt=NoteHelp> '], g:note_help_spec.options)
call assert_equal(s:window, winnr())
call assert_equal(s:previous_window, winnr('#'))
for s:command in [
  \ ':NoteInit', ':NoteToday', ':NoteLiterature {name}', ':NoteFleet {name}',
  \ ':NoteSearch', ':NoteGrep [query]', ':NoteBacklinks', ':NoteUnlinkedMentions',
  \ ':NoteOrphans', ':NoteRelated', ':NoteRandom', ':NoteBrokenLinks',
  \ ':NoteTag {tag}', ':NoteTags', ':NoteHelp'
  \ ]
  call assert_equal(1, len(filter(copy(g:note_help_spec.source), 'stridx(v:val, s:command) == 0')))
endfor
wincmd p
call assert_equal(s:buffer, bufnr('%'))
call assert_equal(s:file, expand('%:p'))

call delete(s:autoload, 'rf')
if !empty(v:errors)
  for s:error in v:errors
    echom s:error
  endfor
  cquit
endif
qa!
