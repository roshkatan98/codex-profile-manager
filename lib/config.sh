#!/usr/bin/env bash

CODEXPM_NAME="codex-profile-manager"
CODEXPM_VERSION="1.0.0"
CODEXPM_DEFAULT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/codex-profile-manager/config.env"
CODEXPM_LEGACY_CONFIG="$HOME/.codex2keys.env"

codexpm_find_config() {
  if [ -n "${CODEX_PROFILE_MANAGER_CONFIG:-}" ]; then
    printf '%s\n' "$CODEX_PROFILE_MANAGER_CONFIG"
  elif [ -f "$CODEXPM_DEFAULT_CONFIG" ]; then
    printf '%s\n' "$CODEXPM_DEFAULT_CONFIG"
  elif [ -f "$CODEXPM_LEGACY_CONFIG" ]; then
    printf '%s\n' "$CODEXPM_LEGACY_CONFIG"
  else
    printf '%s\n' "$CODEXPM_DEFAULT_CONFIG"
  fi
}

codexpm_load_config() {
  CODEXPM_CONFIG_FILE="$(codexpm_find_config)"
  CODEXPM_USING_LEGACY_CONFIG=0

  if [ -f "$CODEXPM_CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CODEXPM_CONFIG_FILE"
    if [ "$CODEXPM_CONFIG_FILE" = "$CODEXPM_LEGACY_CONFIG" ]; then
      CODEXPM_USING_LEGACY_CONFIG=1
    fi
  fi

  CODEX_BIN="${CODEX_BIN:-$HOME/.local/bin/codex}"
  CODEX_ORIGINAL_HOME="${CODEX_ORIGINAL_HOME:-$HOME/.codex}"
  CODEX_ACTIVE_FILE="${CODEX_ACTIVE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/codex-profile-manager/active}"
  CODEX_LOCK_FILE="${CODEX_LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/codex-profile-manager-${UID}.lock}"
  CODEX_BACKUP_DIR="${CODEX_BACKUP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-profile-manager/backups}"
  CODEX_PROMPT_AFTER_EXIT="${CODEX_PROMPT_AFTER_EXIT:-1}"
  CODEX_SHARED_ITEMS="${CODEX_SHARED_ITEMS:-config.toml sessions history.jsonl session_index.jsonl memories attachments skills rules prompts archived_sessions state_*.sqlite state_*.sqlite-*}"

  if [ -z "${CODEX_ACCOUNTS:-}" ]; then
    if [ -n "${CODEX_PROFILE_1:-}" ] || [ -n "${CODEX_PROFILE_2:-}" ]; then
      CODEX_PROFILE_1="${CODEX_PROFILE_1:-$HOME/.codex-1}"
      CODEX_PROFILE_2="${CODEX_PROFILE_2:-$HOME/.codex-2}"
      CODEX_ACCOUNTS="1:$CODEX_PROFILE_1 2:$CODEX_PROFILE_2"
    else
      CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2"
    fi
  fi
}

codexpm_validate_id() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

codexpm_validate_config() {
  local seen=" " entry id path

  [ -n "$CODEX_ACCOUNTS" ] || {
    echo "CODEX_ACCOUNTS is empty." >&2
    return 1
  }

  for entry in $CODEX_ACCOUNTS; do
    case "$entry" in
      *:*) ;;
      *) echo "Invalid CODEX_ACCOUNTS entry: $entry" >&2; return 1 ;;
    esac

    id="${entry%%:*}"
    path="${entry#*:}"

    codexpm_validate_id "$id" || {
      echo "Invalid account id: $id" >&2
      return 1
    }

    [ -n "$path" ] || {
      echo "Missing profile path for account: $id" >&2
      return 1
    }

    case "$path" in
      *' '*) echo "Profile paths cannot contain spaces: $path" >&2; return 1 ;;
    esac

    case "$seen" in
      *" $id "*) echo "Duplicate account id: $id" >&2; return 1 ;;
    esac
    seen="$seen$id "
  done

  return 0
}

codexpm_write_config() {
  local target="${1:-$CODEXPM_DEFAULT_CONFIG}"
  local parent
  parent="$(dirname "$target")"
  mkdir -p "$parent"

  cat > "$target" <<EOF_CONFIG
# codex-profile-manager configuration
CODEX_BIN="$CODEX_BIN"
CODEX_ORIGINAL_HOME="$CODEX_ORIGINAL_HOME"
CODEX_ACCOUNTS="$CODEX_ACCOUNTS"
CODEX_ACTIVE_FILE="$CODEX_ACTIVE_FILE"
CODEX_LOCK_FILE="$CODEX_LOCK_FILE"
CODEX_BACKUP_DIR="$CODEX_BACKUP_DIR"
CODEX_PROMPT_AFTER_EXIT="$CODEX_PROMPT_AFTER_EXIT"
CODEX_SHARED_ITEMS="$CODEX_SHARED_ITEMS"
EOF_CONFIG
  chmod 600 "$target"
  CODEXPM_CONFIG_FILE="$target"
}
