import SwiftUI
import LumenMediaCore

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            switch auth.state.status {
            case .restoring:
                ZStack {
                    LumenColors.bg.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(LumenColors.accent)
                            .scaleEffect(1.2)
                        Text("Restoring session…")
                            .font(.subheadline)
                            .foregroundStyle(LumenColors.muted)
                    }
                }
            case .anonymous:
                LoginView()
            case .authenticated:
                MainShell()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.state.status)
    }
}
