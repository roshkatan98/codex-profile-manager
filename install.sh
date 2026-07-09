#!/usr/bin/env bash
set -euo pipefail

# codex2keys installer
#
# Required or recommended variables:
#   CODEX_BIN              Path to the original Codex binary. Default: $HOME/.local/bin/codex
#   CODEX_ORIGINAL_HOME    Current Codex home. Default: $HOME/.codex
#   CODEX_ACCOUNTS         N-account map. Example: "1:$HOME/.codex-1 2:$HOME/.codex-2 3:$HOME/.codex-3"
#   CODEX_ACCOUNT_IDS      Used only if CODEX_ACCOUNTS is not set. Default: "1 2"
#   CODEX_ACTIVE_FILE      Active account marker. Default: $HOME/.codex-active
#   CODEX_LOCK_FILE        Lock file. Default: /tmp/codex-shared-state.lock
#   INSTALL_BIN_DIR        Target directory for wrappers. Default: $HOME/.local/bin
#   INSTALL_SHELL_FUNCTIONS  1 to append shell functions to ~/.bashrc. Default: 0

CODEX_BIN="${CODEX_BIN:-$HOME/.local/bin/codex}"
CODEX_ORIGINAL_HOME="${CODEX_ORIGINAL_HOME:-$HOME/.codex}"
CODEX_ACCOUNT_IDS="${CODEX_ACCOUNT_IDS:-1 2}"
CODEX_ACCOUNTS="${CODEX_ACCOUNTS:-}"
CODEX_ACTIVE_FILE="${CODEX_ACTIVE_FILE:-$HOME/.codex-active}"
CODEX_LOCK_FILE="${CODEX_LOCK_FILE:-/tmp/codex-shared-state.lock}"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
INSTALL_SHELL_FUNCTIONS="${INSTALL_SHELL_FUNCTIONS:-0}"
CONFIG_FILE="${CODEX2KEYS_CONFIG:-$HOME/.codex2keys.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "### $*"
}

if [ -z "$CODEX_ACCOUNTS" ]; then
  for id in $CODEX_ACCOUNT_IDS; do
    CODEX_ACCOUNTS="$CODEX_ACCOUNTS $id:$HOME/.codex-$id"
  done
  CODEX_ACCOUNTS="${CODEX_ACCOUNTS# }"
fi

account_ids() {
  local entry
  for entry in $CODEX_ACCOUNTS; do
    echo "${entry%%:*}"
  done
}

account_path() {
  local wanted="$1"
  local entry id path
  for entry in $CODEX_ACCOUNTS; do
    id="${entry%%:*}"
    path="${entry#*:}"
    if [ "$id" = "$wanted" ]; then
      echo "$path"
      return 0
    fi
  done
  return 1
}

first_account() {
  account_ids | head -n 1
}

account_count="$(account_ids | wc -l | tr -d ' ')"
[ "$account_count" -ge 2 ] || fail "At least two accounts are required. Set CODEX_ACCOUNTS or CODEX_ACCOUNT_IDS."
[ -x "$CODEX_BIN" ] || fail "CODEX_BIN is not executable: $CODEX_BIN"
[ -d "$CODEX_ORIGINAL_HOME" ] || fail "CODEX_ORIGINAL_HOME does not exist: $CODEX_ORIGINAL_HOME"
[ -f "$CODEX_ORIGINAL_HOME/auth.json" ] || fail "Missing auth.json in $CODEX_ORIGINAL_HOME. Log into Codex first."

info "Configuration"
cat <<EOF
CODEX_BIN=$CODEX_BIN
CODEX_ORIGINAL_HOME=$CODEX_ORIGINAL_HOME
CODEX_ACCOUNTS=$CODEX_ACCOUNTS
CODEX_ACTIVE_FILE=$CODEX_ACTIVE_FILE
CODEX_LOCK_FILE=$CODEX_LOCK_FILE
INSTALL_BIN_DIR=$INSTALL_BIN_DIR
CONFIG_FILE=$CONFIG_FILE
EOF

echo
read -r -p "Continue? [y/N] " answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) echo "Cancelled."; exit 0 ;;
esac

