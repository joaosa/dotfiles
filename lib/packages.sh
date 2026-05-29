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

install_go_packages() {
  local packages=("$@")
  local -a already_installed=()

  for package in "${packages[@]}"; do
    local bin_name install_exit=0
    bin_name=$(go_binary_name "$package")

    if command -v "$bin_name" >/dev/null 2>&1; then
      already_installed+=("$bin_name")
      continue
    fi

    if is_dry_run "install Go package: $bin_name"; then continue; fi

    log_info "Installing Go package: $package"
    go install "$package" || install_exit=$?

    if [ "$install_exit" -eq 0 ]; then
      log_success "Installed Go package: $bin_name"
    else
      log_error "Failed to install Go package: $bin_name"
    fi
  done

  log_skip_grouped "Go packages already installed" "${already_installed[@]+"${already_installed[@]}"}"
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

    # Check ~/.cargo/bin first to avoid system binary conflicts (e.g. /usr/sbin/asr)
    if [ -x "$HOME/.cargo/bin/$bin_name" ]; then
      already_installed+=("$crate_name")
      continue
    fi

    if is_dry_run "install cargo package: $crate_name"; then continue; fi

    local cargo_exit=0
    # openpgp-card-tool-git requires explicit framework linking on macOS
    if is_macos && [ "$crate_name" = "openpgp-card-tool-git" ]; then
      RUSTFLAGS="-C link-arg=-framework -C link-arg=AppKit -C link-arg=-framework -C link-arg=CoreServices" \
        cargo install "$crate_name" || cargo_exit=$?
    elif [ "$crate_name" = "qwen-asr-cli" ]; then
      RUSTFLAGS="-C target-cpu=native" cargo install "$crate_name" || cargo_exit=$?
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

check_dir() {
  local path="$1" description="${2:-$1}"
  if [ -d "$path" ]; then
    log_success "$description"
  else
    log_error "$description: missing"
  fi
}

# Verify that cargo packages are installed.
verify_cargo_packages() {
  local packages=("$@")
  for pkg in "${packages[@]}"; do
    local bin_name
    bin_name=$(cargo_bin_name "$pkg")
    check_file "$HOME/.cargo/bin/$bin_name" "cargo: $(cargo_crate_name "$pkg")"
  done
}

# Verify that Go-installed tools are available.
verify_go_packages() {
  local packages=("$@")
  for pkg in "${packages[@]}"; do
    local bin_name
    bin_name=$(go_binary_name "$pkg")
    check_binary "$bin_name" "go: $bin_name"
  done
}
