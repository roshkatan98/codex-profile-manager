# Frequently asked questions

## Can I configure more than three accounts?

Yes. `CODEX_ACCOUNTS` accepts any number of numeric or named profile ids, and rotation follows their configured order.

```bash
CODEX_ACCOUNTS="personal:$HOME/.codex-personal work:$HOME/.codex-work backup:$HOME/.codex-backup"
```

## Does this bypass Codex limits?

No. The project only manages local authentication profiles and shared local state. Each account remains subject to its own plan, limits, policies, and terms.

## Does it modify the Codex binary?

No. The original executable specified by `CODEX_BIN` is never renamed, replaced, or patched. The project installs separate commands and optional shell functions.

## What is shared between profiles?

Only items in `CODEX_SHARED_ITEMS`. The default allowlist includes known session, history, configuration, memory, and state files. Authentication is never shared by the manager.

## Why are unknown Codex files not shared automatically?

A future Codex version may add account-specific or sensitive files. Keeping unknown items private is safer than sharing everything except a denylist.

## Can I start a new session instead of resuming the last one?

Yes.

```bash
codexpm run new
```

With the optional shell function:

```bash
codex new
```

## Can I switch directly to a specific profile?

Yes.

```bash
codexpm use work
```

Rotate to the next configured profile with:

```bash
codexpm next
```

## Can two managed Codex sessions run simultaneously?

Not safely against the same shared state. `codexpm run` uses a per-user lock and refuses a second concurrent managed session.

## Can I keep every profile completely separate?

That is not this project's primary purpose. Use separate `CODEX_HOME` directories without shared links when you want isolated sessions and configuration.

## Is Windows supported?

Native Windows is not currently supported. The scripts require Bash and Unix utilities such as `flock`. WSL may work but should be treated as unverified unless covered by CI or a documented test.

## Does macOS work?

The project targets Unix-like systems, but the default implementation depends on `flock`, which is not included with a standard macOS installation. Linux is the currently supported and tested platform.

## How do I add another profile later?

```bash
codexpm add 4
codexpm login 4
codexpm doctor
```

## Can I safely uninstall it?

Yes. A normal uninstall removes manager commands and optional shell integration while preserving profiles, configuration, backups, and the original Codex home.

```bash
bash uninstall.sh
```

Use `--purge` only when you intentionally want the managed profile directories and configuration removed as well.

## What should I do after upgrading Codex CLI?

Run:

```bash
codexpm doctor
```

Review any new files in the original Codex home before deciding whether they belong in `CODEX_SHARED_ITEMS`.

## Is this an official OpenAI project?

No. It is an independent, unofficial community project and is not affiliated with or endorsed by OpenAI.
