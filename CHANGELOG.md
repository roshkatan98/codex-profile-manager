# Changelog

## 1.0.0

- Renamed the project concept to `codex-profile-manager`.
- Added the `codexpm` command for N-profile management.
- Added safe account creation without copying authentication tokens.
- Replaced share-everything behavior with a configurable allowlist.
- Added per-user locking, backup free-space checks, migration, diagnostics, and uninstall support.
- Preserved compatibility wrappers for `codex_smart`, `codex_switch`, and `codex_add_account`.
- Added ShellCheck and integration-test CI.
- Added strict validation for absolute paths, duplicate profile ids, and duplicate profile directories.
- Made custom configuration paths persist across install, migration, and profile additions.
- Prevented backup directories inside the original Codex home.
- Added lock-contention handling with a dedicated temporary-failure exit code.
- Expanded `doctor` to validate link targets, permissions, auth isolation, and duplicate auth files.
- Added edge-case regression tests and a CI guard against tracked credentials or Codex runtime state.
