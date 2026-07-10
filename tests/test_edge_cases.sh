#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make_fake_codex() {
  local target="$1"
  cat > "$target" <<'EOF_FAKE'
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
  chmod +x "$target"
}

setup_env() {
  local root="$1"
  export HOME="$root/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_STATE_HOME="$HOME/.local/state"
  export XDG_RUNTIME_DIR="$root/runtime"
  mkdir -p "$HOME/.local/bin" "$HOME/.codex/sessions" "$XDG_RUNTIME_DIR"
  make_fake_codex "$HOME/.local/bin/codex"
  printf '{"primary":true}\n' > "$HOME/.codex/auth.json"
  printf 'model = "test"\n' > "$HOME/.codex/config.toml"
  printf 'history\n' > "$HOME/.codex/history.jsonl"

  export CODEX_BIN="$HOME/.local/bin/codex"
  export CODEX_ORIGINAL_HOME="$HOME/.codex"
  export CODEX_ACTIVE_FILE="$XDG_STATE_HOME/codex-profile-manager/active"
  export CODEX_LOCK_FILE="$XDG_RUNTIME_DIR/codex-profile-manager-${UID}.lock"
  export CODEX_BACKUP_DIR="$XDG_DATA_HOME/codex-profile-manager/backups"
  export INSTALL_BIN_DIR="$HOME/.local/bin"
  export INSTALL_DATA_DIR="$XDG_DATA_HOME/codex-profile-manager"
  export PATH="$INSTALL_BIN_DIR:/usr/bin:/bin"
  unset CODEX_PROFILE_MANAGER_CONFIG CODEX_PROFILE_1 CODEX_PROFILE_2
}

# Custom config path must be honored by install and add.
T1="$(mktemp -d)"
setup_env "$T1"
export CODEX_ACCOUNTS="a:$HOME/.codex-a b:$HOME/.codex-b"
export CODEX_PROFILE_MANAGER_CONFIG="$HOME/custom/config.env"
bash "$ROOT_DIR/install.sh" --yes --skip-backup >/dev/null
codexpm add c >/dev/null
[ -f "$HOME/custom/config.env" ]
[ ! -f "$XDG_CONFIG_HOME/codex-profile-manager/config.env" ]
grep -q "c:$HOME/.codex-c" "$HOME/custom/config.env"
rm -rf "$T1"

# Duplicate profile paths must be rejected.
T2="$(mktemp -d)"
setup_env "$T2"
export CODEX_ACCOUNTS="1:$HOME/.codex-a 2:$HOME/.codex-a"
if bash -c 'source "$1/lib/config.sh"; codexpm_load_config; codexpm_validate_config' _ "$ROOT_DIR" >/dev/null 2>&1; then
  echo "Duplicate profile paths were accepted" >&2
  exit 1
fi
rm -rf "$T2"

# Backup directory must not be inside the original Codex home.
T3="$(mktemp -d)"
setup_env "$T3"
export CODEX_BACKUP_DIR="$HOME/.codex/backups"
if bash -c 'source "$1/lib/backup.sh"; codexpm_backup_home 0' _ "$ROOT_DIR" >/dev/null 2>&1; then
  echo "Nested backup directory was accepted" >&2
  exit 1
fi
rm -rf "$T3"

# Existing profiles require explicit upgrade mode.
T4="$(mktemp -d)"
setup_env "$T4"
export CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2"
mkdir -p "$HOME/.codex-1"
if bash "$ROOT_DIR/install.sh" --yes --skip-backup >/dev/null 2>&1; then
  echo "Existing profile was silently reused without --upgrade" >&2
  exit 1
fi
rm -rf "$T4"

# Original auth symlinks must be copied as independent regular files.
T5="$(mktemp -d)"
setup_env "$T5"
rm -f "$HOME/.codex/auth.json"
printf '{"primary":true}\n' > "$HOME/real-auth.json"
ln -s "$HOME/real-auth.json" "$HOME/.codex/auth.json"
export CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2"
bash "$ROOT_DIR/install.sh" --yes --skip-backup >/dev/null
[ -f "$HOME/.codex-1/auth.json" ]
[ ! -L "$HOME/.codex-1/auth.json" ]
rm -rf "$T5"

# Doctor must detect incorrect shared-link targets.
T6="$(mktemp -d)"
setup_env "$T6"
export CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2"
bash "$ROOT_DIR/install.sh" --yes --skip-backup >/dev/null
rm -f "$HOME/.codex-2/config.toml"
printf 'wrong\n' > "$HOME/wrong-config"
ln -s "$HOME/wrong-config" "$HOME/.codex-2/config.toml"
if codexpm doctor >/dev/null 2>&1; then
  echo "Doctor accepted an incorrect shared-link target" >&2
  exit 1
fi
rm -rf "$T6"

# Lock contention must return the dedicated temporary-failure code.
T7="$(mktemp -d)"
setup_env "$T7"
export CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2"
bash "$ROOT_DIR/install.sh" --yes --skip-backup >/dev/null
exec 8>"$CODEX_LOCK_FILE"
flock -n 8
set +e
codexpm run new >/dev/null 2>&1
lock_status=$?
set -e
flock -u 8
exec 8>&-
[ "$lock_status" -eq 75 ]
rm -rf "$T7"

# Compatibility wrappers must resolve sibling codexpm without relying on PATH.
T8="$(mktemp -d)"
mkdir -p "$T8/bin" "$T8/home"
cp "$ROOT_DIR/bin/codexpm" "$ROOT_DIR/bin/codex_switch" "$ROOT_DIR/bin/codex_smart" "$ROOT_DIR/bin/codex_add_account" "$T8/bin/"
chmod +x "$T8/bin"/*
set +e
PATH=/usr/bin:/bin HOME="$T8/home" "$T8/bin/codex_switch" status >"$T8/output" 2>&1
set -e
if grep -q 'codexpm: command not found' "$T8/output"; then
  echo "Compatibility wrapper depends on PATH" >&2
  exit 1
fi
rm -rf "$T8"

# Uninstall must remove the managed Bash block.
T9="$(mktemp -d)"
export HOME="$T9/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$HOME/.local/bin" "$XDG_DATA_HOME/codex-profile-manager/bin" "$XDG_DATA_HOME/codex-profile-manager/lib"
printf 'before\n# >>> codex-profile-manager >>>\ncodex(){ :; }\n# <<< codex-profile-manager <<<\nafter\n' > "$HOME/.bashrc"
bash "$ROOT_DIR/uninstall.sh" --yes >/dev/null
! grep -q 'codex-profile-manager' "$HOME/.bashrc"
rm -rf "$T9"

printf 'All edge-case tests passed.\n'
