# Add or remove a profile

## Add a profile

Add a numeric profile:

```bash
codexpm add 3
codexpm login 3
```

Add a named profile:

```bash
codexpm add work
codexpm login work
```

Use a custom directory when needed:

```bash
codexpm add work "$HOME/.codex-work"
```

The new profile starts without `auth.json` and must be logged in independently.

## Remove a profile from rotation

Preserve its local files:

```bash
codexpm remove work
```

The profile no longer appears in `codexpm list` or in the rotation, but its directory remains available for manual recovery.

## Remove a profile and delete its files

```bash
codexpm remove work --delete-files
```

The command shows the exact directory and requires confirmation. It deletes only a verified manager profile directory. Shared sessions, history, and the original Codex home are not removed.

The last configured profile cannot be removed. Use `codexpm uninstall --purge` when you want to remove the manager entirely.

## Verify

```bash
codexpm list
codexpm status
codexpm doctor
```
