#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$ROOT_DIR/lib/config.sh"
# shellcheck source=lib/profiles.sh
source "$ROOT_DIR/lib/profiles.sh"
# shellcheck source=lib/backup.sh
source "$ROOT_DIR/lib/backup.sh"

YES=0
DRY_RUN=0
UPGRADE=0
SKIP_BACKUP=0
INSTALL_SHELL_FUNCTIONS="${INSTALL_SHELL_FUNCTIONS:-0}"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
INSTALL_DATA_DIR="${INSTALL_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-profile-manager}"

usage() {
  cat <<'EOF_USAGE'
Usage: bash install.sh [options]

Options:
  --yes                     Do not ask for confirmation
  --dry-run                 Show the plan without changing files
  --upgrade                 Upgrade an existing installation in place
  --skip-backup             Skip the automatic Codex-home backup
  --install-shell-functions Add the optional codex()/codexr() functions to ~/.bashrc
  --help                     Show this help

Configuration may be supplied through environment variables. Example:

  CODEX_BIN="$HOME/.local/bin/codex" \
  CODEX_ORIGINAL_HOME="$HOME/.codex" \
  CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2 3:$HOME/.codex-3" \
  bash install.sh
EOF_USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --upgrade) UPGRADE=1 ;;
    --skip-backup) SKIP_BACKUP=1 ;;
    --install-shell-functions) INSTALL_SHELL_FUNCTIONS=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

codexpm_load_config
codexpm_validate_config

[ -x "$CODEX_BIN" ] || {
  echo "Codex binary is not executable: $CODEX_BIN" >&2
  exit 1
}
[ -d "$CODEX_ORIGINAL_HOME" ] || {
  echo "Original Codex home is missing: $CODEX_ORIGINAL_HOME" >&2
  exit 1
}

first_account="$(codexpm_first_account)"
new_config="$(codexpm_config_write_target)"

cat <<EOF_PLAN
codex-profile-manager installation plan

Codex binary:      $CODEX_BIN
Original home:     $CODEX_ORIGINAL_HOME
Accounts:          $CODEX_ACCOUNTS
Shared items:      $CODEX_SHARED_ITEMS
Config file:       $new_config
Install data:      $INSTALL_DATA_DIR
Install binaries:  $INSTALL_BIN_DIR
Backup directory:  $CODEX_BACKUP_DIR
Upgrade mode:      $UPGRADE
Dry-run:           $DRY_RUN
EOF_PLAN

if [ "$YES" != "1" ]; then
  echo
  read -r -p "Continue? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
fi

if [ "$DRY_RUN" = "1" ]; then
  echo
  echo "Dry-run complete. No files were changed."
  exit 0
fi

if [ "$UPGRADE" != "1" ] && [ -f "$new_config" ]; then
  echo "A configuration already exists: $new_config" >&2
  echo "Rerun with --upgrade." >&2
  exit 1
fi

if [ "$UPGRADE" != "1" ]; then
  while IFS= read -r id; do
    profile="$(codexpm_account_path "$id")"
    if [ -e "$profile" ] || [ -L "$profile" ]; then
      echo "A configured profile already exists: $profile" >&2
      echo "Rerun with --upgrade to migrate an existing installation." >&2
      exit 1
    fi
  done < <(codexpm_account_ids)

  [ -f "$CODEX_ORIGINAL_HOME/auth.json" ] || {
    echo "Original auth.json is missing: $CODEX_ORIGINAL_HOME/auth.json" >&2
    echo "Log into Codex once before installing." >&2
    exit 1
  }
fi

if pgrep -af -- "$CODEX_BIN" >/dev/null 2>&1; then
  echo "A process using the configured Codex binary appears to be running:" >&2
  pgrep -af -- "$CODEX_BIN" >&2 || true
  echo "Close it before installing or upgrading." >&2
  exit 1
fi

codexpm_backup_home "$SKIP_BACKUP"

mkdir -p "$INSTALL_DATA_DIR/bin" "$INSTALL_DATA_DIR/lib" "$INSTALL_BIN_DIR"
install -m 755 "$ROOT_DIR/bin/codexpm" "$INSTALL_DATA_DIR/bin/codexpm"
install -m 755 "$ROOT_DIR/bin/codex_smart" "$INSTALL_DATA_DIR/bin/codex_smart"
install -m 755 "$ROOT_DIR/bin/codex_switch" "$INSTALL_DATA_DIR/bin/codex_switch"
install -m 755 "$ROOT_DIR/bin/codex_add_account" "$INSTALL_DATA_DIR/bin/codex_add_account"
install -m 644 "$ROOT_DIR/lib/config.sh" "$INSTALL_DATA_DIR/lib/config.sh"
install -m 644 "$ROOT_DIR/lib/profiles.sh" "$INSTALL_DATA_DIR/lib/profiles.sh"
install -m 644 "$ROOT_DIR/lib/backup.sh" "$INSTALL_DATA_DIR/lib/backup.sh"

for command_name in codexpm codex_smart codex_switch codex_add_account; do
  ln -sfn "$INSTALL_DATA_DIR/bin/$command_name" "$INSTALL_BIN_DIR/$command_name"
done

while IFS= read -r id; do
  profile="$(codexpm_account_path "$id")"
  if [ -d "$profile" ]; then
    codexpm_migrate_profile_links "$profile"
    continue
  fi

  if [ "$id" = "$first_account" ]; then
    codexpm_create_profile "$id" "$profile" 1
  else
    codexpm_create_profile "$id" "$profile" 0
  fi
done < <(codexpm_account_ids)

codexpm_write_config "$new_config"
mkdir -p "$(dirname "$CODEX_ACTIVE_FILE")"
if [ ! -f "$CODEX_ACTIVE_FILE" ]; then
  printf '%s\n' "$first_account" > "$CODEX_ACTIVE_FILE"
fi
chmod 600 "$CODEX_ACTIVE_FILE"

if [ "$INSTALL_SHELL_FUNCTIONS" = "1" ]; then
  begin_marker="# >>> codex-profile-manager >>>"
  end_marker="# <<< codex-profile-manager <<<"
  tmp="$(mktemp)"
  awk -v begin="$begin_marker" -v end="$end_marker" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$HOME/.bashrc" 2>/dev/null > "$tmp" || true
  cat "$ROOT_DIR/templates/bashrc-snippet.sh" >> "$tmp"
  mv "$tmp" "$HOME/.bashrc"
fi

cat <<EOF_DONE

Installation complete.

Config:
  $new_config

Run diagnostics:
  $INSTALL_BIN_DIR/codexpm doctor

Profiles other than the first account intentionally received no auth.json.
Login each additional profile explicitly, for example:
  $INSTALL_BIN_DIR/codexpm login 2

The original Codex binary was not modified.
EOF_DONE

if [ "$CODEXPM_USING_LEGACY_CONFIG" = "1" ]; then
  echo
  echo "Legacy config detected at: $CODEXPM_LEGACY_CONFIG"
  echo "It was migrated to the new config location and left in place for rollback."
fi
