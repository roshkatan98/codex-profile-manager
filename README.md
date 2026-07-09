# codex2keys

A practical setup for using **multiple Codex CLI authentication profiles** on the same machine while keeping the same Codex context, sessions, history, configuration, and project workflow.

This repository is intentionally generic. It does not depend on one specific VPS, user, repository, or project. Fill in the variables in the configuration section and run the installer.

> This project is for managing legitimate Codex authentication profiles on one machine. It is not a recommendation to bypass service limits or terms. The safest workflow is manual switching, or switching after explicit user confirmation.

## What this solves

Codex CLI keeps local state under a Codex home directory, usually:

```bash
~/.codex
```

That directory normally contains things like:

```text
auth.json
config.toml
sessions/
session_index.jsonl
history.jsonl
attachments/
memories/
cache/
```

If you create completely separate Codex homes, each account gets its own sessions and context. That is usually not what you want.

The better setup is:

```text
~/.codex                    # original Codex home, remains untouched
~/.codex-1/auth.json        # auth for account 1
~/.codex-2/auth.json        # auth for account 2
~/.codex-3/auth.json        # auth for account 3, optional
~/.codex-N/auth.json        # auth for account N, optional
~/.codex-*/config.toml      # symlink to ~/.codex/config.toml
~/.codex-*/sessions         # symlink to ~/.codex/sessions
~/.codex-*/history.jsonl    # symlink to ~/.codex/history.jsonl
```

So every account has separate authentication but shared context.

## Important safety rule

Do **not** run two Codex sessions at the same time against the same shared state. This repo uses a `flock` lock to prevent that.

## Required variables

Before installing, decide these values:

| Variable | Example | Meaning |
|---|---|---|
| `CODEX_BIN` | `$HOME/.local/bin/codex` | Path to the original Codex binary |
| `CODEX_ORIGINAL_HOME` | `$HOME/.codex` | Current Codex home containing your existing state |
| `CODEX_ACCOUNTS` | `1:$HOME/.codex-1 2:$HOME/.codex-2 3:$HOME/.codex-3` | Account id to profile directory map |
| `CODEX_ACTIVE_FILE` | `$HOME/.codex-active` | Stores which account is currently active |
| `CODEX_LOCK_FILE` | `/tmp/codex-shared-state.lock` | Lock file preventing parallel sessions |
| `INSTALL_BIN_DIR` | `$HOME/.local/bin` | Where wrapper scripts are installed |

`CODEX_ACCOUNTS` is the key setting. It supports any number of accounts:

```bash
CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2 3:$HOME/.codex-3"
```

You may also use names instead of numbers:

```bash
CODEX_ACCOUNTS="main:$HOME/.codex-main work:$HOME/.codex-work backup:$HOME/.codex-backup"
```

Use paths without spaces.

## Quick install for three accounts

Clone the repo:

```bash
git clone https://github.com/YOUR_USER/codex2keys.git
cd codex2keys
```

Run the installer with your real paths:

```bash
CODEX_BIN="$HOME/.local/bin/codex" \
CODEX_ORIGINAL_HOME="$HOME/.codex" \
CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2 3:$HOME/.codex-3" \
INSTALL_BIN_DIR="$HOME/.local/bin" \
./install.sh
```

The installer does **not** modify the original Codex binary.

## Connect additional accounts

After install, every generated profile initially contains a copy of the same `auth.json`. Keep account 1 as-is if it is already your primary account, then log each additional profile into its own account.

For account 2:

```bash
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" login --device-auth
```

For account 3:

```bash
CODEX_HOME="$HOME/.codex-3" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-3" "$HOME/.local/bin/codex" login --device-auth
```

Then verify:

```bash
codex_smart status
sha256sum "$HOME/.codex-1/auth.json" "$HOME/.codex-2/auth.json" "$HOME/.codex-3/auth.json"
```

The auth hashes should be different.

## Add another account later

Use:

```bash
codex_add_account 4
```

or with a custom directory:

```bash
codex_add_account work "$HOME/.codex-work"
```

Then log in the new profile:

```bash
CODEX_HOME="$HOME/.codex-4" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-4" "$HOME/.local/bin/codex" login --device-auth
```

See `docs/add-account.md` for the manual process.

## Shell integration

If you want typing `codex` in your shell to run the smart wrapper while leaving the original Codex binary untouched, add this to your shell rc file:

```bash
# Codex smart wrapper - shell only, original binary untouched
codex() {
  command codex_smart "$@"
}

codexr() {
  command codex_smart "$@"
}
```

A ready-to-copy version is available in:

```text
templates/bashrc-snippet.sh
```

Apply it manually, then reload your shell:

```bash
source ~/.bashrc
```

## Daily usage

Continue the last Codex session in the current project:

```bash
cd /path/to/project
codex
```

Open a new Codex session:

```bash
cd /path/to/project
codex new
```

Rotate to the next account:

```bash
codex_switch
```

Set a specific account:

```bash
codex_switch 1
codex_switch 2
codex_switch 3
```

Check current state:

```bash
codex status
codex_switch status
```

Resume across all sessions if you are not in the original project directory:

```bash
codex all
```

## Behavior after `/quit`

When Codex exits, `codex_smart` asks whether to switch to the next account in the configured rotation and resume:

```text
Switch to account 2 and resume? [y/N]
```

With three accounts, the rotation is:

```text
1 -> 2 -> 3 -> 1
```

Answer `y` only if you intentionally want to switch.

## Why not modify the original Codex binary?

Because it is cleaner and safer to leave the vendor-installed CLI untouched. This project uses wrapper scripts and optional shell functions only.

If something goes wrong, remove the shell function and keep using the original Codex binary directly.

## Files in this repo

```text
README.md
install.sh
scripts/codex_smart
scripts/codex_switch
scripts/codex_add_account
templates/bashrc-snippet.sh
docs/add-account.md
docs/restore.md
docs/troubleshooting.md
```
