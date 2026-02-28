#!/usr/bin/env bash
# Module: Shell configuration (Prezto, fzf, GNU parallel)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/standalone.sh"

run() {
  # Prezto - pinned to specific commit
  if [ ! -d "${ZDOTDIR:-$HOME}/.zprezto" ]; then
    log_info "Installing Prezto (commit: ${PREZTO_COMMIT:0:8})..."
    if ! is_dry_run "install Prezto"; then
      zsh << EOF
git clone --recursive https://github.com/sorin-ionescu/prezto.git "\${ZDOTDIR:-\$HOME}/.zprezto"
cd "\${ZDOTDIR:-\$HOME}/.zprezto"
git checkout "$PREZTO_COMMIT"
git submodule update --init --recursive
EOF
      log_success "Installed Prezto"
    fi
  else
    log_skip "Prezto already installed"
  fi

  # fzf
  if [ ! -f ~/.fzf.bash ] && [ ! -f ~/.fzf.zsh ]; then
    if ! is_dry_run "install fzf shell integration"; then
      "$(brew --prefix)/opt/fzf/install" --all
      log_success "Installed fzf"
    fi
  else
    log_skip "fzf already installed"
  fi

  # GNU parallel citation suppression
  if [ ! -f ~/.parallel/will-cite ]; then
    if ! is_dry_run "configure GNU parallel"; then
      mkdir -p ~/.parallel
      touch ~/.parallel/will-cite
      log_success "Configured GNU parallel"
    fi
  else
    log_skip "GNU parallel already configured"
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run; print_summary; }
