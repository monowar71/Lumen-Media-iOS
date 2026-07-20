# LumenMedia iOS

[![CI](https://github.com/monowar71/Lumen-Media-iOS/actions/workflows/ci.yml/badge.svg)](https://github.com/monowar71/Lumen-Media-iOS/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

**Native SwiftUI client** for iPhone and iPad (tvOS target planned). Thin UI over [Lumen-Media-Server](https://github.com/monowar71/Lumen-Media-Server) — libraries, details, HLS / Direct Play via `AVPlayer`, progress sync.

## Features

- Login / first-run setup against the LumenMedia API
- Home shelves, library grid, item details
- Playback with device profile → DirectPlay or HLS
- Quality / audio / subtitle selection; resume progress
- Design language aligned with the web client (cinema dark + mint accent)

## Requirements

- Xcode 16+ / iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A running [LumenMedia Server](https://github.com/monowar71/Lumen-Media-Server)

## Setup

```bash
git clone https://github.com/monowar71/Lumen-Media-iOS.git
cd Lumen-Media-iOS
xcodegen generate
open LumenMedia.xcodeproj
```

Set the server URL on the login screen (default `http://127.0.0.1:8096`).

## Tests

Unit tests live in the `LumenMediaCore` Swift package (`MockLumenMediaAPI`):

```bash
swift test
```

## Architecture

| Path | Role |
| --- | --- |
| `Sources/LumenMediaCore` | Models, API client, Keychain session, settings, ViewModels, design tokens |
| `App-iOS` | SwiftUI shell — TabView (iPhone), `NavigationSplitView` (iPad) |
| `Tests` / `UITests` | Unit and UI coverage |

MVVM: SwiftUI `View` ↔ observable ViewModel ↔ API protocols (testable).

More: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [AGENTS.md](AGENTS.md)

## Related repositories

| Repo | Role |
| --- | --- |
| [Lumen-Media-Server](https://github.com/monowar71/Lumen-Media-Server) | Backend API + transcoding |
| [Lumen-Media-Android](https://github.com/monowar71/Lumen-Media-Android) | Android / Android TV client |
| [Lumen-Media-Web](https://github.com/monowar71/Lumen-Media-Web) | Web client |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Security: [SECURITY.md](SECURITY.md).

## License

[GNU General Public License v3.0](LICENSE)

Copyright © 2026 Alexander Goncharow and contributors.
