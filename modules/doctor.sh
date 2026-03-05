#!/usr/bin/env bash
# Doctor: Verify setup health by checking expected binaries, stow links, and versions

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && source "${BASH_SOURCE[0]%/*}/../lib/standalone.sh"

run() {
  log_section "1" "5" "CORE TOOLS"
  check_binary brew "Homebrew"
  check_binary git "Git"
  check_binary stow "GNU Stow"
  check_binary just "Just"
  check_binary zsh "Zsh"
  check_binary nvim "Neovim"
  check_binary tmux "tmux"

  log_section "2" "5" "LANGUAGE RUNTIMES"
  check_binary rustc "Rust compiler"
  check_binary cargo "Cargo"
  check_binary asdf "asdf version manager"

  local nodejs_version
  nodejs_version=$(get_tool_version "nodejs")
  [ -n "$nodejs_version" ] && check_version node "$nodejs_version" "Node.js"

  local golang_version
  golang_version=$(get_tool_version "golang")
  [ -n "$golang_version" ] && check_version go "$golang_version" "Go"

  log_section "3" "5" "PACKAGES"
  verify_asdf_packages "nodejs" "${NPM_PACKAGES[@]}"
  verify_asdf_packages "golang" "${GO_PACKAGES[@]}"
  verify_cargo_packages "${CARGO_PACKAGES[@]}"

  log_section "4" "5" "STOW LINKS"
  check_stow_links

  log_section "5" "5" "DOWNLOADS"
  check_file "$KUBECTL_ALIASES_PATH" "kubectl aliases"
  check_dir "$ASR_MODEL_DIR" "ASR model (Qwen3-ASR-0.6B)"

  echo ""
  if brew bundle check --file="$SCRIPT_DIR/Brewfile" >/dev/null 2>&1; then
    log_success "All Brewfile packages installed"
  else
    log_error "Some Brewfile packages are missing (run: just homebrew)"
  fi

  return $(( ITEMS_FAILED > 0 ? 1 : 0 ))
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run || true; print_summary --doctor; exit $(( ITEMS_FAILED > 0 ? 1 : 0 )); }
