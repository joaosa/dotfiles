#!/usr/bin/env bash
# Module: Shell configuration (Prezto, fzf, GNU parallel)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

_install_prezto() {
  log_info "Installing Prezto (commit: ${PREZTO_COMMIT:0:8})..."
  zsh << EOF
git clone --recursive https://github.com/sorin-ionescu/prezto.git "\${ZDOTDIR:-\$HOME}/.zprezto"
cd "\${ZDOTDIR:-\$HOME}/.zprezto"
git checkout "$PREZTO_COMMIT"
git submodule update --init --recursive
EOF
}

run() {
  ensure_installed "Prezto" \
    '[ -d "${ZDOTDIR:-$HOME}/.zprezto" ]' \
    _install_prezto

  ensure_installed "fzf" \
    '[ -f ~/.fzf.bash ] || [ -f ~/.fzf.zsh ]' \
    '"$(brew --prefix)/opt/fzf/install" --all'

  ensure_installed "GNU parallel" \
    '[ -f ~/.parallel/will-cite ]' \
    'mkdir -p ~/.parallel && touch ~/.parallel/will-cite'
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
