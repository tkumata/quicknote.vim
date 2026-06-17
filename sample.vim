" Example .vimrc entry point.
" Replace this directory with the installed path when copying these lines.
let s:vimdir = expand('~/.vim')

if filereadable(s:vimdir . '/private.vim')
  execute 'source ' . fnameescape(s:vimdir . '/private.vim')
endif

if filereadable(s:vimdir . '/quicknote.vim')
  execute 'source ' . fnameescape(s:vimdir . '/quicknote.vim')
endif
