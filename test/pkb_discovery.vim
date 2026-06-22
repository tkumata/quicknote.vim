let s:repo = fnamemodify(expand('<sfile>:p'), ':h:h')
let s:root = tempname()
let g:quicknote_root = s:root

call mkdir(s:root . '/Fleet', 'p')
call mkdir(s:root . '/Daily/Nested', 'p')
call mkdir(s:root . '/Templates/Nested', 'p')

let s:current = s:root . '/Fleet/Alpha.md'
let s:mention = s:root . '/Fleet/Mention.md'
let s:daily_named = s:root . '/Fleet/Daily.md'
let s:templates_named = s:root . '/Fleet/Templates.md'
call writefile(['# Alpha concept'], s:current)
call writefile([
  \ 'Alpha is useful.',
  \ '[[Alpha]]',
  \ '[[Other]] and Alpha',
  \ '[[Other Alpha]]',
  \ 'Alpha and [[Alpha]]',
  \ 'Alphabet',
  \ 'Alpha concept appears.'
  \ ], s:mention)
call writefile(['Alpha hidden in Daily'], s:root . '/Daily/Nested/Hidden.md')
call writefile(['Alpha hidden in Templates'], s:root . '/Templates/Nested/Hidden.md')
call writefile(['# Daily'], s:daily_named)
call writefile(['# Templates'], s:templates_named)

execute 'source ' . fnameescape(s:repo . '/plugin/quicknote.vim')
call assert_equal(2, exists(':NoteUnlinkedMentions'))
call assert_equal(2, exists(':NoteOrphans'))
call assert_equal(2, exists(':NoteRelated'))
call assert_equal(2, exists(':NoteRandom'))

let s:functions = execute('function /unlinked_mention_results')
let s:sid = matchstr(s:functions, '<SNR>\d\+_')
call assert_notequal('', s:sid)

let s:DiscoveryFiles = function(s:sid . 'discovery_markdown_files')
let s:IsDiscoveryNote = function(s:sid . 'is_discovery_note_file')
let s:CurrentNames = function(s:sid . 'current_note_names')
let s:UnlinkedResults = function(s:sid . 'unlinked_mention_results')
let s:OrphanFiles = function(s:sid . 'orphan_note_files')
let s:RelatedFiles = function(s:sid . 'related_note_files')
let s:FrontmatterTags = function(s:sid . 'frontmatter_tags')

let s:files = sort(call(s:DiscoveryFiles, []))
call assert_equal(sort([s:current, s:mention, s:daily_named, s:templates_named]), s:files)

execute 'edit ' . fnameescape(s:current)
call assert_equal(1, call(s:IsDiscoveryNote, []))
call assert_equal(['Alpha', 'Alpha concept'], call(s:CurrentNames, []))
execute 'edit ' . fnameescape(s:root . '/Daily/Nested/Hidden.md')
call assert_equal(0, call(s:IsDiscoveryNote, []))
execute 'edit ' . fnameescape(s:root . '/Templates/Nested/Hidden.md')
call assert_equal(0, call(s:IsDiscoveryNote, []))

let s:results = call(s:UnlinkedResults, [[s:current, s:mention], s:current, ['Alpha', 'Alpha concept']])
call assert_equal([
  \ s:mention . ':1:Alpha is useful.',
  \ s:mention . ':3:[[Other]] and Alpha',
  \ s:mention . ':5:Alpha and [[Alpha]]',
  \ s:mention . ':6:Alphabet',
  \ s:mention . ':7:Alpha concept appears.'
  \ ], s:results)

let s:linked = s:root . '/Fleet/Linked.md'
let s:source = s:root . '/Fleet/Source.md'
let s:self_linked = s:root . '/Fleet/Self.md'
let s:h1_target = s:root . '/Fleet/Odd.md'
let s:daily_only = s:root . '/Fleet/DailyOnly.md'
call writefile(['# Linked'], s:linked)
call writefile(['[[Linked]]', '[[Heading Target]]'], s:source)
call writefile(['[[Self]]'], s:self_linked)
call writefile(['# Heading Target'], s:h1_target)
call writefile(['# DailyOnly'], s:daily_only)
call writefile(['[[DailyOnly]]'], s:root . '/Daily/Nested/Reference.md')
call assert_equal(sort([s:source, s:self_linked, s:daily_only]), call(s:OrphanFiles, [[
  \ s:linked,
  \ s:source,
  \ s:self_linked,
  \ s:h1_target,
  \ s:daily_only
  \ ]]))

let s:related = s:root . '/Fleet/Related.md'
let s:unrelated = s:root . '/Fleet/Unrelated.md'
call writefile(['---', 'tags:', '  - knowledge', '  - vim', '---', '# Alpha concept'], s:current)
call writefile(['---', 'tags:', '  - vim', '---', '# Related'], s:related)
call writefile(['---', 'tags:', '  - other', '---', '# Unrelated'], s:unrelated)
call writefile(['---', 'tags:', '  - vim', '---', '# Daily related'], s:root . '/Daily/Nested/Related.md')
call writefile(['---', 'tags:', '  - vim', '---', '# Template related'], s:root . '/Templates/Nested/Related.md')
let s:tags = call(s:FrontmatterTags, [s:current])
call assert_equal(['knowledge', 'vim'], s:tags)
call assert_equal([s:related], call(s:RelatedFiles, [call(s:DiscoveryFiles, []), s:current, s:tags]))

for s:attempt in range(20)
  NoteRandom
  call assert_true(index(call(s:DiscoveryFiles, []), expand('%:p')) >= 0)
endfor

let s:current_buffer = expand('%:p')
for s:file in call(s:DiscoveryFiles, [])
  call delete(s:file)
endfor
NoteRandom
call assert_equal(s:current_buffer, expand('%:p'))

call delete(s:root, 'rf')
if !empty(v:errors)
  for s:error in v:errors
    echom s:error
  endfor
  cquit
endif
qa!
