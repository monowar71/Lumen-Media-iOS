# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| `main` (pre-1.0 development) | Yes |
| Tagged releases (when published) | Latest minor only |

## Reporting a vulnerability

**Do not open a public issue for security vulnerabilities.**

Report privately via:

1. [GitHub Security Advisories](https://github.com/monowar71/Lumen-Media-iOS/security/advisories/new) (preferred)
2. A private message to the repository owner via GitHub

Include reproduction steps, affected commit/version, and impact (token theft, XSS, local data exposure, etc.).

We aim to acknowledge reports within **72 hours**.

## Client-specific notes

- Never commit API tokens, keystores, or `local.properties` / `.env` files.
- Store refresh/access tokens only in platform-secure storage (Keychain / EncryptedSharedPreferences / memory+session as documented).
- Treat the companion server URL as untrusted input; validate TLS when exposing beyond LAN.
