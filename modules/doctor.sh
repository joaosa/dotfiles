#!/usr/bin/env bash
# Doctor: Verify setup health by checking expected binaries, stow links, and versions

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"
init_standalone

check_binary() {
  local name="$1" description="${2:-$1}"
  if command -v "$name" >/dev/null 2>&1; then
    log_success "$description"
  else
    log_error "$description: not found"
  fi
}

check_file() {
  local path="$1" description="${2:-$1}"
  if [ -f "$path" ]; then
    log_success "$description"
  else
    log_error "$description: missing"
  fi
}

check_symlink() {
  local path="$1" description="${2:-$1}"
  if [ -L "$path" ]; then
    log_success "$description (-> $(readlink "$path"))"
  elif [ -e "$path" ]; then
    log_warn "$description exists but is not a symlink"
  else
    log_error "$description: missing"
  fi
}

check_version() {
  local binary="$1" expected="$2" description="${3:-$1}"
  if ! command -v "$binary" >/dev/null 2>&1; then
    log_error "$description: not installed"
    return
  fi
  local actual
  actual=$("$binary" --version 2>/dev/null | head -1 || echo "unknown")
  if echo "$actual" | grep -qF "$expected"; then
    log_success "$description $expected"
  else
    log_warn "$description: expected $expected, got $actual"
  fi
}

main() {
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
  local pkg name bin_name

  for pkg in "${NPM_PACKAGES[@]}"; do
    # Handle scoped packages: @scope/name@version vs name@version
    if [[ "$pkg" == @*/*@* ]]; then
      name="${pkg%@*}"
    else
      name="${pkg%%@*}"
    fi
    if npm list -g "$pkg" --depth=0 >/dev/null 2>&1; then
      log_success "npm: $name"
    else
      log_error "npm: $name: not installed"
    fi
  done

  for pkg in "${GO_PACKAGES[@]}"; do
    name="${pkg##*/}"
    name="${name%%@*}"
    check_binary "$name" "go: $name"
  done

  for pkg in "${CARGO_PACKAGES[@]}"; do
    bin_name=$(cargo_bin_name "$pkg")
    check_binary "$bin_name" "cargo: $pkg"
  done

  log_section "4" "5" "STOW LINKS"
  check_symlink "$HOME/.config/nvim" "nvim config"
  check_symlink "$HOME/.config/alacritty" "alacritty config"
  check_symlink "$HOME/.tmux.conf" "tmux config"
  check_symlink "$HOME/.zshrc" "zsh config"
  check_symlink "$HOME/.gitconfig" "git config"
  is_macos && check_symlink "$HOME/.hammerspoon" "hammerspoon config"

  log_section "5" "5" "DOWNLOADS"
  check_file "$HOME/.kubectl_aliases" "kubectl aliases"
  check_file "$HOME/.local/share/whisper/ggml-base.en.bin" "whisper model"

  echo ""
  if brew bundle check --file="$SCRIPT_DIR/Brewfile" >/dev/null 2>&1; then
    log_success "All Brewfile packages installed"
  else
    log_error "Some Brewfile packages are missing (run: just homebrew)"
  fi

  # Summary
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${GREEN}✓${RESET} Passed:   $ITEMS_INSTALLED"
  [ "$ITEMS_WARNED" -gt 0 ] && echo -e "${YELLOW}!${RESET} Warnings: $ITEMS_WARNED"
  [ "$ITEMS_FAILED" -gt 0 ] && echo -e "${RED}✗${RESET} Failed:   $ITEMS_FAILED"
  echo ""

  return $(( ITEMS_FAILED > 0 ? 1 : 0 ))
}

main
exit $?
