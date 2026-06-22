# Quick Note

Quick Note は、Vim 上で Obsidian 風のノート運用を行うためのプラグインです。また、このプラグインで既存の Obsidian Vault ディレクトリ以下を開くことが可能で、Obsidian Vault ディレクトリ配下を汚染することなくノート運用が可能です。本プラグインと Obsidian で同一 Vault を操作できます。

![screenshot 1](./doc/quicknote-screenshot.png)
![screenshot 2](./doc/quicknote-screenshot-2.png)

## この repository に含まれるファイル

- `plugin/quicknote.vim` (本体設定ファイル)
  - QuickNote 固有の設定
  - `:NoteToday` コマンドの実装
  - `:NoteLiterature` コマンドの実装
  - `:NoteFleet` コマンドの実装
  - `:NoteSearch`、`:NoteGrep`、`:NoteBacklinks`、`:NoteUnlinkedMentions`、`:NoteOrphans`、`:NoteRelated`、`:NoteRandom`、`:NoteBrokenLinks`、`:NoteTag`、`:NoteTags`、`:NoteHelp` コマンドの実装
  - `[[link]]` を `<Enter>` で開く mapping (ファイルがなければファイルを**自動生成**)
  - template token 置換
- `my.vim` (補足設定ファイル)
  - `vim-plug` の plugin 定義
  - 一般的な Vim 設定
  - NERDTree、airline、Git キーマップなどの汎用設定
- `test/pkb_discovery.vim`
  - PKB discovery command の headless Vim smoke test
- `test/note_help.vim`
  - `:NoteHelp` の headless Vim smoke test

## 主な機能

- `~/Documents/QuickNote` を既定 root とした markdown ノート管理 (変更可能)
- `[[note-name]]` 形式の wiki link を `<Enter>` でオープン
- `:NoteToday` で `Daily/YYYY-MM-DD.md` を作成またはオープン
- `:NoteLiterature {name}` で `Literature/{name}.md` を作成またはオープン
- `:NoteFleet {name}` で `Fleet/{name}.md` を作成またはオープン
- 存在しない `[[link]]` から `Fleet/{link}.md` を自動作成
- `:NoteSearch` で note file を FZF 検索
- `:NoteGrep` で note 本文を FZF grep
- `:NoteBacklinks` で現在の note を参照している `[[name]]` を FZF 検索
- `:NoteUnlinkedMentions` で現在の note 名が wiki link ではない plain text として現れる行を FZF 検索
- `:NoteOrphans` で backlink がない note を FZF 表示
- `:NoteRelated` で現在の note と共通 tag を持つ note を FZF 表示
- `:NoteRandom` でランダムな note を1件開く
- `:NoteTag {tag}` で frontmatter の `tags:` ブロックに指定タグを持つ note を FZF 検索
- `:NoteTags` で frontmatter tag 一覧を FZF 選択し、選択 tag の note 検索へ進む
- `:NoteBrokenLinks` で存在しない `[[wiki link]]` を含む note を FZF 検索
- `:NoteHelp` で QuickNote コマンドと短い説明を読み取り専用の FZF 一覧に表示
- markdown 編集時に `(`、`[`、`{` の対になる括弧を自動入力
- Obsidian 互換の template token 置換
- 同名 note が複数ある場合の FZF 選択

## Quick Note コマンド

- `:NoteInit`
  - `g:quicknote_root` の directory を作成します。
  - `Daily/`、`Fleet/`、`Literature/` を作成します。既に存在する場合は変更しません。
  - repository の `Templates/` を `g:quicknote_root` 配下へコピーします。
  - 既存の template file は上書きしません。
- `:NoteToday`
  - `Daily/YYYY-MM-DD.md` を開きます。
  - file が存在しない場合は `Templates/Daily.md` があれば内容を展開して作成します。
  - template がなくても空の buffer として開けます。
- `:NoteLiterature {name}`
  - `Literature/{name}.md` を開きます。
  - `{name}` に `.md` がなければ自動で付与します。
  - file が存在しない場合は `Templates/Literature.md` から作成します。
  - `Templates/Literature.md` がない場合は error を表示して終了します。
- `:NoteFleet {name}`
  - `Fleet/{name}.md` を開きます。
  - `{name}` に `.md` がなければ自動で付与します。
  - file が存在しない場合は最小の markdown note を作成します。
  - `{name}` 内の `/` は subdirectory として扱わず、file name 用に `-` へ置換します。
- `:NoteSearch`
  - QuickNote root 配下の markdown file を FZF で選択して開きます。
  - FZF が利用できない場合は error を表示します。
- `:NoteGrep [query]`
  - QuickNote root 配下の markdown file 本文を grep し、結果を FZF で選択します。
  - `[query]` を省略した場合は検索語を入力します。
  - FZF grep support が利用できない場合は error を表示します。
- `:NoteBacklinks`
  - 現在開いている note の filename stem と markdown H1 title をもとに `[[name]]` 参照を検索します。
  - 検索結果を FZF で選択し、参照元 file の該当行を開きます。
  - FZF が利用できない場合は error を表示します。
- `:NoteUnlinkedMentions`
  - 現在開いている note の filename stem と最初の markdown H1 title を検索名にします。
  - `Daily/`、`Templates/`、現在の note 自身を除く markdown file から、検索名が wiki link ではない plain text として現れる行を検索します。
  - 検索は case-sensitive な literal substring 一致です。
  - 検索結果を FZF で選択し、該当 file の該当行を開きます。
  - FZF が利用できない場合は error を表示します。
