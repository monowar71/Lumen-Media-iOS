import SwiftUI
import LumenMediaCore

struct LoadingStateView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(LumenColors.accent)
                .scaleEffect(1.15)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LumenColors.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumenColors.bg)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryTitle: String = "Try again"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(LumenColors.accent)
            Text(message)
                .font(.body)
                .foregroundStyle(LumenColors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(LumenColors.accent)
                    .foregroundStyle(LumenColors.onAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumenColors.bg)
    }
}

struct EmptyStateView: View {
    let title: String
    var message: String?
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(LumenColors.muted.opacity(0.7))
            Text(title)
                .font(.headline)
                .foregroundStyle(LumenColors.text)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(LumenColors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumenColors.bg)
    }
}
