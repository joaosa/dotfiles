#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...
# vim
# fix the delay switching modes
export KEYTIMEOUT=1
# disable arrow keys
noop () { }
zle -N noop
# up
bindkey -M vicmd "$terminfo[kcuu1]" noop
bindkey -M viins "$terminfo[kcuu1]" noop
# down
bindkey -M vicmd "$terminfo[kcud1]" noop
bindkey -M viins "$terminfo[kcud1]" noop
# left
bindkey -M vicmd "$terminfo[kcub1]" noop
bindkey -M viins "$terminfo[kcub1]" noop
# right
bindkey -M vicmd "$terminfo[kcuf1]" noop
bindkey -M viins "$terminfo[kcuf1]" noop

# alias
alias vi=nvim
alias vim=nvim

# dotfiles
alias c='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# history
export HISTSIZE=100000 SAVEHIST=100000 HISTFILE=~/.zhistory

# tag-ag
if (( $+commands[tag] )); then
  tag() { command tag "$@"; source ${TAG_ALIAS_FILE:-/tmp/tag_aliases} 2>/dev/null }
  alias ag=tag
fi

# git
alias git='hub'
alias gcod='git checkout develop'
alias gbpm='git branch --merged | grep -v "\*" | grep -v develop | grep -v master | xargs -n 1 git branch -d'
alias gSp='git submodule foreach --recursive git checkout master && git submodule foreach --recursive git pull origin master'

# move multiple files
alias mmv='noglob zmv -W'

# postgres
export PG_DATA=/usr/local/var/postgres

# Go
export GOPATH="$HOME"
export PATH="$PATH:${GOPATH//://bin:}/bin"

# python
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# homebrew
BREW_PREFIX="/usr/local/opt"
export FIND_UTILS="$BREW_PREFIX/findutils/bin"
export CORE_UTILS="$BREW_PREFIX/libexec/gnubin"

# fuzzy matching
# setting ag as the default source for fzf
export FZF_DEFAULT_COMMAND='ag -g ""'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh