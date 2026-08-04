#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT_DIR/lib/common.sh"

echo "vim-nox"

apt_install vim-nox

ensure_dir /etc/vim
cat > /etc/vim/vimrc.local << 'EOF'
" system-wide defaults (minimal-debian)

set nocompatible
set encoding=utf-8
syntax on
filetype plugin indent on

set number
set ruler
set showcmd
set showmatch
set hlsearch
set incsearch
set ignorecase
set smartcase

set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent

set wildmenu
set laststatus=2
set scrolloff=3
set backspace=indent,eol,start
set mouse=

set nobackup
set noswapfile
set undofile
set undodir=/tmp/vim-undo//

nnoremap <C-l> :nohlsearch<CR><C-l>
EOF

# undodir for all users
ensure_dir /tmp/vim-undo
chmod 1777 /tmp/vim-undo

echo "vim-nox installed, /etc/vim/vimrc.local written"
