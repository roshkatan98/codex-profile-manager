# Changelog

## 1.1.1

- Added `codexpm update --check` to check for a newer stable release.
- Added `codexpm update` to download and install the latest stable release.
- Preserved profile configuration and authentication during updates.
- Added archive validation and automatic post-update diagnostics.
- Added an offline integration test for the complete update flow.

## 1.1.0

- Added an interactive setup wizard for choosing the number of profiles.
- Added optional custom profile names with numeric defaults.
- Added `codexpm remove` with safe file-preserving behavior by default.
- Added `codexpm remove --delete-files` for verified profile deletion.
- Added `codexpm uninstall` and `codexpm uninstall --purge`.
- Added managed-profile markers to prevent unsafe directory deletion.
- Added lifecycle tests for setup, removal, active-profile reassignment, and uninstall.

## 1.0.0

- Added the `codexpm` command for N-profile management.
- Added safe profile creation without copying authentication tokens.
- Replaced share-everything behavior with a configurable allowlist.
- Added per-user locking, backup validation, migration, diagnostics, and uninstall support.
- Preserved compatibility wrappers for `codex_smart`, `codex_switch`, and `codex_add_account`.
- Added ShellCheck and integration-test CI.
- Added strict validation for paths, duplicate profile ids, and duplicate profile directories.
- Added lock-contention handling with a dedicated temporary-failure exit code.
- Expanded `doctor` to validate link targets, permissions, and authentication isolation.
