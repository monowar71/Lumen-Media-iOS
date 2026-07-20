import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

public enum ConnectionKind: String, Sendable {
    case lan
    case external
}

public enum DeviceProfileFactory {
    public static func build(
        maxBitrateKbps: Int,
        maxResolution: String = "2160p"
    ) -> DeviceProfile {
        let hevc = supportsHEVC
        let hdr = supportsHDR
        var video = ["h264"]
        if hevc { video.append("hevc") }
        var audio = ["aac", "mp3", "ac3", "eac3", "opus"]
        return DeviceProfile(
            maxResolution: maxResolution,
            maxBitrateKbps: maxBitrateKbps,
            videoCodecs: video,
            audioCodecs: audio,
            // AVPlayer cannot play Matroska; match web profile so the server
            // remuxes/transcodes unsupported containers to HLS instead of DirectPlay.
            containers: ["hls", "mp4", "mov"],
            subtitleFormats: ["vtt", "srt", "ass"],
            supportsHevc: hevc,
            supportsHdr: hdr
        )
    }

    private static var supportsHEVC: Bool {
        #if canImport(AVFoundation)
        // HEVC decode is available on A9+ / Apple Silicon; treat as supported on modern targets.
        return true
        #else
        return true
        #endif
    }

    private static var supportsHDR: Bool {
        #if canImport(UIKit)
        return UIScreen.main.traitCollection.displayGamut == .P3
        #else
        return false
        #endif
    }
}