- `:NoteOrphans`
  - `Daily/` と `Templates/` を除く markdown file を対象にします。
  - filename stem または最初の H1 を指す `[[name]]` が他の対象 note にない note を FZF 表示します。
  - 自己参照だけの note は orphan として扱います。
  - 選択した note を開きます。
  - FZF が利用できない場合は error を表示します。
- `:NoteRelated`
  - 現在の note と frontmatter tag が1個以上完全一致する note を FZF 表示します。
  - `Daily/`、`Templates/`、現在の note 自身を候補から除外します。
  - 共通 tag 数による順位付けは行いません。
  - 選択した note を開きます。
  - FZF が利用できない場合は error を表示します。
- `:NoteRandom`
  - `Daily/` と `Templates/` を除く markdown file から1件をランダムに開きます。
  - 現在の note も候補に含みます。
  - FZF は必要ありません。
- `:NoteTag {tag}`
  - QuickNote root 配下の markdown file から、frontmatter の `tags:` ブロックに `{tag}` を持つ note を検索します。
  - 対象は `tags:` ブロック内の `- tag` 形式です。
  - YAML の inline list や本文内 tag は対象外です。
  - 検索結果を FZF で選択し、該当 note を開きます。
  - FZF が利用できない場合は error を表示します。
- `:NoteTags`
  - QuickNote root 配下の markdown file から、frontmatter の `tags:` ブロックにある tag 一覧を集めます。
  - tag を FZF で選択すると、`:NoteTag {tag}` と同じ検索結果へ進みます。
  - 対象は `tags:` ブロック内の `- tag` 形式です。
  - YAML の inline list や本文内 tag は対象外です。
  - FZF が利用できない場合は error を表示します。
- `:NoteBrokenLinks`
  - QuickNote root 配下の markdown file から、存在しない `[[wiki link]]` を含む行を検索します。
  - 検索結果を FZF で選択し、該当 note の該当行を開きます。
  - 初期仕様では `[[name]]` 形式を対象にし、markdown inline link や URL の死活確認は対象外です。
  - FZF が利用できない場合は error を表示します。
- `:NoteHelp`
  - QuickNote の公開コマンドと短い説明を FZF に一覧表示します。
  - コマンド名と説明を入力して絞り込めます。
  - 項目を選択してもコマンドは実行しません。
  - FZF が利用できない場合は error を表示します。

## 前提条件

- Vim のインストール
- `vim-plug` のインストール
- `find` コマンドが利用できる環境
- `grep` コマンドが利用できる環境

## 導入手順

```vim
" QuickNote Root Directory
let g:quicknote_root = '~/Documents/QuickNote'

" Vimwiki
let g:vimwiki_list = [{
  \ 'path': g:quicknote_root . '/',
  \ 'syntax': 'markdown',
  \ 'ext': '.md'
  \}]
let g:vimwiki_key_mappings = { 'all_maps': 0 }

" Plugins
call plug#begin('~/.vim/plugged')
Plug 'tkumata/quicknote.vim'
Plug 'preservim/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'plasticboy/vim-markdown'
Plug 'tpope/vim-fugitive'
Plug 'vimwiki/vimwiki'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'rbtnn/vim-ambiwidth'
call plug#end()
```

vim 上で以下を実行します。

```vim
:PlugInstall
:NoteInit
```

開きたいディレクトリに移動して Vim を再起動します。

```shell
cd ~/Documents/QuickNote
vim
```

もしあなたが `~/Documents/Obsidian` で運用していたら、`quicknote_root` を変更すればそのまま運用できます。

## wiki link の開き方

markdown buffer では `<Enter>` によってカーソル下の `[[link]]` を開きます。

- 一致する file が 1 件ならそのまま開きます。
- 0 件なら `Fleet/{link}.md` を作成して開きます。
- 複数件なら `:FZF` が利用できる場合に候補選択へ渡します。
- `:FZF` が利用できない場合は候補一覧を表示します。

## 括弧自動補完

QuickNote の markdown 編集では、insert mode で開き括弧を入力すると対になる閉じ括弧も入力します。

- `(` は `()` になります。
- `[` は `[]` になります。
- `{` は `{}` になります。

カーソルは括弧の間に置かれます。

## 補足

- `g:quicknote_root` は `quicknote.vim` を source する前に設定してください。
- root path の末尾に `/` が付いていても内部で正規化されます。
- `quicknote.vim` は `vimwiki` を markdown mode で利用する前提です。

## template の書き方

QuickNote が置換する token は次の通りです。

- `{{title}}`
- `{{date}}`
- `{{time}}`
- `{{date:FORMAT}}`
- `{{time:FORMAT}}`

`FORMAT` では次の表記が使えます。

- `YYYY`
- `MM`
- `DD`
- `HH`
- `mm`
- `ss`
- `ddd`
- `dddd`

`NoteToday` は `Daily.md` 内の `{{cursor}}` を見つけると、その位置へカーソルを移動して token 自体を削除します。

例:

```md
# {{date:YYYY-MM-DD}} {{date:ddd}}

- [ ] 

{{cursor}}
```

```md
# {{title}}

Created: {{date}} {{time}}
```
