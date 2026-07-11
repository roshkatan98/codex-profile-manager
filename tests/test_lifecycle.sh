#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$TMP/runtime"
export INSTALL_BIN_DIR="$HOME/.local/bin"
export INSTALL_DATA_DIR="$XDG_DATA_HOME/codex-profile-manager"
export PATH="$INSTALL_BIN_DIR:/usr/bin:/bin"
mkdir -p "$HOME/.local/bin" "$HOME/.codex/sessions" "$XDG_RUNTIME_DIR"

FAKE_CODEX="$HOME/.local/bin/codex"
cat > "$FAKE_CODEX" <<'EOF_FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  login)
    case "${2:-}" in
      status)
        [ -f "$CODEX_HOME/auth.json" ] && exit 0
        exit 1
        ;;
      --device-auth)
        printf '{"profile":"%s"}\n' "$(basename "$CODEX_HOME")" > "$CODEX_HOME/auth.json"
        chmod 600 "$CODEX_HOME/auth.json"
        exit 0
        ;;
    esac
    ;;
  logout)
    rm -f "$CODEX_HOME/auth.json"
    exit 0
    ;;
esac
exit 0
EOF_FAKE
chmod +x "$FAKE_CODEX"

printf '{"primary":true}\n' > "$HOME/.codex/auth.json"
printf 'model = "test"\n' > "$HOME/.codex/config.toml"
printf 'session\n' > "$HOME/.codex/sessions/session.txt"

export CODEX_BIN="$FAKE_CODEX"
export CODEX_ORIGINAL_HOME="$HOME/.codex"
export CODEX_ACTIVE_FILE="$XDG_STATE_HOME/codex-profile-manager/active"
export CODEX_LOCK_FILE="$XDG_RUNTIME_DIR/codex-profile-manager-${UID}.lock"
export CODEX_BACKUP_DIR="$XDG_DATA_HOME/codex-profile-manager/backups"
unset CODEX_ACCOUNTS CODEX_PROFILE_1 CODEX_PROFILE_2 CODEX_PROFILE_MANAGER_CONFIG

printf '3\ny\npersonal\nwork\nbackup\n' | bash "$ROOT_DIR/install.sh" --wizard --yes --skip-backup >/dev/null

CONFIG="$XDG_CONFIG_HOME/codex-profile-manager/config.env"
[ -f "$CONFIG" ]
grep -q "personal:$HOME/.codex-personal" "$CONFIG"
grep -q "work:$HOME/.codex-work" "$CONFIG"
grep -q "backup:$HOME/.codex-backup" "$CONFIG"
[ -f "$HOME/.codex-personal/auth.json" ]
[ ! -e "$HOME/.codex-work/auth.json" ]
[ ! -e "$HOME/.codex-backup/auth.json" ]

codexpm login work
codexpm login backup
codexpm use work >/dev/null
codexpm remove work >/dev/null
[ "$(cat "$CODEX_ACTIVE_FILE")" = "backup" ]
[ -d "$HOME/.codex-work" ]
if grep -q "work:$HOME/.codex-work" "$CONFIG"; then
  echo "Removed profile remained in rotation" >&2
  exit 1
fi

codexpm remove backup --delete-files --yes >/dev/null
[ ! -e "$HOME/.codex-backup" ]
[ "$(cat "$CODEX_ACTIVE_FILE")" = "personal" ]

set +e
codexpm remove personal >"$TMP/remove-last.log" 2>&1
remove_status=$?
set -e
[ "$remove_status" -ne 0 ]
grep -q 'last configured profile cannot be removed' "$TMP/remove-last.log"

codexpm add spare >/dev/null
[ -d "$HOME/.codex-spare" ]
[ -f "$HOME/.codex-spare/.codex-profile-manager-profile" ]

codexpm uninstall --purge --yes >/dev/null
[ -x "$FAKE_CODEX" ]
[ -d "$HOME/.codex" ]
[ ! -e "$HOME/.codex-personal" ]
[ ! -e "$HOME/.codex-spare" ]
[ ! -e "$CONFIG" ]
[ ! -e "$INSTALL_BIN_DIR/codexpm" ]

printf 'All lifecycle tests passed.\n'