stamp="$(date +%Y%m%d_%H%M%S)"
backup="$CODEX_ORIGINAL_HOME.backup.codex2keys.$stamp"

info "Make sure Codex is not running"
if pgrep -af "codex" >/dev/null 2>&1; then
  pgrep -af "codex" || true
  echo
  read -r -p "Codex-related processes were found. Continue anyway? [y/N] " process_answer
  case "$process_answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 1 ;;
  esac
fi

info "Create backup"
cp -a "$CODEX_ORIGINAL_HOME" "$backup"
echo "Backup created: $backup"

info "Create profile directories"
for id in $(account_ids); do
  profile_dir="$(account_path "$id")"
  if [ -e "$profile_dir" ]; then
    fail "Profile directory already exists for account $id: $profile_dir"
  fi
  mkdir -p "$profile_dir"
done

mkdir -p "$INSTALL_BIN_DIR"

info "Copy auth.json separately and link shared Codex state"
for id in $(account_ids); do
  profile_dir="$(account_path "$id")"
  cp -a "$CODEX_ORIGINAL_HOME/auth.json" "$profile_dir/auth.json"
  chmod 600 "$profile_dir/auth.json"

  for item in "$CODEX_ORIGINAL_HOME"/* "$CODEX_ORIGINAL_HOME"/.[!.]*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"

    if [ "$name" = "auth.json" ]; then
      continue
    fi

    ln -s "$item" "$profile_dir/$name"
  done

  chmod 700 "$profile_dir"
done

info "Write config file"
cat > "$CONFIG_FILE" <<EOF
# codex2keys configuration
CODEX_BIN="$CODEX_BIN"
CODEX_ORIGINAL_HOME="$CODEX_ORIGINAL_HOME"
CODEX_ACCOUNTS="$CODEX_ACCOUNTS"
CODEX_ACTIVE_FILE="$CODEX_ACTIVE_FILE"
CODEX_LOCK_FILE="$CODEX_LOCK_FILE"
EOF
chmod 600 "$CONFIG_FILE"

info "Install wrapper scripts"
install -m 755 "$SCRIPT_DIR/scripts/codex_smart" "$INSTALL_BIN_DIR/codex_smart"
install -m 755 "$SCRIPT_DIR/scripts/codex_switch" "$INSTALL_BIN_DIR/codex_switch"
install -m 755 "$SCRIPT_DIR/scripts/codex_add_account" "$INSTALL_BIN_DIR/codex_add_account"

info "Set default active account"
first="$(first_account)"
echo "$first" > "$CODEX_ACTIVE_FILE"
chmod 600 "$CODEX_ACTIVE_FILE"

if [ "$INSTALL_SHELL_FUNCTIONS" = "1" ]; then
  info "Append shell functions to ~/.bashrc"
  cat "$SCRIPT_DIR/templates/bashrc-snippet.sh" >> "$HOME/.bashrc"
  echo "Shell functions appended. Reload with: source ~/.bashrc"
else
  info "Shell functions not installed automatically"
  echo "To make 'codex' run the smart wrapper without modifying the original binary, append templates/bashrc-snippet.sh to your shell rc file."
fi

info "Verify profiles"
for id in $(account_ids); do
  profile_dir="$(account_path "$id")"
  echo
  echo "Account $id: $profile_dir"
  CODEX_HOME="$profile_dir" "$CODEX_BIN" login status || true
done

cat <<EOF

Done.

Each generated profile currently has a copy of the original auth.json.
Keep account $first as-is if it represents your primary account.
For every additional account, login that profile with the intended account, for example:

  CODEX_HOME="$(account_path "$(account_ids | sed -n '2p')")" "$CODEX_BIN" logout || true
  CODEX_HOME="$(account_path "$(account_ids | sed -n '2p')")" "$CODEX_BIN" login --device-auth

Verify all auth files are different:

  sha256sum $(for id in $(account_ids); do printf '"%s/auth.json" ' "$(account_path "$id")"; done)

Usage:

  codex_smart          # resume last session with active account
  codex_smart new      # open new session
  codex_smart status   # show all account statuses
  codex_switch         # rotate to the next account
  codex_switch 1       # set a specific account id
  codex_add_account 3  # add another account later
EOF
