# Contributing

Contributions are welcome.

## Before opening a pull request

1. Run syntax checks:

   ```bash
   bash -n install.sh uninstall.sh bin/* lib/*.sh tests/*.sh
   ```

2. Run ShellCheck:

   ```bash
   shellcheck -x -e SC1090,SC1091,SC2034,SC2154 install.sh uninstall.sh bin/* lib/*.sh tests/*.sh
   ```

3. Run the integration tests:

   ```bash
   bash tests/test_codexpm.sh
   ```

4. Confirm no credentials or real profile data are present:

   ```bash
   git grep -nE 'auth\.json|access[_-]?token|refresh[_-]?token'
   ```

Expected documentation references to `auth.json` are acceptable. Real token values are not.

## Design principles

- Never modify the original Codex binary.
- Never copy authentication into additional profiles.
- Prefer conservative allowlists over sharing unknown files.
- Preserve backward compatibility for the legacy wrappers when practical.
- Fail safely before destructive changes.
