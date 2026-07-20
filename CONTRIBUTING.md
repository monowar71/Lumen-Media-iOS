# Contributing to LumenMedia iOS

Thank you for contributing. Please also read the [Code of Conduct](CODE_OF_CONDUCT.md).

## Relationship to the server

This client is a thin UI over [Lumen-Media-Server](https://github.com/monowar71/Lumen-Media-Server).
API changes belong in the server OpenAPI contract first; regenerate client types/SDK in the same effort when possible.

## Workflow

1. Fork and clone.
2. Branch: `feat/<scope>-<short>` or `fix/<scope>-<short>`.
3. Keep PRs focused; Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `ci:`).
4. Run the project’s lint/tests before opening a PR.
5. Playback changes need a short manual verification note (DirectPlay / HLS / seek / subtitles).

## Security

Do not commit secrets. See [SECURITY.md](SECURITY.md).

## License

Contributions are accepted under the [GNU GPL v3](LICENSE).
