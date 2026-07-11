# Restore and uninstall

## Remove the manager but keep profiles

```bash
codexpm uninstall
```

This removes the installed manager commands and managed shell integration. Profile directories, authentication files, configuration, and backups are preserved.

## Return to the original Codex setup

```bash
codexpm uninstall --purge
```

This removes verified manager profile directories and configuration, then restores the shell to the original Codex command.

The following are never removed:

- the original Codex binary;
- the original `~/.codex` directory;
- backups created by the installer.

## Run uninstall from a repository checkout

When the installed `codexpm` command is unavailable:

```bash
bash uninstall.sh
bash uninstall.sh --purge
```

## Restore an original Codex-home backup

Backups are stored under `CODEX_BACKUP_DIR`, by default:

```text
~/.local/share/codex-profile-manager/backups
```

To restore one manually:

```bash
mv "$HOME/.codex" "$HOME/.codex.before-restore.$(date +%Y%m%d_%H%M%S)"
cp -a "/path/to/codex-home.TIMESTAMP" "$HOME/.codex"
```
