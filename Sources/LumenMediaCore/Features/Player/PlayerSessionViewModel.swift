import Foundation
import Combine

/// Pure session orchestration for playback (no AVPlayer). UI layer attaches the stream URL.
@MainActor
public final class PlayerSessionViewModel: ObservableObject {
    @Published public private(set) var loading: Bool = true
    @Published public private(set) var error: String?
    @Published public private(set) var decision: PlaybackDecisionResponse?
    @Published public private(set) var selectedQualityId: String = "auto"
    @Published public private(set) var selectedAudioId: String?
    @Published public private(set) var baseUrl: String = ""
    @Published public private(set) var isOffline: Bool = false
    @Published public var positionMs: Int64 = 0
    @Published public var durationMs: Int64 = 0

    public let itemId: String
    private let api: any LumenMediaServing
    private let settingsStore: SettingsStore
    private let offline: OfflineDownloadManager?
    private var sessionId: String?
    private var cacheToken: Int = 0
    private var progressTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var offlinePlayback = false
    private var localFileURL: URL?

    public init(
        itemId: String,
        resumeMs: Int64 = 0,
        api: any LumenMediaServing,
        settingsStore: SettingsStore,
        offline: OfflineDownloadManager? = nil
    ) {
        self.itemId = itemId
        self.api = api
        self.settingsStore = settingsStore
        self.offline = offline
        self.positionMs = resumeMs
    }

    /// Optional bearer token for stream URLs (`access_token` query).
    public var accessToken: String?

    public var streamSource: PlaybackSource? {
        if let localFileURL {
            return .direct(url: localFileURL.absoluteString)
        }
        guard let decision else { return nil }
        return resolvePlaybackSource(
            decision: decision,
            baseUrl: baseUrl,
            cacheToken: String(cacheToken),
            accessToken: accessToken
        )
    }

    public func start(resumeMs: Int64? = nil, qualityId: String? = nil, mode: String? = nil) async {
        loading = true
        error = nil
        isOffline = false
        offlinePlayback = false
        localFileURL = nil
        let resume = resumeMs ?? positionMs
        if let previous = sessionId, previous != Self.offlineSessionId {
            await api.stopSession(sessionId: previous)
        }
        sessionId = nil

        if let local = offline?.readyFileURL(for: itemId) {
            if Self.avPlayerCanPlayLocally(local) {
                await playLocalFile(local, resumeMs: resume)
                return
            }
            // Cached Matroska/etc. cannot be opened by AVPlayer — stream over the network instead.
        }

        do {
            var resolvedResume = resume
            if resume <= 0 {
                if let progress = try? await api.getProgress(itemId: itemId) {
                    resolvedResume = progress.positionMs
                }
            }
            let settings = settingsStore.currentSettings
            let cap = settingsStore.capFor(kind: NetworkMonitor.shared.kind)
            let preferredMode = mode ?? settings.preferredMode
            let profile = DeviceProfileFactory.build(maxBitrateKbps: cap)
            let decision = try await api.playbackDecision(
                PlaybackDecisionRequest(
                    mediaId: itemId,
                    mode: preferredMode,
                    qualityId: qualityId,
                    audioStreamId: selectedAudioId,
                    resumePositionMs: resolvedResume,
                    profile: profile
                )
            )
            sessionId = decision.sessionId
            cacheToken += 1
            self.decision = decision
            selectedQualityId = decision.selectedQualityId
            selectedAudioId = Self.defaultAudioId(in: decision) ?? selectedAudioId
            baseUrl = settings.baseUrl
            positionMs = decision.startPositionMs ?? resolvedResume
            durationMs = decision.durationMs ?? durationMs
            loading = false
            startProgressLoop()
            startPingLoop()
        } catch {
            loading = false
            self.error = error.lumenUserMessage("Playback failed")
        }
    }

    private func playLocalFile(_ fileURL: URL, resumeMs: Int64) async {
        localFileURL = fileURL
        offlinePlayback = true
        isOffline = true
        sessionId = Self.offlineSessionId
        decision = PlaybackDecisionResponse(
            sessionId: Self.offlineSessionId,
            method: "DirectPlay",
            mode: "manual",
            streamUrl: fileURL.absoluteString,
            container: fileURL.pathExtension,
            startPositionMs: resumeMs,
            selectedQualityId: "original",
            reason: "offline-cache"
        )
        selectedQualityId = "original"
        selectedAudioId = nil
        baseUrl = settingsStore.currentSettings.baseUrl
        positionMs = resumeMs
        loading = false
        startProgressLoop()
        pingTask?.cancel()
    }

