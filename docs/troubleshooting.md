# Troubleshooting

## `codex status` opens an interactive Codex session

This usually means your shell is not using the `codex()` function from `templates/bashrc-snippet.sh`.

Check:

```bash
type codex
```

Expected:

```text
codex is a function
```

If it shows a binary path instead, reload your shell:

```bash
source ~/.bashrc
```

Or call the wrapper directly:

```bash
codex_smart status
```

## I see old prompts when I open Codex

The default smart wrapper resumes the last session:

```bash
codex_smart
```

That is equivalent to:

```bash
codex resume --last
```

To open a fresh session:

```bash
codex_smart new
```

After you work in the new session, it becomes the latest session.

## I am in the wrong project context

Codex resume is usually affected by the current working directory.

Always enter the project first:

```bash
cd /path/to/project
codex_smart
```

If you want to search across all sessions:

```bash
codex_smart all
```

## `Another Codex session may already be running`

The wrapper uses a lock file to prevent two Codex sessions from writing to the same shared state at the same time.

Check for running sessions:

```bash
pgrep -af codex || true
```

Close the other session and try again.

## Account 1 and account 2 are the same account

Compare the auth files:

```bash
sha256sum "$HOME/.codex-1/auth.json" "$HOME/.codex-2/auth.json"
```

If the hashes are identical, profile 2 is still logged into the same account as profile 1.

Fix:

```bash
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" login --device-auth
```

Use the second account in the browser login flow.

## `token_invalidated` or `Please try signing in again`

Re-login the affected profile:

```bash
CODEX_HOME="$HOME/.codex-1" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-1" "$HOME/.local/bin/codex" login --device-auth
```

or:

```bash
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-2" "$HOME/.local/bin/codex" login --device-auth
```

## `source ~/.bashrc` fails with `unbound variable`

This can happen if you run `source ~/.bashrc` while the current shell has `set -u` enabled.

Use:

```bash
set +u
source ~/.bashrc
```

## I do not want to override the `codex` command

Do not install the shell function. Use explicit commands instead:

```bash
codex_smart
codex_smart new
codex_smart status
codex_switch
```

The original Codex binary remains untouched either way.

## I want to completely remove codex2keys

See:

```text
docs/restore.md
```
