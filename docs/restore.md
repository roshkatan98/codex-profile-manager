# Restore and uninstall

This guide explains how to undo a codex2keys setup without touching your original Codex binary.

## What the installer changes

The installer creates:

```text
~/.codex-1
~/.codex-2
~/.codex-active
~/.codex2keys.env
~/.local/bin/codex_smart
~/.local/bin/codex_switch
```

It also creates a backup of the original Codex home:

```text
~/.codex.backup.codex2keys.TIMESTAMP
```

If `INSTALL_SHELL_FUNCTIONS=1` was used, it appends shell functions to `~/.bashrc`.

## Remove the dual-profile setup

First make sure Codex is not running:

```bash
pgrep -af codex || true
```

Then remove the generated profile directories and helper files:

```bash
rm -rf "$HOME/.codex-1" "$HOME/.codex-2"
rm -f "$HOME/.codex-active" "$HOME/.codex2keys.env"
rm -f "$HOME/.local/bin/codex_smart" "$HOME/.local/bin/codex_switch"
```

This does not remove your original:

```text
~/.codex
```

## Remove shell functions from `.bashrc`

Open your shell rc file:

```bash
nano ~/.bashrc
```

Remove the block that starts with:

```bash
# Codex smart wrapper - shell only, original binary untouched
```

Then reload:

```bash
source ~/.bashrc
```

## Restore original Codex home from backup

Only do this if the original `~/.codex` was damaged or you explicitly want to revert to the backup state.

```bash
mv "$HOME/.codex" "$HOME/.codex.before-restore.$(date +%Y%m%d_%H%M%S)"
cp -a "$HOME/.codex.backup.codex2keys.TIMESTAMP" "$HOME/.codex"
```

Replace `TIMESTAMP` with the actual backup suffix.

## Verify original Codex works

```bash
CODEX_HOME="$HOME/.codex" "$HOME/.local/bin/codex" login status
```

If you used the optional shell function named `codex`, either remove it from `.bashrc` or call the original binary by path:

```bash
"$HOME/.local/bin/codex" --version
```
