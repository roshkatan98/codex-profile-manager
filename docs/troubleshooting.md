# Troubleshooting

## `codex status` opens an interactive session

Your shell is probably calling the original binary instead of the optional shell function.

```bash
type codex
```

Expected when shell integration is enabled:

```text
codex is a function
```

Reload Bash:

```bash
set +u
source ~/.bashrc
```

Or use the explicit command:

```bash
codexpm status
```

## Old prompts appear immediately

`codex` resumes the latest session by default. Start a fresh session:

```bash
codex new
```

## Account is not logged in

```bash
codexpm login <account-id>
```

## Invalid account

```bash
codexpm list
codexpm config-path
```

Check the `CODEX_ACCOUNTS` entry in the displayed config file.

## Lock error

Another managed Codex process is probably running:

```bash
pgrep -af codex
```

Close the other process. Do not delete the lock merely to run two shared-state sessions concurrently.

## Not enough backup space

Set `CODEX_BACKUP_DIR` to a larger filesystem:

```bash
CODEX_BACKUP_DIR=/mnt/volume/codex-backups bash install.sh --upgrade
```

## Diagnose links

```bash
codexpm doctor
```
