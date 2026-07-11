#!/usr/bin/env bash
set -euo pipefail

PURGE=0
YES=0
PURGE_EXTERNAL=0
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
INSTALL_DATA_DIR="${INSTALL_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-profile-manager}"
DEFAULT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/codex-profile-manager/config.env"
LEGACY_CONFIG="$HOME/.codex2keys.env"
PROFILE_MARKER=".codex-profile-manager-profile"

usage() {
  cat <<'EOF_USAGE'
Usage: bash uninstall.sh [--purge] [--purge-external-profiles] [--yes]

Without --purge, the command removes codex-profile-manager commands and shell
integration. Profiles, configuration, authentication files, and backups remain.

--purge also removes verified manager profile directories and configuration,
returning the shell to the original Codex setup. Profiles outside HOME are
skipped unless --purge-external-profiles is supplied. The original Codex home
and backups are never removed.
EOF_USAGE
}

safe_delete_profile() {
  local id="$1" profile="$2" original_home="$3" marker
  marker="$profile/$PROFILE_MARKER"

  if [ "$profile" = "/" ] || [ "$profile" = "$HOME" ] || [ "$profile" = "$original_home" ]; then
    echo "Refusing to remove unsafe profile path: $profile" >&2
    return 1
  fi

  case "$profile/" in
    "$original_home"/*)
      echo "Refusing to remove a profile inside the original Codex home: $profile" >&2
      return 1
      ;;
  esac

  if [ ! -d "$profile" ]; then
    return 0
  fi

  if [ -L "$profile" ] || [ ! -f "$marker" ] || [ -L "$marker" ]; then
    echo "Skipping unverified profile directory: $profile" >&2
    return 1
  fi

  grep -Fqx 'managed_by=codex-profile-manager' "$marker" || {
    echo "Skipping profile with an invalid manager marker: $profile" >&2
    return 1
  }
  grep -Fqx "profile_id=$id" "$marker" || {
    echo "Skipping profile with a mismatched id: $profile" >&2
    return 1
  }
  grep -Fqx "original_home=$original_home" "$marker" || {
    echo "Skipping profile with a mismatched original home: $profile" >&2
    return 1
  }

  case "$profile/" in
    "$HOME"/*) ;;
    *)
      if [ "$PURGE_EXTERNAL" != "1" ]; then
        echo "Skipping profile outside HOME: $profile" >&2
        return 1
      fi
      ;;
  esac

  rm -rf -- "${profile:?}"
  echo "Removed profile files: $profile"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --purge) PURGE=1 ;;
    --purge-external-profiles) PURGE_EXTERNAL=1 ;;
    --yes) YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if [ -n "${CODEX_PROFILE_MANAGER_CONFIG:-}" ]; then
  CONFIG_FILE="$CODEX_PROFILE_MANAGER_CONFIG"
elif [ -f "$DEFAULT_CONFIG" ]; then
  CONFIG_FILE="$DEFAULT_CONFIG"
elif [ -f "$LEGACY_CONFIG" ]; then
  CONFIG_FILE="$LEGACY_CONFIG"
else
  CONFIG_FILE="$DEFAULT_CONFIG"
fi

if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

if [ -n "${CODEX_BIN:-}" ] && pgrep -af -- "$CODEX_BIN" >/dev/null 2>&1; then
  echo "A process using the configured Codex binary appears to be running:" >&2
  pgrep -af -- "$CODEX_BIN" >&2 || true
  echo "Close it before uninstalling." >&2
  exit 1
fi

if [ "$YES" != "1" ]; then
  echo "This will remove codex-profile-manager commands and shell integration."
  if [ "$PURGE" = "1" ]; then
    echo "Managed profile directories and configuration will also be removed."
  else
    echo "Profile directories and configuration will be preserved."
  fi
  echo "The original Codex home and binary will not be changed."
  echo
  read -r -p "Continue? [y/N] " answer
  case "$answer" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0 ;; esac
fi

if [ -f "$HOME/.bashrc" ]; then
  begin_marker="# >>> codex-profile-manager >>>"
  end_marker="# <<< codex-profile-manager <<<"
  tmp="$(mktemp)"
  awk -v begin="$begin_marker" -v end="$end_marker" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$HOME/.bashrc" > "$tmp"
  cat "$tmp" > "$HOME/.bashrc"
  rm -f "$tmp"
fi

if [ "$PURGE" = "1" ]; then
  original_home="${CODEX_ORIGINAL_HOME:-$HOME/.codex}"
  if [ -n "${CODEX_ACCOUNTS:-}" ]; then
    read -r -a entries <<< "$CODEX_ACCOUNTS"
    for entry in "${entries[@]}"; do
      id="${entry%%:*}"
      profile="${entry#*:}"
      safe_delete_profile "$id" "$profile" "$original_home" || true
    done
  fi

  rm -f "$CONFIG_FILE"
  if [ "$CONFIG_FILE" != "$LEGACY_CONFIG" ]; then
    rm -f "$LEGACY_CONFIG"
  fi
  rm -f "${CODEX_ACTIVE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/codex-profile-manager/active}"
  rmdir "$(dirname "$DEFAULT_CONFIG")" 2>/dev/null || true
fi

for command_name in codexpm codex_smart codex_switch codex_add_account; do
  target="$INSTALL_BIN_DIR/$command_name"
  if [ -L "$target" ] || [ -f "$target" ]; then
    rm -f "$target"
  fi
done

rm -rf -- "${INSTALL_DATA_DIR:?}/bin" "${INSTALL_DATA_DIR:?}/lib"
rm -f "$INSTALL_DATA_DIR/uninstall.sh"
rmdir "$INSTALL_DATA_DIR" 2>/dev/null || true

echo
if [ "$PURGE" = "1" ]; then
  echo "codex-profile-manager was removed. The original Codex setup remains available."
else
  echo "codex-profile-manager commands were removed. Profiles and configuration were preserved."
fi
echo "Backups were not modified."
