#!/usr/bin/env bash
# Package name parsing, installation, and verification

# ============================================================================
# PACKAGE NAME PARSING
# ============================================================================

# Extract binary name from a Go install path: github.com/user/repo/cmd/tool@v1.0 -> tool
go_binary_name() {
  local pkg="$1"
  local name="${pkg##*/}"
  echo "${name%%@*}"
}

# Extract package name from an npm specifier: @scope/name@version -> @scope/name, name@version -> name
npm_package_name() {
  local pkg="$1"
  if [[ "$pkg" == @*/*@* ]]; then
    echo "${pkg%@*}"
  else
    echo "${pkg%%@*}"
  fi
}

# Extract version from an npm specifier: @scope/name@version -> version, name@version -> version
npm_package_version() {
  local pkg="$1"
  echo "${pkg##*@}"
}

# Check if an npm package specifier (name or name@version) is globally installed.
is_npm_pkg_installed() {
  npm list -g "$1" --depth=0 >/dev/null 2>&1
}

# Extract binary name from a cargo package spec (crate:binary or just crate)
cargo_bin_name() {
  local pkg="$1"
  if [[ "$pkg" == *:* ]]; then
    echo "${pkg#*:}"
  else
    echo "${pkg##*/}"
  fi
}

# Extract crate name from a cargo package spec (crate:binary or just crate)
cargo_crate_name() {
  local pkg="$1"
  echo "${pkg%%:*}"
}

# ============================================================================
# ASDF MANAGEMENT
# ============================================================================

install_asdf_language() {
  local language="$1"
  local repo="$2"
  local version="${3:-$(get_tool_version "$language")}"
  local skipped=false

  if [ -z "$version" ]; then
    log_error "No version found for $language"
    return 1
  fi

  if ! asdf plugin list 2>/dev/null | grep -qxF "$language"; then
    if is_dry_run "add asdf plugin: $language"; then return 0; fi
    log_info "Adding asdf plugin: $language"
    if ! asdf plugin add "$language" "$repo"; then
      log_error "Failed to add asdf plugin: $language"
      return 1
    fi
    log_success "Added asdf plugin: $language"
  else
    skipped=true
  fi

  if ! asdf list "$language" 2>/dev/null | grep -qF " $version"; then
    if is_dry_run "install $language $version"; then return 0; fi
    log_info "Installing $language $version..."
    if ! asdf install "$language" "$version"; then
      log_error "Failed to install $language $version"
      return 1
    fi
    log_success "Installed $language $version"
  else
    if [ "$skipped" = true ]; then
      log_skip "$language $version (plugin and version already installed)"
    else
      log_skip "$language $version already installed"
    fi
  fi

  is_dry_run || asdf reshim "$language"
}

install_asdf_packages() {
  local language="$1"
  shift
  local packages=("$@")
  local -a already_installed=()
  local installed_count=0

  for package in "${packages[@]}"; do
    local display_name="" is_installed=false install_exit=0

    case "$language" in
      "golang")
        display_name=$(go_binary_name "$package")
        command -v "$display_name" >/dev/null 2>&1 && is_installed=true
        ;;
      "nodejs")
        local package_name package_version
        package_name=$(npm_package_name "$package")
        package_version=$(npm_package_version "$package")
        display_name="$package_name@$package_version"
        is_npm_pkg_installed "$package_name@$package_version" && is_installed=true
        ;;
      *)
        log_error "Unsupported language: $language"
        return 1
        ;;
    esac

    if [ "$is_installed" = true ]; then
      already_installed+=("$display_name")
      continue
    fi
    if is_dry_run "install $language package: $display_name"; then continue; fi

    log_info "Installing $language package: $package"
    case "$language" in
      "golang") go install "$package" || install_exit=$? ;;
      "nodejs") npm install -g "$package" || install_exit=$? ;;
    esac

    if [ "$install_exit" -eq 0 ]; then
      log_success "Installed $language package: $display_name"
      ((installed_count++)) || true
    else
      log_error "Failed to install $language package: $display_name"
    fi
  done

  log_skip_grouped "$language packages already installed" "${already_installed[@]+"${already_installed[@]}"}"

  if ! is_dry_run && [ "$installed_count" -gt 0 ]; then
    asdf reshim "$language"
  fi
}

# ============================================================================
# CARGO
# ============================================================================

install_cargo_packages() {
  local packages=("$@")
  local -a already_installed=()

  for pkg in "${packages[@]}"; do
    local bin_name crate_name
    bin_name=$(cargo_bin_name "$pkg")
    crate_name=$(cargo_crate_name "$pkg")

    if command -v "$bin_name" >/dev/null 2>&1; then
      already_installed+=("$crate_name")
      continue
    fi

    if is_dry_run "install cargo package: $crate_name"; then continue; fi

    local cargo_exit=0
    # openpgp-card-tool-git requires explicit framework linking on macOS
    if is_macos && [ "$crate_name" = "openpgp-card-tool-git" ]; then
      RUSTFLAGS="-C link-arg=-framework -C link-arg=AppKit -C link-arg=-framework -C link-arg=CoreServices" \
        cargo install "$crate_name" || cargo_exit=$?
    else
      cargo install "$crate_name" || cargo_exit=$?
    fi

    if [ "$cargo_exit" -eq 0 ]; then
      log_success "Installed $crate_name"
    else
      log_error "Failed to install $crate_name (exit code: $cargo_exit)"
    fi
  done

  log_skip_grouped "Cargo packages already installed" "${already_installed[@]+"${already_installed[@]}"}"
}

# ============================================================================
# HOMEBREW
# ============================================================================

pin_brew_packages() {
  local pinned_packages
  pinned_packages=$(brew list --pinned)
  local -a already_pinned=()

  for package in $(brew list --formula); do
    if ! echo "$pinned_packages" | grep -qxF "$package"; then
      if is_dry_run "pin: $package"; then continue; fi
      if ! brew pin "$package" 2>/dev/null; then
        log_error "Failed to pin: $package"
      else
        log_success "Pinned: $package"
      fi
    else
      already_pinned+=("$package")
    fi
  done

  log_skip_grouped "Already pinned" "${already_pinned[@]+"${already_pinned[@]}"}"
}

# ============================================================================
# VERIFICATION (used by doctor.sh)
# ============================================================================

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

# Verify that asdf-managed packages are installed (npm or go).
verify_asdf_packages() {
  local language="$1"
  shift
  local packages=("$@")

  for package in "${packages[@]}"; do
    case "$language" in
      "nodejs")
        local name
        name=$(npm_package_name "$package")
        if is_npm_pkg_installed "$package"; then
          log_success "npm: $name"
        else
          log_error "npm: $name: not installed"
        fi
        ;;
      "golang")
        local name
        name=$(go_binary_name "$package")
        check_binary "$name" "go: $name"
        ;;
    esac
  done
}

# Verify that cargo packages are installed.
verify_cargo_packages() {
  local packages=("$@")
  for pkg in "${packages[@]}"; do
    local bin_name
    bin_name=$(cargo_bin_name "$pkg")
    check_binary "$bin_name" "cargo: $(cargo_crate_name "$pkg")"
  done
}

# Verify that stow-managed symlinks exist in $HOME.
check_stow_links() {
  local -A checked_config_dirs
  local pkg_name
  while IFS= read -r pkg_name; do
    local pkg_dir="$STOW_DIR/$pkg_name/"

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
