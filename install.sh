#!/usr/bin/env bash
set -euo pipefail

# codex2keys installer
#
# Required or recommended variables:
#   CODEX_BIN             Path to the original Codex binary. Default: $HOME/.local/bin/codex
#   CODEX_ORIGINAL_HOME   Current Codex home. Default: $HOME/.codex
#   CODEX_PROFILE_1       Profile 1 home. Default: $HOME/.codex-1
#   CODEX_PROFILE_2       Profile 2 home. Default: $HOME/.codex-2
#   CODEX_ACTIVE_FILE     Active account marker. Default: $HOME/.codex-active
#   CODEX_LOCK_FILE       Lock file. Default: /tmp/codex-shared-state.lock
#   INSTALL_BIN_DIR       Target directory for wrappers. Default: $HOME/.local/bin
#   INSTALL_SHELL_FUNCTIONS  1 to append shell functions to ~/.bashrc. Default: 0

CODEX_BIN="${CODEX_BIN:-$HOME/.local/bin/codex}"
CODEX_ORIGINAL_HOME="${CODEX_ORIGINAL_HOME:-$HOME/.codex}"
CODEX_PROFILE_1="${CODEX_PROFILE_1:-$HOME/.codex-1}"
CODEX_PROFILE_2="${CODEX_PROFILE_2:-$HOME/.codex-2}"
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

[ -x "$CODEX_BIN" ] || fail "CODEX_BIN is not executable: $CODEX_BIN"
[ -d "$CODEX_ORIGINAL_HOME" ] || fail "CODEX_ORIGINAL_HOME does not exist: $CODEX_ORIGINAL_HOME"
[ -f "$CODEX_ORIGINAL_HOME/auth.json" ] || fail "Missing auth.json in $CODEX_ORIGINAL_HOME. Log into Codex first."

info "Configuration"
cat <<EOF
CODEX_BIN=$CODEX_BIN
CODEX_ORIGINAL_HOME=$CODEX_ORIGINAL_HOME
CODEX_PROFILE_1=$CODEX_PROFILE_1
CODEX_PROFILE_2=$CODEX_PROFILE_2
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
if [ -e "$CODEX_PROFILE_1" ] || [ -e "$CODEX_PROFILE_2" ]; then
  fail "Profile directory already exists. Remove it manually if you want to reinstall."
fi

mkdir -p "$CODEX_PROFILE_1" "$CODEX_PROFILE_2" "$INSTALL_BIN_DIR"

info "Copy auth.json separately"
cp -a "$CODEX_ORIGINAL_HOME/auth.json" "$CODEX_PROFILE_1/auth.json"
cp -a "$CODEX_ORIGINAL_HOME/auth.json" "$CODEX_PROFILE_2/auth.json"
chmod 600 "$CODEX_PROFILE_1/auth.json" "$CODEX_PROFILE_2/auth.json"

info "Link all other Codex state from original home"
for item in "$CODEX_ORIGINAL_HOME"/* "$CODEX_ORIGINAL_HOME"/.[!.]*; do
  [ -e "$item" ] || continue
  name="$(basename "$item")"

  if [ "$name" = "auth.json" ]; then
    continue
  fi

  ln -s "$item" "$CODEX_PROFILE_1/$name"
  ln -s "$item" "$CODEX_PROFILE_2/$name"
done

chmod 700 "$CODEX_PROFILE_1" "$CODEX_PROFILE_2"

info "Write config file"
cat > "$CONFIG_FILE" <<EOF
# codex2keys configuration
CODEX_BIN="$CODEX_BIN"
CODEX_PROFILE_1="$CODEX_PROFILE_1"
CODEX_PROFILE_2="$CODEX_PROFILE_2"
CODEX_ACTIVE_FILE="$CODEX_ACTIVE_FILE"
CODEX_LOCK_FILE="$CODEX_LOCK_FILE"
EOF
chmod 600 "$CONFIG_FILE"

info "Install wrapper scripts"
install -m 755 "$SCRIPT_DIR/scripts/codex_smart" "$INSTALL_BIN_DIR/codex_smart"
install -m 755 "$SCRIPT_DIR/scripts/codex_switch" "$INSTALL_BIN_DIR/codex_switch"

info "Set default active account"
echo "1" > "$CODEX_ACTIVE_FILE"
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
CODEX_HOME="$CODEX_PROFILE_1" "$CODEX_BIN" login status || true
CODEX_HOME="$CODEX_PROFILE_2" "$CODEX_BIN" login status || true

cat <<EOF

Done.

Next step: log profile 2 into the second account:

  CODEX_HOME="$CODEX_PROFILE_2" "$CODEX_BIN" logout || true
  CODEX_HOME="$CODEX_PROFILE_2" "$CODEX_BIN" login --device-auth

Then verify the two auth files are different:

  sha256sum "$CODEX_PROFILE_1/auth.json" "$CODEX_PROFILE_2/auth.json"

Usage:

  codex_smart          # resume last session with active account
  codex_smart new      # open new session
  codex_smart status   # show account status
  codex_switch         # toggle active account
  codex_switch 1       # set account 1
  codex_switch 2       # set account 2
EOF
