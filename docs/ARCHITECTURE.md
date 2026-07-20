# Architecture — LumenMedia iOS

Thin SwiftUI client. Business logic stays on [Lumen-Media-Server](https://github.com/monowar71/Lumen-Media-Server).

```
App-iOS (SwiftUI shell)
    └── LumenMediaCore (SPM)
          ├── Networking / session (Keychain)
          ├── Features (ViewModels)
          └── DesignSystem
```

- **MVVM** with protocol-injected API for unit tests
- Playback: `AVPlayer` after `POST /playback/decision`
- Tokens in Keychain; server URL in AppStorage/UserDefaults

See [AGENTS.md](../AGENTS.md) for player, resource, and DoD rules.
