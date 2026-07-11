#!/usr/bin/env bash

CODEXPM_UPDATE_REPOSITORY="${CODEXPM_UPDATE_REPOSITORY:-roshkatan98/codex-profile-manager}"

codexpm_update_usage() {
  cat <<'EOF_USAGE'
Usage: codexpm update [--check] [--yes]

Options:
  --check  Check whether a newer stable release is available
  --yes    Install the update without an additional confirmation prompt
EOF_USAGE
}

codexpm_update_validate_tag() {
  [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

codexpm_update_version_value() {
  printf '%s\n' "${1#v}"
}

codexpm_update_compare_versions() {
  local current latest first
  current="$(codexpm_update_version_value "$1")"
  latest="$(codexpm_update_version_value "$2")"

  if [ "$current" = "$latest" ]; then
    printf '0\n'
    return 0
  fi

  first="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | head -n 1)"
  if [ "$first" = "$current" ]; then
    printf '%s\n' '-1'
  else
    printf '1\n'
  fi
}

codexpm_update_latest_tag() {
  local latest_url resolved tag

  if [ -n "${CODEXPM_UPDATE_LATEST_TAG:-}" ]; then
    tag="$CODEXPM_UPDATE_LATEST_TAG"
  else
    latest_url="https://github.com/$CODEXPM_UPDATE_REPOSITORY/releases/latest"

    if command -v curl >/dev/null 2>&1; then
      resolved="$(curl -fsSL --proto '=https' --tlsv1.2 -o /dev/null -w '%{url_effective}' "$latest_url")"
    elif command -v wget >/dev/null 2>&1; then
      resolved="$(wget -q --max-redirect=10 --server-response --spider "$latest_url" 2>&1 \
        | awk '/^[[:space:]]*Location:/ {print $2}' \
        | tr -d '\r' \
        | tail -n 1)"
    else
      echo "Updating requires curl or wget." >&2
      return 1
    fi

    tag="${resolved##*/}"
  fi

  codexpm_update_validate_tag "$tag" || {
    echo "Could not determine a valid stable release tag: $tag" >&2
    return 1
  }

  printf '%s\n' "$tag"
}

codexpm_update_download_archive() {
  local tag="$1" destination="$2" url

  if [ -n "${CODEXPM_UPDATE_ARCHIVE:-}" ]; then
    [ -f "$CODEXPM_UPDATE_ARCHIVE" ] || {
      echo "Update archive does not exist: $CODEXPM_UPDATE_ARCHIVE" >&2
      return 1
    }
    cp "$CODEXPM_UPDATE_ARCHIVE" "$destination"
    return 0
  fi

  url="https://github.com/$CODEXPM_UPDATE_REPOSITORY/archive/refs/tags/$tag.tar.gz"
  echo "Downloading $tag..."

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 "$url" -o "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$destination"
  else
    echo "Updating requires curl or wget." >&2
    return 1
  fi
}

codexpm_update_command() {
  local bin_dir="$1" check_only=0 yes=0 latest comparison answer
  local temp archive source_dir install_data_dir install_bin_dir command_path
  shift

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) check_only=1 ;;
      --yes) yes=1 ;;
      --help|-h) codexpm_update_usage; return 0 ;;
      *) echo "Unknown update option: $1" >&2; codexpm_update_usage >&2; return 1 ;;
    esac
    shift
  done

  latest="$(codexpm_update_latest_tag)"
  comparison="$(codexpm_update_compare_versions "$CODEXPM_VERSION" "$latest")"

  printf 'Installed version: %s\n' "$CODEXPM_VERSION"
  printf 'Latest release:   %s\n' "${latest#v}"

  case "$comparison" in
    0)
      echo "codex-profile-manager is already up to date."
      return 0
      ;;
    1)
      echo "The installed version is newer than the latest stable release."
      return 0
      ;;
  esac

  if [ "$check_only" = "1" ]; then
    echo "An update is available. Run 'codexpm update' to install it."
    return 0
  fi

  if [ "$yes" != "1" ]; then
    [ -t 0 ] || {
      echo "Run with --yes when standard input is not interactive." >&2
      return 1
    }
    echo
    read -r -p "Update to ${latest#v}? [y/N] " answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "Cancelled."; return 0 ;;
    esac
  fi

  command_path="$(command -v codexpm 2>/dev/null || true)"
  [ -n "$command_path" ] || {
    echo "The built-in updater requires an installed codexpm command." >&2
    echo "Update from the repository checkout with: bash install.sh --upgrade" >&2
    return 1
  }

  install_bin_dir="${INSTALL_BIN_DIR:-$(dirname "$command_path")}"
  install_data_dir="${INSTALL_DATA_DIR:-$(cd "$bin_dir/.." && pwd)}"
  temp="$(mktemp -d)"
  archive="$temp/release.tar.gz"
  trap 'rm -rf "$temp"' RETURN

  codexpm_update_download_archive "$latest" "$archive"

  if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    echo "Refusing an archive with unsafe paths." >&2
    return 1
  fi

  tar -xzf "$archive" -C "$temp"
  source_dir="$(find "$temp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

  [ -f "$source_dir/install.sh" ] \
    && [ -f "$source_dir/bin/codexpm" ] \
    && [ -f "$source_dir/lib/config.sh" ] || {
      echo "The downloaded release archive is incomplete." >&2
      return 1
    }

  echo "Installing ${latest#v}..."
  CODEX_PROFILE_MANAGER_CONFIG="$CODEXPM_CONFIG_FILE" \
  INSTALL_BIN_DIR="$install_bin_dir" \
  INSTALL_DATA_DIR="$install_data_dir" \
    bash "$source_dir/install.sh" --upgrade --yes --skip-backup

  "$install_data_dir/bin/codexpm" doctor
  echo "Update complete: $CODEXPM_VERSION -> ${latest#v}"
}
