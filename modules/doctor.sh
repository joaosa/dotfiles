#!/usr/bin/env bash
# Doctor: Verify setup health by checking expected binaries, stow links, and versions

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { set -euo pipefail; source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/helpers.sh"; init_standalone; }

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

check_stow_links() {
  local stow_dir="$SCRIPT_DIR/stow"
  local -A checked_config_dirs
  local pkg_name
  while IFS= read -r pkg_name; do
    local pkg_dir="$stow_dir/$pkg_name/"

    # Check immediate children of each stow package
    for entry in "$pkg_dir"* "$pkg_dir".*; do
      [ -e "$entry" ] || continue
      local base
      base=$(basename "$entry")
      [[ "$base" == "." || "$base" == ".." ]] && continue

      if [ "$base" = ".config" ] && [ -d "$entry" ]; then
        # For .config, stow symlinks one level deeper (e.g. ~/.config/nvim -> ...)
        for sub in "$entry"/*/; do
          [ -d "$sub" ] || continue
          local sub_name
          sub_name=$(basename "$sub")
          # Avoid duplicate checks if multiple packages share a .config subdir
          [[ -n "${checked_config_dirs[$sub_name]+x}" ]] && continue
          checked_config_dirs[$sub_name]=1
          check_symlink "$HOME/.config/$sub_name" "$pkg_name: ~/.config/$sub_name"
        done
        # Also check .config files (not dirs) like starship.toml
        for sub in "$entry"/*; do
          [ -f "$sub" ] || continue
          local sub_name
          sub_name=$(basename "$sub")
          check_symlink "$HOME/.config/$sub_name" "$pkg_name: ~/.config/$sub_name"
        done
      else
        # Top-level entry: stow creates a direct symlink in $HOME
        check_symlink "$HOME/$base" "$pkg_name: ~/$base"
      fi
    done
  done < <(discover_stow_packages)
}

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
  local pkg name bin_name

  for pkg in "${NPM_PACKAGES[@]}"; do
    name=$(npm_package_name "$pkg")
    if is_npm_pkg_installed "$pkg"; then
      log_success "npm: $name"
    else
      log_error "npm: $name: not installed"
    fi
  done

  for pkg in "${GO_PACKAGES[@]}"; do
    name=$(go_binary_name "$pkg")
    check_binary "$name" "go: $name"
  done

  for pkg in "${CARGO_PACKAGES[@]}"; do
    bin_name=$(cargo_bin_name "$pkg")
    check_binary "$bin_name" "cargo: $pkg"
  done

  log_section "4" "5" "STOW LINKS"
  check_stow_links

  log_section "5" "5" "DOWNLOADS"
  check_file "$KUBECTL_ALIASES_PATH" "kubectl aliases"
  check_file "$WHISPER_MODEL_PATH" "whisper model"

  echo ""
  if brew bundle check --file="$SCRIPT_DIR/Brewfile" >/dev/null 2>&1; then
    log_success "All Brewfile packages installed"
  else
    log_error "Some Brewfile packages are missing (run: just homebrew)"
  fi

  return $(( ITEMS_FAILED > 0 ? 1 : 0 ))
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { run || true; print_summary --doctor; exit $(( ITEMS_FAILED > 0 ? 1 : 0 )); }
