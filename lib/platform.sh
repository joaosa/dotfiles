#!/usr/bin/env bash
# Platform detection and OS-portable utilities

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

is_macos() { [ "$OS" = "darwin" ]; }
is_linux() { [ "$OS" = "linux" ]; }

sha256sum_portable() {
  if is_macos; then shasum -a 256 "$@"; else sha256sum "$@"; fi
}

sed_inplace() {
  if is_macos; then sed -i '' "$@"; else sed -i "$@"; fi
}
