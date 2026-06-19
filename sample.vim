" Example .vimrc entry point.
" Replace this directory with the installed path when copying these lines.
let s:vimdir = expand('~/.vim')

if filereadable(s:vimdir . '/plugged/quicknote.vim/my.vim')
  execute 'source ' . fnameescape(s:vimdir . '/plugged/quicknote.vim/my.vim')
endif
