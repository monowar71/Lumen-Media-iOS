import SwiftUI
import LumenMediaCore

@main
struct LumenMediaApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var authViewModel: AuthViewModel

    init() {
        let env = AppEnvironment()
        _environment = StateObject(wrappedValue: env)
        _authViewModel = StateObject(
            wrappedValue: AuthViewModel(
                api: env.api,
                sessionStore: env.sessionStore,
                settingsStore: env.settingsStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(authViewModel)
                .preferredColorScheme(.dark)
                .tint(LumenColors.accent)
                .task {
                    await authViewModel.bootstrap()
                }
        }
    }
}
