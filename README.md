# codex2keys

A practical setup for using **two separate Codex CLI authentication profiles** on the same machine while keeping the same Codex context, sessions, history, configuration, and project workflow.

This repository is intentionally generic. It does not depend on one specific VPS, user, repository, or project. Fill in the variables in the configuration section and run the installer.

> This project is for managing two legitimate Codex authentication profiles on one machine. It is not a recommendation to bypass service limits or terms. The safest workflow is manual switching, or switching after explicit user confirmation.

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

If you create two completely separate Codex homes, each account gets its own sessions and context. That is usually not what you want.

The better setup is:

```text
~/.codex                 # original Codex home, remains untouched
~/.codex-1/auth.json     # auth for account 1
~/.codex-2/auth.json     # auth for account 2
~/.codex-1/*             # symlinks to ~/.codex, except auth.json
~/.codex-2/*             # symlinks to ~/.codex, except auth.json
```

So the two accounts have separate authentication but shared context.

## Important safety rule

Do **not** run two Codex sessions at the same time against the same shared state. This repo uses a `flock` lock to prevent that.

## Required variables

Before installing, decide these values:

| Variable | Example | Meaning |
|---|---|---|
| `CODEX_BIN` | `$HOME/.local/bin/codex` | Path to the original Codex binary |
| `CODEX_ORIGINAL_HOME` | `$HOME/.codex` | Current Codex home containing your existing state |
| `CODEX_PROFILE_1` | `$HOME/.codex-1` | Profile directory for account 1 |
| `CODEX_PROFILE_2` | `$HOME/.codex-2` | Profile directory for account 2 |
| `CODEX_ACTIVE_FILE` | `$HOME/.codex-active` | Stores which account is currently active |
| `CODEX_LOCK_FILE` | `/tmp/codex-shared-state.lock` | Lock file preventing parallel sessions |
| `INSTALL_BIN_DIR` | `$HOME/.local/bin` | Where wrapper scripts are installed |

## Quick install

Clone the repo:

```bash
git clone https://github.com/YOUR_USER/codex2keys.git
cd codex2keys
```

Run the installer with your real paths:

```bash
CODEX_BIN="$HOME/.local/bin/codex" \
CODEX_ORIGINAL_HOME="$HOME/.codex" \
CODEX_PROFILE_1="$HOME/.codex-1" \
CODEX_PROFILE_2="$HOME/.codex-2" \
INSTALL_BIN_DIR="$HOME/.local/bin" \
./install.sh
```

The installer does **not** modify the original Codex binary.

## Connect account 2

After install, profile 1 and profile 2 initially contain a copy of the same `auth.json`. You must log profile 2 into the second account:

```bash
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" login --device-auth
```

Use your second ChatGPT/Codex account in the browser flow.

Then verify both accounts:

```bash
CODEX_HOME="$HOME/.codex-1" "$HOME/.local/bin/codex" login status
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" login status
sha256sum "$HOME/.codex-1/auth.json" "$HOME/.codex-2/auth.json"
```

The two hashes should be different.

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

Switch account only:

```bash
codex_switch
```

Set a specific account:

```bash
codex_switch 1
codex_switch 2
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

When Codex exits, `codex_smart` asks whether to switch to the other account and resume:

```text
Switch to account 2 and resume? [y/N]
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
templates/bashrc-snippet.sh
docs/restore.md
docs/troubleshooting.md
```
