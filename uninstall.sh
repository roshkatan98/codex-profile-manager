#!/usr/bin/env bash
set -euo pipefail

PURGE=0
YES=0
PURGE_EXTERNAL=0
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
INSTALL_DATA_DIR="${INSTALL_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-profile-manager}"
DEFAULT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/codex-profile-manager/config.env"
LEGACY_CONFIG="$HOME/.codex2keys.env"

usage() {
  cat <<'EOF_USAGE'
Usage: bash uninstall.sh [--purge] [--purge-external-profiles] [--yes]

Without --purge, the command removes installed executables and managed shell
functions only. It preserves configuration, profiles, authentication files,
shared Codex state, and backups.

--purge also removes the manager configuration and profile directories listed
in that configuration. Profiles outside HOME are skipped unless
--purge-external-profiles is also supplied. The original Codex home is never
removed.
EOF_USAGE
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
  read -r -p "Remove codex-profile-manager? [y/N] " answer
  case "$answer" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0 ;; esac
fi

for command_name in codexpm codex_smart codex_switch codex_add_account; do
  target="$INSTALL_BIN_DIR/$command_name"
  if [ -L "$target" ] || [ -f "$target" ]; then
    rm -f "$target"
  fi
done
rm -rf -- "${INSTALL_DATA_DIR:?}/bin" "${INSTALL_DATA_DIR:?}/lib"

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
      profile="${entry#*:}"
      if [ "$profile" = "$original_home" ]; then
        echo "Refusing to remove the original Codex home: $profile" >&2
        continue
      fi
      case "$profile/" in
        "$HOME"/*) rm -rf "$profile" ;;
        *)
          if [ "$PURGE_EXTERNAL" = "1" ]; then
            rm -rf "$profile"
          else
            echo "Skipping profile outside HOME: $profile" >&2
          fi
          ;;
      esac
    done
  fi

  rm -f "$CONFIG_FILE"
  if [ "$CONFIG_FILE" != "$LEGACY_CONFIG" ]; then
    rm -f "$LEGACY_CONFIG"
  fi
  rm -f "${CODEX_ACTIVE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/codex-profile-manager/active}"
  rmdir "$(dirname "$DEFAULT_CONFIG")" 2>/dev/null || true
fi

echo "Uninstall complete. Original Codex files and backups were not modified."
