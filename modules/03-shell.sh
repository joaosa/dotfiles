#!/usr/bin/env bash
# Module: Shell configuration (Prezto, fzf, git, GNU parallel)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

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
setopt EXTENDED_GLOB
for rcfile in "\${ZDOTDIR:-\$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -sf "\$rcfile" "\${ZDOTDIR:-\$HOME}/.\${rcfile:t}"
done
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

  # git global excludes
  if [ ! -f ~/.gitignore_global ]; then
    log_skip "Global git excludes (no ~/.gitignore_global file)"
  elif [ "$(git config --global --get core.excludesfile 2>/dev/null)" != "$HOME/.gitignore_global" ]; then
    if ! is_dry_run "configure global git excludes"; then
      git config --global core.excludesfile ~/.gitignore_global
      log_success "Configured global git excludes"
    fi
  else
    log_skip "Global git excludes already configured"
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
