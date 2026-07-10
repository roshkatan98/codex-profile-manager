# Restore

The installer stores backups under `CODEX_BACKUP_DIR`, by default:

```text
~/.local/share/codex-profile-manager/backups
```

To restore an original Codex home backup:

```bash
mv "$HOME/.codex" "$HOME/.codex.before-restore.$(date +%Y%m%d_%H%M%S)"
cp -a "/path/to/codex-home.TIMESTAMP" "$HOME/.codex"
```

The manager never modifies the original Codex binary.

To remove only the manager commands:

```bash
bash uninstall.sh
```

To remove manager profiles and configuration too:

```bash
bash uninstall.sh --purge
```
