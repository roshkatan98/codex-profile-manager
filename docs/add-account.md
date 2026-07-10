# Add an account

Add a numeric profile:

```bash
codexpm add 3
codexpm login 3
```

Add a named profile with a custom directory:

```bash
codexpm add work "$HOME/.codex-work"
codexpm login work
```

The add command creates the directory and shared-state links, updates the configuration, and deliberately does not create `auth.json`.

Verify:

```bash
codexpm list
codexpm status
codexpm doctor
```
