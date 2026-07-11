# Frequently asked questions

## How many profiles can I configure?

The setup wizard asks how many profiles you want. You can configure one or more profiles and add more later.

## Can I name the profiles?

Yes. During setup you can use names such as `personal`, `work`, or `backup`. Press Enter to keep the numeric defaults.

```text
1
2
3
```

Profile names may contain letters, numbers, dots, underscores, and hyphens.

## Does this bypass Codex limits?

No. The project only manages local authentication profiles and shared local state. Each account remains subject to its own plan, limits, policies, and terms.

## Does it modify the Codex binary?

No. The original executable specified by `CODEX_BIN` is never renamed, replaced, or patched. The project installs separate commands and optional shell functions.

## What is shared between profiles?

Only items in `CODEX_SHARED_ITEMS`. The default allowlist includes known session, history, configuration, memory, and state files. Authentication is never shared by the manager.

## Why are unknown Codex files not shared automatically?

A future Codex version may add account-specific or sensitive files. Keeping unknown items private is safer than sharing everything except a denylist.

## Can I start a new session instead of resuming the last one?

```bash
codexpm run new
```

With the optional shell function:

```bash
codex new
```

## Can I switch directly to a specific profile?

```bash
codexpm use work
```

Rotate to the next configured profile with:

```bash
codexpm next
```

## Can I remove a profile from the rotation?

Yes. Preserve its local files with:

```bash
codexpm remove work
```

Remove it and delete its verified local profile directory with:

```bash
codexpm remove work --delete-files
```

Shared sessions and history are not deleted. The last configured profile cannot be removed accidentally.

## Can two managed Codex sessions run simultaneously?

Not safely against the same shared state. `codexpm run` uses a per-user lock and refuses a second concurrent managed session.

## Can I keep every profile completely separate?

That is not this project's primary purpose. Use separate `CODEX_HOME` directories without shared links when you want isolated sessions and configuration.

## Is Windows supported?

Native Windows is not currently supported. The scripts require Bash and Unix utilities such as `flock`. WSL may work but is not currently covered by CI.

## Does macOS work?

The default implementation depends on `flock`, which is not included with a standard macOS installation. Linux is the currently supported and tested platform.

## How do I add another profile later?

```bash
codexpm add 4
codexpm login 4
codexpm doctor
```

A named profile works the same way:

```bash
codexpm add work
codexpm login work
```

## Can I safely uninstall it?

Yes. Remove the manager commands while preserving profiles and configuration:

```bash
codexpm uninstall
```

Return to the original Codex setup and remove verified managed profiles:

```bash
codexpm uninstall --purge
```

The original Codex binary, original home, and backups are not removed.

## What should I do after upgrading Codex CLI?

```bash
codexpm doctor
```

Review any new files in the original Codex home before deciding whether they belong in `CODEX_SHARED_ITEMS`.

## Is this an official OpenAI project?

No. It is an independent, unofficial community project and is not affiliated with or endorsed by OpenAI.
