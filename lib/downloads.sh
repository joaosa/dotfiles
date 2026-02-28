#!/usr/bin/env bash
# Temp-file cleanup and download with integrity verification

_TEMP_FILES=()

register_temp_file() { _TEMP_FILES+=("$1"); }

_cleanup_temp_files() {
  for f in "${_TEMP_FILES[@]+"${_TEMP_FILES[@]}"}"; do rm -f "$f" 2>/dev/null; done
}

trap _cleanup_temp_files EXIT INT TERM

download_if_missing() {
  local file_path="$1"
  local url="$2"
  local expected_sha256="$3"
  local filename
  filename=$(basename "$file_path")

  if [ -f "$file_path" ]; then
    if [ -n "$expected_sha256" ]; then
      local actual_sha256
      actual_sha256=$(sha256sum_portable "$file_path" | awk '{print $1}')
      if [ "$actual_sha256" = "$expected_sha256" ]; then
        log_skip "$filename (checksum verified)"
        return 0
      else
        if is_dry_run "re-download $filename (checksum mismatch)"; then return 0; fi
        log_warn "Existing file has incorrect checksum, re-downloading..."
        rm -f "$file_path"
      fi
    else
      log_skip "$filename (already exists)"
      return 0
    fi
  fi

  if is_dry_run "download $filename"; then return 0; fi

  log_info "Downloading: $filename"
  mkdir -p "$(dirname "$file_path")"
  local temp_file="${file_path}.tmp"
  register_temp_file "$temp_file"

  if ! curl -fsSL -m 120 -o "$temp_file" "$url"; then
    rm -f "$temp_file"
    log_error "Failed to download $filename"
    return 1
  fi

  if [ -n "$expected_sha256" ]; then
    local actual_sha256
    actual_sha256=$(sha256sum_portable "$temp_file" | awk '{print $1}')
    if [ "$actual_sha256" != "$expected_sha256" ]; then
      rm -f "$temp_file"
      log_error "Checksum verification failed for $filename"
      log_detail "Expected: $expected_sha256"
      log_detail "Got:      $actual_sha256"
      return 1
    fi
  fi

  mv "$temp_file" "$file_path"
  log_success "Downloaded: $filename"
}
