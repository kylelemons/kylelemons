"""""" VIM Setup file (.vimrc)
""" Basic setup
set nocompatible          " Don't force VI compatibility when using vi
"set modelines=5           " Check the first(?) 5* lines of a file for VIM mode commands
"set modeline              " Enable checking of files for vim modelines (e.g. /* vim: set noai sw=4 ts=4 et: */

""" Editing setup
set autoindent            " Enable automatic indenting where possible
set autowrite             " Automatically write to file for compilles, etc
set linebreak             " Break lines onscreen at sensible places (read: word breaks)
set whichwrap=bs~<>[]     " Let cursors, backspace, etc to move onto the next or previous line
set backupdir=~/.vim/bak  " Write backup files to ~/.vim/bak* if it exists
set showmatch             " Show matches wile searching
set incsearch             " Search as you type
set ignorecase            " Ignore case by default when searching
set hlsearch              " Show other matches after a search (use :set noh to hide them)
set ruler                 " Show cursor position in the last line

""" Editing setup - indent
set expandtab
set tabstop=2
set shiftwidth=2

""" Editing setup - folding
set foldminlines=5        " Don't fold stuff that's tiny
set foldlevel=99          " Don't fold anything at load
set foldmethod=syntax     " Let the syntax files specify how to fold

""" More editing setup
"set textwidth=80          " Break lines at 80* characters
"set nobackup              " Suppress the creation of backup files when saving
"set background=dark       " Assume that the background will be dark, so use appropriate colors
behave xterm              " Use XTERM semantics for handling control sequences, etc (use mswin if you're on windows)

""" Filetype rules
" Java/C
autocmd BufRead,BufNewFile * set fo=tcql nocin com&
autocmd BufRead,BufNewFile *.java,*.c,*.h,*.cpp set fo=ctroq cin com=sr:/**,mb:*,elx:*/,sr:/*,mb:*,elx:*/,://
" Go
highlight ExtraWhitespace ctermbg=red guibg=red
autocmd BufRead,BufNewFile *.go match ExtraWhitespace /^\t*\zs \+/
autocmd BufRead,BufNewFile *.go set noet tabstop=4 shiftwidth=4
" Python
highlight TooLongLine ctermbg=red guibg=red
autocmd BufRead,BufNewFile *.py match TooLongLine /^.\{80,}$/
autocmd BufRead,BufNewFile *.py set et tabstop=4 shiftwidth=4

" Last position jump
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

""" Command mappings
" Use ^J to reformat a text paragraph with the current linewidth
nmap <C-J> gqap
vmap <C-J> gq
imap <C-J> <C-O>gqap

" Use ^A/^E as beginning/end jump like in shell
map  <C-A> 0
map  <C-E> $

" Delete current line with ^K
map  <C-K> dd
imap <C-K> <C-O>dd

" Switch buffers
imap <C-^> <C-O><C-^>

" Page Up/Down Emulation
imap [5;5~ :N<CR>
map  [5;5~ <C-O>:N<CR>
imap [6;5~ :n<CR>
map  [6;5~ <C-O>:n<CR>

" Allow suspend in insert mode
imap <C-Z> <C-O><C-Z>

""" Useful commands:
" <C-V,<any>> - In insert mode (holding CTRL), insert the terminal code for <any>, e.g. <C-V,[> enters ^[
" gggqG - Format paragraph according to text width

""" In gnome terminal, change the cursor to be a vertical bar (this interferes with all other open gnome_terminals and tabs)
"if has("autocmd")
"  au InsertEnter * silent execute "!gconftool-2 --type string --set /apps/gnome-terminal/profiles/Default/cursor_shape ibeam"
"  au InsertLeave * silent execute "!gconftool-2 --type string --set /apps/gnome-terminal/profiles/Default/cursor_shape block"
"  au VimLeave * silent execute "!gconftool-2 --type string --set /apps/gnome-terminal/profiles/Default/cursor_shape block"
"endif
