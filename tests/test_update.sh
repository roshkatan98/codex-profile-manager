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
export CODEX_ACCOUNTS="personal:$HOME/.codex-personal work:$HOME/.codex-work"
export CODEX_ACTIVE_FILE="$XDG_STATE_HOME/codex-profile-manager/active"
export CODEX_LOCK_FILE="$XDG_RUNTIME_DIR/codex-profile-manager-${UID}.lock"
export CODEX_BACKUP_DIR="$XDG_DATA_HOME/codex-profile-manager/backups"

bash "$ROOT_DIR/install.sh" --yes --skip-backup >/dev/null
codexpm login work
codexpm use work >/dev/null

CONFIG="$XDG_CONFIG_HOME/codex-profile-manager/config.env"
INSTALLED_CONFIG="$INSTALL_DATA_DIR/lib/config.sh"
sed -i 's/CODEXPM_VERSION="1.1.1"/CODEXPM_VERSION="1.1.0"/' "$INSTALLED_CONFIG"
[ "$(codexpm version)" = "codex-profile-manager 1.1.0" ]

ARCHIVE_ROOT="$TMP/archive/codex-profile-manager-1.1.1"
mkdir -p "$ARCHIVE_ROOT"
cp "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh" "$ARCHIVE_ROOT/"
cp -a "$ROOT_DIR/bin" "$ROOT_DIR/lib" "$ROOT_DIR/templates" "$ARCHIVE_ROOT/"
tar -czf "$TMP/v1.1.1.tar.gz" -C "$TMP/archive" "$(basename "$ARCHIVE_ROOT")"

export CODEXPM_UPDATE_LATEST_TAG="v1.1.1"
export CODEXPM_UPDATE_ARCHIVE="$TMP/v1.1.1.tar.gz"

codexpm update --check | grep -q 'An update is available'
codexpm update --yes >"$TMP/update.log"

grep -q 'Update complete: 1.1.0 -> 1.1.1' "$TMP/update.log"
[ "$(codexpm version)" = "codex-profile-manager 1.1.1" ]
[ "$(cat "$CODEX_ACTIVE_FILE")" = "work" ]
[ -f "$HOME/.codex-personal/auth.json" ]
[ -f "$HOME/.codex-work/auth.json" ]
grep -q "personal:$HOME/.codex-personal" "$CONFIG"
grep -q "work:$HOME/.codex-work" "$CONFIG"
codexpm doctor >/dev/null
codexpm update --check | grep -q 'already up to date'

printf 'All update tests passed.\n'
