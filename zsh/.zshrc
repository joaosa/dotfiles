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
function nvim() {
  if test $# -gt 0; then
    env nvim "$@"
  elif test -f Session.vim; then
    env nvim -S
  else
    env nvim -c Obsession -c Alpha
  fi
}

# prezto history
export HISTSIZE=1000000 SAVEHIST=1000000 HISTFILE=~/.zsh_history

# xkcd
# ref - https://www.commandlinefu.com/commands/view/4167/view-the-newest-xkcd-comic
xkcd() {
  wget -qO- http://xkcd.com/ | gtee >(feh $(rg -o 'https://imgs[^/]+/comics/[^"]+\.\w{3}' | cut -f1,2 -d:) &) >(rg -Po '(?<=(\w{3})" title=").*(?=" alt)' | cut -f1,2 -d:) 1>/dev/null
}

# git
alias git='hub'
alias gcod="git branch | grep dev | xargs git checkout"
alias gcom="git branch | grep main | xargs git checkout"
alias gbpm='git branch --merged | grep -v "\*" | grep -v develop | grep -v master | xargs -n 1 git branch -d'
alias gSp='git submodule foreach --recursive git checkout master && git submodule foreach --recursive git pull origin master'
alias gtx='git tag -l | xargs git tag -d && git fetch -t'
gw() {
  ~/ghq/github.com/muesli/gitomatic/gitomatic -privkey "$(ssh-add -l | cut -f3 -d' ' | head -n1)" "$1"
}

# docker AWS login
docker-aws-login() {
  vault_user="$1"
  ecr_repo="$(aws-vault exec $vault_user -- aws ecr get-authorization-token --output text --query 'authorizationData[].proxyEndpoint')"
  login="$(aws-vault exec $vault_user -- aws ecr get-login --no-include-email)"
  echo "$login" | awk '{print $6}' | docker login -u AWS --password-stdin "$ecr_repo"
}

# python
eval "$(pyenv init -)"
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

# wasm
export BINARYEN=/usr/local/opt/binaryen
export LLVM=/usr/local/opt/llvm/bin

# fuzzy matching
# setting ag as the default source for fzf
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# direnv
eval "$(direnv hook zsh)"

# asdf
. /opt/homebrew/opt/asdf/libexec/asdf.sh

# zoxide
eval "$(zoxide init zsh)"

# starship
eval "$(starship init zsh)"

# kubectl aliases
[ -f ~/.kubectl_aliases ] && source ~/.kubectl_aliases
function kubectl() { echo "+ kubectl $@">&2; command kubectl $@; }
