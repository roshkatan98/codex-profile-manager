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
mkdir -p "$HOME/.local/bin" "$HOME/.codex/sessions" "$XDG_RUNTIME_DIR"

FAKE_CODEX="$HOME/.local/bin/codex"
cat > "$FAKE_CODEX" <<'EOF_FAKE'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  login)
    case "${2:-}" in
      status)
        if [ -f "$CODEX_HOME/auth.json" ]; then
          echo "Logged in using test profile"
          exit 0
        fi
        echo "Not logged in"
        exit 1
        ;;
      --device-auth)
        printf '{"test":"%s"}\n' "$(basename "$CODEX_HOME")" > "$CODEX_HOME/auth.json"
        chmod 600 "$CODEX_HOME/auth.json"
        echo "Login complete"
        exit 0
        ;;
    esac
    ;;
  logout)
    rm -f "$CODEX_HOME/auth.json"
    exit 0
    ;;
  --version)
    echo "codex-cli test"
    exit 0
    ;;
esac

printf '%s\n' "$*" > "$CODEX_HOME/last-command.txt"
exit 0
EOF_FAKE
chmod +x "$FAKE_CODEX"

printf '{"test":"primary"}\n' > "$HOME/.codex/auth.json"
printf 'model = "test"\n' > "$HOME/.codex/config.toml"
printf 'history\n' > "$HOME/.codex/history.jsonl"
printf 'future secret\n' > "$HOME/.codex/future-account-cache"
printf 'session\n' > "$HOME/.codex/sessions/session.txt"

export CODEX_BIN="$FAKE_CODEX"
export CODEX_ORIGINAL_HOME="$HOME/.codex"
export CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2"
export CODEX_ACTIVE_FILE="$XDG_STATE_HOME/codex-profile-manager/active"
export CODEX_LOCK_FILE="$XDG_RUNTIME_DIR/codex-profile-manager-${UID}.lock"
export CODEX_BACKUP_DIR="$XDG_DATA_HOME/codex-profile-manager/backups"
export INSTALL_BIN_DIR="$HOME/.local/bin"
export INSTALL_DATA_DIR="$XDG_DATA_HOME/codex-profile-manager"
export PATH="$INSTALL_BIN_DIR:$PATH"

bash "$ROOT_DIR/install.sh" --yes --skip-backup

[ -f "$HOME/.codex-1/auth.json" ]
[ ! -e "$HOME/.codex-2/auth.json" ]
[ -f "$HOME/.codex-1/.codex-profile-manager-profile" ]
[ -f "$HOME/.codex-2/.codex-profile-manager-profile" ]
[ -L "$HOME/.codex-1/sessions" ]
[ -L "$HOME/.codex-2/config.toml" ]
[ ! -e "$HOME/.codex-1/future-account-cache" ]
[ ! -e "$HOME/.codex-2/future-account-cache" ]

codexpm use 2 | grep -q 'profile is now: 2'
[ "$(cat "$CODEX_ACTIVE_FILE")" = "2" ]
codexpm next | grep -q '2 -> 1'
[ "$(cat "$CODEX_ACTIVE_FILE")" = "1" ]

codexpm add 3
[ -d "$HOME/.codex-3" ]
[ ! -e "$HOME/.codex-3/auth.json" ]
[ -f "$HOME/.codex-3/.codex-profile-manager-profile" ]
codexpm login 3
[ -f "$HOME/.codex-3/auth.json" ]

grep -q "3:$HOME/.codex-3" "$XDG_CONFIG_HOME/codex-profile-manager/config.env"

ln -s "$HOME/.codex/future-account-cache" "$HOME/.codex-1/future-account-cache"
codexpm migrate
[ ! -e "$HOME/.codex-1/future-account-cache" ]

codexpm doctor
codexpm run new
[ -f "$HOME/.codex-1/last-command.txt" ]

codex_smart status >/dev/null
codex_switch 3 >/dev/null
[ "$(cat "$CODEX_ACTIVE_FILE")" = "3" ]

codexpm remove 2 >/dev/null
[ -d "$HOME/.codex-2" ]
if grep -q "2:$HOME/.codex-2" "$XDG_CONFIG_HOME/codex-profile-manager/config.env"; then
  echo "Removed profile remained in configuration" >&2
  exit 1
fi

printf 'All integration tests passed.\n'
