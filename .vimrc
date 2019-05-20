set tabstop=4
set list
set listchars=tab:^\ 
set number
set nowrap
set cursorline
set nocp
set hlsearch
syntax on
set backspace=indent,eol,start
set background=dark
colorscheme torte
set display=uhex
filetype plugin on
set laststatus=2
set cmdheight=2
set statusline=%F%m%r%h%w%=\[TYPE=%Y]\[FORMAT=%{&ff}]\[ENC=%{&fileencoding}]\[R=%l,C=%v]
set encoding=utf8
set shortmess+=s
set tags=tags;
set foldmethod=marker

set splitright

nnoremap <Tab> <C-w>w
noremap f :Vexp! ~/<cr>
noremap = :Vexp! %:p:h<cr>
noremap b<Left> :e#<cr>

vnoremap * "zy:let @/ = @z<CR>nN

augroup BinaryXXD
  autocmd!
  autocmd BufReadPre *.bin let &binary=1
  autocmd BufReadPost * if &binary | silent %!xxd -g 1
  autocmd BufReadPost * set filetype=xxd | endif
  autocmd BufWritePre * if &binary | %!xxd -r
  autocmd BufWritePre * endif
  autocmd BufWritePost * if &binary | silent %!xxd -g 1
  autocmd BufWritePost * set nomod | endif
augroup END

augroup SaveCursor
  au BufRead * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g`\"" | endif
augroup END

augroup SaveCurrentDir
  au VimLeave * !echo `pwd` > ~/.vimlastdir
augroup END

