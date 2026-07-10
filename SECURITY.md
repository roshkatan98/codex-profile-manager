# Security policy

## Never include secrets in reports

Do not open an issue, pull request, discussion, or log attachment containing:

- `auth.json`
- access tokens or refresh tokens
- browser/device login codes
- private Codex session content
- private repository paths or configuration that you do not intend to disclose

Redact paths and replace account ids with placeholders when necessary.

## Local file permissions

The manager creates configuration, active-account state, and authentication files with restrictive permissions where it controls creation. Profile directories should be mode `700`, while `auth.json` and configuration files should be mode `600`.

## Authentication isolation

Only the first profile may inherit the original Codex authentication during a new installation. Additional profiles start without `auth.json` and must be logged in independently.

Do not copy one profile's `auth.json` to another profile and then run logout. Some authentication systems may invalidate shared credentials.

## Shared state

The manager shares only an explicit allowlist. Do not add unknown files to `CODEX_SHARED_ITEMS` unless you have confirmed they do not contain account-specific credentials or secrets.

## Reporting a vulnerability

Open a private security advisory in the GitHub repository when available. Include a minimal reproduction and exclude all real tokens and private session data.
