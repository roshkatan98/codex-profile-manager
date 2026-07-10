# Architecture

## Isolation model

Each configured account has its own profile directory and its own `auth.json`. Shared Codex state remains in the original Codex home.

```text
Original Codex home
  ~/.codex/
    config.toml
    sessions/
    history.jsonl
    state_*.sqlite
    auth.json                original account only

Profile 1
  ~/.codex-1/
    auth.json                copied once during initial install
    config.toml -> ~/.codex/config.toml
    sessions -> ~/.codex/sessions

Profile 2
  ~/.codex-2/
    auth.json                created by independent login
    config.toml -> ~/.codex/config.toml
    sessions -> ~/.codex/sessions
```

## Why an allowlist

A denylist such as "share everything except auth.json" assumes future Codex versions will not add new account-specific files. An allowlist makes the safer assumption: unknown files stay private until reviewed.

## Concurrency

All profiles point at shared mutable state. Running more than one Codex process against that state may corrupt or race on files. `codexpm run` uses a per-user `flock` lock.

## Original binary

The project installs separate commands and optional shell functions. It never replaces, renames, or patches the original Codex executable.