    public func changeQuality(_ qualityId: String) async {
        guard !offlinePlayback else { return }
        guard let decision else { return }
        let mode = QualityMode.mode(for: qualityId, available: decision.availableQualities)
        let position = positionMs
        do {
            let next = try await api.setQuality(
                sessionId: decision.sessionId,
                body: SetQualityRequest(qualityId: qualityId, mode: mode, resumePositionMs: position)
            )
            sessionId = next.sessionId
            cacheToken += 1
            self.decision = next
            selectedQualityId = next.selectedQualityId
            selectedAudioId = Self.defaultAudioId(in: next) ?? selectedAudioId
            positionMs = next.startPositionMs ?? position
        } catch {
            await start(resumeMs: position, qualityId: qualityId, mode: mode)
        }
    }

    public func changeAudio(_ audioId: String) async {
        guard !offlinePlayback else { return }
        guard let decision else { return }
        guard audioId != selectedAudioId else { return }
        let position = positionMs
        let previousSid = decision.sessionId
        selectedAudioId = audioId
        if previousSid != Self.offlineSessionId {
            await api.stopSession(sessionId: previousSid)
        }
        do {
            let settings = settingsStore.currentSettings
            let cap = settingsStore.capFor(kind: NetworkMonitor.shared.kind)
            let profile = DeviceProfileFactory.build(maxBitrateKbps: cap)
            let qualityId = decision.mode == "manual" ? selectedQualityId : nil
            let next = try await api.playbackDecision(
                PlaybackDecisionRequest(
                    mediaId: itemId,
                    mode: decision.mode,
                    qualityId: qualityId,
                    audioStreamId: audioId,
                    resumePositionMs: position,
                    profile: profile
                )
            )
            sessionId = next.sessionId
            cacheToken += 1
            self.decision = next
            selectedQualityId = next.selectedQualityId
            selectedAudioId = Self.defaultAudioId(in: next) ?? audioId
            positionMs = next.startPositionMs ?? position
            durationMs = next.durationMs ?? durationMs
            baseUrl = settings.baseUrl
            startPingLoop()
        } catch {
            self.error = error.lumenUserMessage("Could not change audio track")
        }
    }

    public func remoteSeek(_ targetMs: Int64) async {
        guard !offlinePlayback else {
            positionMs = targetMs
            return
        }
        guard let sid = sessionId else { return }
        do {
            let next = try await api.seekSession(sessionId: sid, positionMs: targetMs)
            sessionId = next.sessionId
            cacheToken += 1
            decision = next
            positionMs = next.startPositionMs ?? targetMs
        } catch let err {
            self.error = err.lumenUserMessage("Could not seek")
        }
    }

    public func reportProgress(stateName: String, position: Int64, duration: Int64) async {
        let sid = sessionId == Self.offlineSessionId ? nil : sessionId
        _ = try? await api.putProgress(
            itemId: itemId,
            body: ProgressRequest(
                positionMs: position,
                durationMs: max(0, duration),
                sessionId: sid,
                state: stateName
            )
        )
    }

    public func stop() async {
        progressTask?.cancel()
        pingTask?.cancel()
        let sid = sessionId == Self.offlineSessionId ? nil : sessionId
        let position = positionMs
        let duration = durationMs
        sessionId = nil
        localFileURL = nil
        offlinePlayback = false
        await reportProgress(stateName: "stopped", position: position, duration: duration)
        if let sid {
            await api.stopSession(sessionId: sid)
        }
    }

    private func startProgressLoop() {
        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { break }
                await reportProgress(stateName: "playing", position: positionMs, duration: durationMs)
            }
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        if offlinePlayback { return }
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, let sid = sessionId, sid != Self.offlineSessionId else { break }
                await api.pingSession(sessionId: sid)
            }
        }
    }

    private static let offlineSessionId = "offline"

    /// AVFoundation supports a narrow set of containers; Matroska/WebM need remux/transcode.
    public static func avPlayerCanPlayLocally(_ fileURL: URL) -> Bool {
        switch fileURL.pathExtension.lowercased() {
        case "mp4", "m4v", "mov", "m4a", "mp3", "aac":
            return true
        default:
            return false
        }
    }

    private static func defaultAudioId(in decision: PlaybackDecisionResponse) -> String? {
        decision.audioStreams.first(where: { $0.isDefault == true })?.id
            ?? decision.audioStreams.first?.id
    }
}
