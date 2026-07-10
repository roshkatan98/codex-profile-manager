#!/usr/bin/env bash
set -euo pipefail

PURGE=0
YES=0
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
INSTALL_DATA_DIR="${INSTALL_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-profile-manager}"
CONFIG_FILE="${CODEX_PROFILE_MANAGER_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/codex-profile-manager/config.env}"

usage() {
  cat <<'EOF_USAGE'
Usage: bash uninstall.sh [--purge] [--yes]

Without --purge, the command removes installed executables only. It preserves
configuration, profiles, authentication files, shared Codex state, and backups.

--purge also removes the manager configuration and profile directories listed
in that configuration. The original ~/.codex directory is never removed.
EOF_USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --purge) PURGE=1 ;;
    --yes) YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

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
rm -rf "$INSTALL_DATA_DIR/bin" "$INSTALL_DATA_DIR/lib"

if [ "$PURGE" = "1" ]; then
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    for entry in ${CODEX_ACCOUNTS:-}; do
      profile="${entry#*:}"
      case "$profile" in
        "$HOME"/.codex-*) rm -rf "$profile" ;;
        *) echo "Skipping non-standard profile path during purge: $profile" >&2 ;;
      esac
    done
    rm -f "$CONFIG_FILE"
    rmdir "$(dirname "$CONFIG_FILE")" 2>/dev/null || true
  fi
  rm -f "${CODEX_ACTIVE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/codex-profile-manager/active}"
fi

echo "Uninstall complete. Original Codex files were not modified."
