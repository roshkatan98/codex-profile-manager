## Summary

Describe the change and the user problem it solves.

## Safety checklist

- [ ] The original Codex binary is not renamed, replaced, or modified.
- [ ] Authentication remains isolated between profiles.
- [ ] No `auth.json`, tokens, device codes, or private session data are included.
- [ ] Unknown Codex files are not shared automatically.
- [ ] Destructive operations fail safely.

## Validation

- [ ] `bash -n install.sh uninstall.sh bin/* lib/*.sh tests/*.sh`
- [ ] `shellcheck -x -e SC1090,SC1091,SC2034,SC2154 install.sh uninstall.sh bin/* lib/*.sh tests/*.sh`
- [ ] `bash tests/test_codexpm.sh`
- [ ] Relevant documentation was updated.
