#!/usr/bin/env bash

CODEXPM_NAME="codex-profile-manager"
CODEXPM_VERSION="1.1.1"
CODEXPM_PROFILE_MARKER=".codex-profile-manager-profile"
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

codexpm_config_write_target() {
  if [ -n "${CODEX_PROFILE_MANAGER_CONFIG:-}" ]; then
    printf '%s\n' "$CODEX_PROFILE_MANAGER_CONFIG"
  elif [ "${CODEXPM_USING_LEGACY_CONFIG:-0}" = "1" ]; then
    printf '%s\n' "$CODEXPM_DEFAULT_CONFIG"
  else
    printf '%s\n' "${CODEXPM_CONFIG_FILE:-$CODEXPM_DEFAULT_CONFIG}"
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
  local seen_ids=" " seen_paths=" " entry id path
  local -a entries

  [ -n "$CODEX_ACCOUNTS" ] || {
    echo "CODEX_ACCOUNTS is empty." >&2
    return 1
  }

  case "$CODEX_BIN" in
    /*) ;;
    *) echo "CODEX_BIN must be an absolute path: $CODEX_BIN" >&2; return 1 ;;
  esac

  case "$CODEX_ORIGINAL_HOME" in
    /*) ;;
    *) echo "CODEX_ORIGINAL_HOME must be an absolute path: $CODEX_ORIGINAL_HOME" >&2; return 1 ;;
  esac

  case "$CODEX_ACTIVE_FILE" in
    /*) ;;
    *) echo "CODEX_ACTIVE_FILE must be an absolute path: $CODEX_ACTIVE_FILE" >&2; return 1 ;;
  esac

  case "$CODEX_LOCK_FILE" in
    /*) ;;
    *) echo "CODEX_LOCK_FILE must be an absolute path: $CODEX_LOCK_FILE" >&2; return 1 ;;
  esac

  case "$CODEX_BACKUP_DIR" in
    /*) ;;
    *) echo "CODEX_BACKUP_DIR must be an absolute path: $CODEX_BACKUP_DIR" >&2; return 1 ;;
  esac

  case "$CODEX_PROMPT_AFTER_EXIT" in
    0|1) ;;
    *) echo "CODEX_PROMPT_AFTER_EXIT must be 0 or 1." >&2; return 1 ;;
  esac

  read -r -a entries <<< "$CODEX_ACCOUNTS"
  for entry in "${entries[@]}"; do
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

    case "$path" in
      /*) ;;
      '') echo "Missing profile path for account: $id" >&2; return 1 ;;
      *) echo "Profile paths must be absolute: $path" >&2; return 1 ;;
    esac

    case "$path" in
      *' '*) echo "Profile paths cannot contain spaces: $path" >&2; return 1 ;;
    esac

    if [ "$path" = "$CODEX_ORIGINAL_HOME" ]; then
      echo "A profile cannot be the original Codex home: $path" >&2
      return 1
    fi

    case "$path/" in
      "$CODEX_ORIGINAL_HOME"/*)
        echo "Profile directories cannot be inside CODEX_ORIGINAL_HOME: $path" >&2
        return 1
        ;;
    esac

    case "$seen_ids" in
      *" $id "*) echo "Duplicate account id: $id" >&2; return 1 ;;
    esac
    case "$seen_paths" in
      *" $path "*) echo "Duplicate profile path: $path" >&2; return 1 ;;
    esac
    seen_ids="$seen_ids$id "
    seen_paths="$seen_paths$path "
  done

  return 0
}

codexpm_write_config() {
  local target="${1:-$(codexpm_config_write_target)}"
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
  CODEXPM_USING_LEGACY_CONFIG=0
}
