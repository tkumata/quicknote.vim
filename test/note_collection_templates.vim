let s:repo = fnamemodify(expand('<sfile>:p'), ':h:h')
let s:root = tempname()
let g:quicknote_root = s:root

call mkdir(s:root . '/Templates', 'p')
call writefile(['# {{title}}', 'fleet template'], s:root . '/Templates/Fleet.md')
call writefile(['# {{title}}', 'literature template'], s:root . '/Templates/Literature.md')

execute 'source ' . fnameescape(s:repo . '/plugin/quicknote.vim')

NoteFleet Alpha
call assert_equal(['# Alpha', 'fleet template'], readfile(s:root . '/Fleet/Alpha.md'))

NoteLiterature Beta
call assert_equal(['# Beta', 'literature template'], readfile(s:root . '/Literature/Beta.md'))

call delete(s:root . '/Templates/Fleet.md')
NoteFleet Missing
call assert_false(filereadable(s:root . '/Fleet/Missing.md'))

call delete(s:root, 'rf')
if !empty(v:errors)
  for s:error in v:errors
    echom s:error
  endfor
  cquit
endif
qa!
