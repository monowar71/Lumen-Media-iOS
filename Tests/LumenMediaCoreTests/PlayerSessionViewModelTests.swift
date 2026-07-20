import XCTest
@testable import LumenMediaCore

@MainActor
final class PlayerSessionViewModelTests: XCTestCase {
    private var api: MockLumenMediaAPI!
    private var settingsStore: SettingsStore!
    private var suiteName: String!

    override func setUp() async throws {
        api = MockLumenMediaAPI()
        suiteName = "test.lumen.player.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.setBaseUrl("http://host:8096")
        settingsStore.setPreferredMode("auto")
    }

    override func tearDown() async throws {
        if let suiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        api = nil
        settingsStore = nil
        suiteName = nil
    }

    func testStart_loadsPlaybackDecision() async {
        api.playbackDecisionResult = .success(
            PlaybackDecisionResponse(
                sessionId: "sess-1",
                method: "DirectPlay",
                streamUrl: "/api/v1/stream/file",
                startPositionMs: 1_200,
                durationMs: 90_000,
                selectedQualityId: "auto",
                availableQualities: [
                    QualityOption(id: "auto", label: "Auto", adaptive: true),
                    QualityOption(id: "1080p", label: "1080p", height: 1080),
                ]
            )
        )

        let vm = PlayerSessionViewModel(
            itemId: "m1",
            resumeMs: 1_200,
            api: api,
            settingsStore: settingsStore
        )
        await vm.start()

        XCTAssertFalse(vm.loading)
        XCTAssertNil(vm.error)
        XCTAssertEqual(vm.decision?.sessionId, "sess-1")
        XCTAssertEqual(vm.selectedQualityId, "auto")
        XCTAssertEqual(vm.positionMs, 1_200)
        XCTAssertEqual(vm.durationMs, 90_000)
        XCTAssertEqual(vm.baseUrl, "http://host:8096")
        XCTAssertEqual(vm.streamSource, .direct(url: "http://host:8096/api/v1/stream/file"))

        await vm.stop()
    }

    func testChangeQuality_callsSetQuality() async {
        api.playbackDecisionResult = .success(
            PlaybackDecisionResponse(
                sessionId: "sess-1",
                method: "Transcode",
                streamUrl: "/api/v1/stream/sess-1/master.m3u8",
                selectedQualityId: "auto",
                availableQualities: [
                    QualityOption(id: "auto", label: "Auto", adaptive: true),
                    QualityOption(id: "720p", label: "720p", height: 720),
                ]
            )
        )

        let vm = PlayerSessionViewModel(itemId: "m1", api: api, settingsStore: settingsStore)
        await vm.start()
        vm.positionMs = 5_000
        await vm.changeQuality("720p")

        XCTAssertEqual(api.setQualityCalls.count, 1)
        XCTAssertEqual(api.setQualityCalls[0].0, "sess-1")
        XCTAssertEqual(api.setQualityCalls[0].1.qualityId, "720p")
        XCTAssertEqual(api.setQualityCalls[0].1.mode, "manual")
        XCTAssertEqual(api.setQualityCalls[0].1.resumePositionMs, 5_000)
        XCTAssertEqual(vm.selectedQualityId, "720p")
        XCTAssertEqual(vm.decision?.method, "Transcode")

        await vm.stop()
    }

    func testStop_callsStopSession() async {
        api.playbackDecisionResult = .success(
            PlaybackDecisionResponse(
                sessionId: "sess-99",
                method: "DirectPlay",
                streamUrl: "/file"
            )
        )

        let vm = PlayerSessionViewModel(itemId: "m1", api: api, settingsStore: settingsStore)
        await vm.start()
        XCTAssertTrue(api.stopSessionCalls.isEmpty)

        await vm.stop()

        XCTAssertEqual(api.stopSessionCalls, ["sess-99"])
        XCTAssertEqual(api.putProgressCalls.last?.1.state, "stopped")
    }

    func testAvPlayerCanPlayLocally_supportsAppleContainersOnly() {
        XCTAssertTrue(PlayerSessionViewModel.avPlayerCanPlayLocally(URL(fileURLWithPath: "/tmp/a.mp4")))
        XCTAssertTrue(PlayerSessionViewModel.avPlayerCanPlayLocally(URL(fileURLWithPath: "/tmp/a.mov")))
        XCTAssertFalse(PlayerSessionViewModel.avPlayerCanPlayLocally(URL(fileURLWithPath: "/tmp/a.mkv")))
        XCTAssertFalse(PlayerSessionViewModel.avPlayerCanPlayLocally(URL(fileURLWithPath: "/tmp/a.webm")))
    }

    func testChangeAudio_reopensPlaybackDecisionWithAudioStreamId() async {
        api.playbackDecisionResult = .success(
            PlaybackDecisionResponse(
                sessionId: "sess-1",
                method: "Transcode",
                streamUrl: "/api/v1/stream/sess-1/master.m3u8",
                selectedQualityId: "auto",
                availableQualities: [QualityOption(id: "auto", label: "Auto", adaptive: true)],
                audioStreams: [
                    AudioStreamOption(id: "a1", language: "eng", codec: "aac", channels: 2, isDefault: true),
                    AudioStreamOption(id: "a2", language: "rus", codec: "ac3", channels: 6, isDefault: false),
                ]
            )
        )

        let vm = PlayerSessionViewModel(itemId: "m1", api: api, settingsStore: settingsStore)
        await vm.start()
        XCTAssertEqual(vm.selectedAudioId, "a1")

        api.playbackDecisionResult = .success(
            PlaybackDecisionResponse(
                sessionId: "sess-2",
                method: "Transcode",
                mode: "auto",
                streamUrl: "/api/v1/stream/sess-2/master.m3u8",
                selectedQualityId: "auto",
                availableQualities: [QualityOption(id: "auto", label: "Auto", adaptive: true)],
                audioStreams: [
                    AudioStreamOption(id: "a1", language: "eng", codec: "aac", channels: 2, isDefault: false),
                    AudioStreamOption(id: "a2", language: "rus", codec: "ac3", channels: 6, isDefault: true),
                ]
            )
        )
        vm.positionMs = 12_000
        await vm.changeAudio("a2")

        XCTAssertEqual(api.stopSessionCalls, ["sess-1"])
        XCTAssertEqual(api.playbackDecisionCalls.count, 2)
        XCTAssertEqual(api.playbackDecisionCalls.last?.audioStreamId, "a2")
        XCTAssertEqual(api.playbackDecisionCalls.last?.resumePositionMs, 12_000)
        XCTAssertEqual(vm.selectedAudioId, "a2")
        XCTAssertEqual(vm.decision?.sessionId, "sess-2")

        await vm.stop()
    }
}
