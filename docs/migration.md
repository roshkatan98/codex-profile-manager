# Migration from codex2keys

The legacy setup may contain:

```text
~/.codex2keys.env
~/.codex-1
~/.codex-2
codex_smart
codex_switch
codex_add_account
```

## Upgrade

Close Codex sessions first, then run:

```bash
bash install.sh --upgrade
codexpm migrate
codexpm doctor
```

The migration:

- reads the legacy config if the new config does not yet exist;
- writes `~/.config/codex-profile-manager/config.env`;
- preserves every profile's `auth.json`;
- removes only obsolete symlinks that point into the original Codex home;
- creates the current allowlisted shared links;
- leaves `~/.codex2keys.env` in place for rollback.

## Existing third account

Include it in `CODEX_ACCOUNTS` before upgrading, or add it afterward:

```bash
codexpm add 3
codexpm login 3
```

Do not copy another profile's `auth.json` into the new profile.
