# LumenMedia iOS

Native SwiftUI client for iPhone and iPad (tvOS target planned in P7).

## Requirements

- Xcode 16+ / iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
cd client_ios
xcodegen generate
open LumenMedia.xcodeproj
```

Set the server URL on the login screen (default `http://127.0.0.1:8096`).

## Tests

Unit tests live in the `LumenMediaCore` Swift package (ViewModels + pure helpers with `MockLumenMediaAPI`):

```bash
swift test
```

## Architecture

- `Sources/LumenMediaCore` — models, API client, Keychain session, settings, ViewModels, design tokens
- `App-iOS` — SwiftUI shell: TabView on iPhone, `NavigationSplitView` on iPad
- Visual language matches the web client (dark cinema `#0b1f1a` + mint accent `#3ecf9a`)
