import SwiftUI
import AVKit
import Combine
import LumenMediaCore

struct PlayerView: View {
    @EnvironmentObject private var env: AppEnvironment

    let itemId: String
    var resumeMs: Int64 = 0

    var body: some View {
        StatefulViewModel(
            makeSession()
        ) { session in
            PlayerContent(session: session, resumeMs: resumeMs)
        }
    }

    private func makeSession() -> PlayerSessionViewModel {
        let session = PlayerSessionViewModel(
            itemId: itemId,
            resumeMs: resumeMs,
            api: env.api,
            settingsStore: env.settingsStore,
            offline: env.offline
        )
        session.accessToken = env.sessionStore.accessToken
        return session
    }
}

private struct PlayerContent: View {
    @ObservedObject var session: PlayerSessionViewModel
    let resumeMs: Int64
    @Environment(\.dismiss) private var dismiss

    @StateObject private var playerHolder = AVPlayerHolder()
    @State private var attachError: String?

    private var displayError: String? {
        if let attachError { return attachError }
        if session.decision == nil { return session.error }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if session.loading && session.decision == nil {
                ProgressView("Starting playback…")
                    .tint(LumenColors.accent)
                    .foregroundStyle(.white)
            } else if let error = displayError {
                VStack(spacing: 16) {
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        attachError = nil
                        Task {
                            await session.start(resumeMs: max(resumeMs, session.positionMs))
                            applyStream()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LumenColors.accent)
                    .foregroundStyle(LumenColors.onAccent)
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            } else {
                VideoPlayer(player: playerHolder.player)
                    .ignoresSafeArea()
            }

            if session.decision != nil, displayError == nil {
                playerChrome
            }
        }
        .task {
            await session.start(resumeMs: resumeMs)
            applyStream()
        }
        .onChange(of: session.decision?.sessionId) { _, _ in
            applyStream()
        }
        .onDisappear {
            Task {
                await session.stop()
                playerHolder.release()
            }
        }
        .statusBarHidden(true)
    }

    /// Single close control + floating track/quality menus (no full-width dark bar).
    private var playerChrome: some View {
        VStack {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityIdentifier("player.close")
                .accessibilityLabel("Close")

                Spacer(minLength: 0)

                if session.isOffline {
                    Text("Offline")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(LumenColors.accent)
                }

                if let decision = session.decision,
                   decision.audioStreams.count > 1,
                   !session.isOffline {
                    Menu {
                        ForEach(decision.audioStreams) { stream in
                            Button {
                                Task {
                                    await session.changeAudio(stream.id)
                                    applyStream()
                                }
                            } label: {
                                HStack {
                                    Text(stream.displayLabel)
                                    if stream.id == session.selectedAudioId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(audioMenuTitle, systemImage: "waveform")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("player.audio")
                }

                if let decision = session.decision,
                   !decision.availableQualities.isEmpty,
                   !session.isOffline {
                    Menu {
                        ForEach(decision.availableQualities) { quality in
                            Button {
                                Task {
                                    await session.changeQuality(quality.id)
                                    applyStream()
                                }
                            } label: {
                                HStack {
                                    Text(quality.label)
                                    if quality.id == session.selectedQualityId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(qualityMenuTitle, systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("player.quality")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()
        }
    }

    private var qualityMenuTitle: String {
        session.decision?.availableQualities
            .first { $0.id == session.selectedQualityId }?
            .label ?? "Quality"
    }

    private var audioMenuTitle: String {
        session.decision?.audioStreams
            .first { $0.id == session.selectedAudioId }?
            .shortLabel ?? "Audio"
    }

    private func applyStream() {
        guard let source = session.streamSource else { return }
        guard let url = URL(string: source.url) else {
            attachError = "Invalid stream URL"
            return
        }

        let item: AVPlayerItem
        if url.isFileURL {
            item = AVPlayerItem(url: url)
        } else {
            var headers: [String: String] = [:]
            if let token = session.accessToken, !token.isEmpty {
                headers["Authorization"] = "Bearer \(token)"
            }
            let asset: AVURLAsset
            if headers.isEmpty {
                asset = AVURLAsset(url: url)
            } else {
                asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            }
            item = AVPlayerItem(asset: asset)
        }
        playerHolder.player.replaceCurrentItem(with: item)

        let seekMs = session.positionMs
        if session.decision?.method == "DirectPlay", seekMs > 0 {
            let time = CMTime(value: seekMs, timescale: 1000)
            playerHolder.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        playerHolder.player.play()
        attachError = nil
        playerHolder.startObserving { position, duration in
            session.positionMs = position
            if duration > 0 {
                session.durationMs = duration
            }
        }
    }
}

// MARK: - AVPlayer helpers

@MainActor
final class AVPlayerHolder: ObservableObject {
    let player = AVPlayer()
    private var timeObserver: Any?

    func startObserving(onTick: @escaping (Int64, Int64) -> Void) {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak player] time in
            guard let player else { return }
            let position = Int64(CMTimeGetSeconds(time) * 1000)
            let durationSec = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            let duration = durationSec.isFinite ? Int64(durationSec * 1000) : Int64(0)
            onTick(max(0, position), max(0, duration))
        }
    }

    func release() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
