# Add another Codex account

This guide explains how to add account 3, 4, or any additional account after codex2keys is already installed.

## Preferred method

Use the helper script:

```bash
codex_add_account 3
```

This creates:

```text
~/.codex-3/auth.json
```

and symlinks every other item back to your original Codex home, usually:

```text
~/.codex
```

Then log into the new account:

```bash
CODEX_HOME="$HOME/.codex-3" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$HOME/.codex-3" "$HOME/.local/bin/codex" login --device-auth
```

Use the intended third account in the browser/device login flow.

Verify:

```bash
codex_smart status
sha256sum "$HOME/.codex-1/auth.json" "$HOME/.codex-2/auth.json" "$HOME/.codex-3/auth.json"
```

The hashes should be different.

## Custom account labels

Account ids do not have to be numbers:

```bash
codex_add_account work "$HOME/.codex-work"
codex_switch work
```

The configured rotation follows the order in `CODEX_ACCOUNTS`.

## Manual method

Use this only if you do not want to use `codex_add_account`.

Set your variables:

```bash
ORIG="$HOME/.codex"
NEW_ID="3"
NEW_DIR="$HOME/.codex-3"
CONFIG_FILE="$HOME/.codex2keys.env"
```

Create the profile:

```bash
mkdir -p "$NEW_DIR"
cp -a "$ORIG/auth.json" "$NEW_DIR/auth.json"
chmod 600 "$NEW_DIR/auth.json"
```

Symlink all shared state except `auth.json`:

```bash
for item in "$ORIG"/* "$ORIG"/.[!.]*; do
  [ -e "$item" ] || continue
  name="$(basename "$item")"

  if [ "$name" = "auth.json" ]; then
    continue
  fi

  ln -s "$item" "$NEW_DIR/$name"
done

chmod 700 "$NEW_DIR"
```

Update the config file:

```bash
# Example final config line:
CODEX_ACCOUNTS="1:$HOME/.codex-1 2:$HOME/.codex-2 3:$HOME/.codex-3"
```

Then log into the new profile:

```bash
CODEX_HOME="$NEW_DIR" "$HOME/.local/bin/codex" logout || true
CODEX_HOME="$NEW_DIR" "$HOME/.local/bin/codex" login --device-auth
```

## Expected commands after adding account 3

```bash
codex_switch status
codex_switch       # rotates to the next account
codex_switch 1
codex_switch 2
codex_switch 3
codex_smart status
```

With three numeric accounts, rotation is:

```text
1 -> 2 -> 3 -> 1
```
