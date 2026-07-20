import SwiftUI
import LumenMediaCore

struct HeroBanner: View {
    let item: MediaItemSummary
    let baseUrl: String
    var accessToken: String?
    var onPlay: (String, Int64) -> Void

    private var canResume: Bool {
        (item.userData.playbackPositionMs ?? 0) > 0 && item.userData.watched != true
            || (item.userData.nextUp?.userData.playbackPositionMs ?? 0) > 0
    }

    private var playTarget: (id: String, resumeMs: Int64) {
        if let next = item.userData.nextUp {
            return (next.id, next.userData.playbackPositionMs ?? 0)
        }
        return (item.id, item.userData.playbackPositionMs ?? 0)
    }

    var body: some View {
        let fraction = Formatters.progressFraction(
            positionMs: item.userData.nextUp?.userData.playbackPositionMs
                ?? item.userData.playbackPositionMs,
            durationMs: item.userData.nextUp?.runtimeMs ?? item.runtimeMs
        )

        ZStack(alignment: .bottomLeading) {
            backdrop

            // Match web `.hero-scrim`: transparent at the top, soft fade into bg at the bottom.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: LumenColors.bg.opacity(0.25), location: 0.45),
                    .init(color: LumenColors.bg.opacity(0.75), location: 0.75),
                    .init(color: LumenColors.bg, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Match web `from-bg via-bg/70 to-transparent` — only enough for text, not a full veil.
            LinearGradient(
                stops: [
                    .init(color: LumenColors.bg.opacity(0.72), location: 0),
                    .init(color: LumenColors.bg.opacity(0.35), location: 0.45),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                Text(canResume ? "CONTINUE WATCHING" : "FEATURED")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(LumenColors.accent)

                Text(item.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(LumenColors.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 2)

                Text(metaLine)
                    .font(.subheadline)
                    .foregroundStyle(LumenColors.muted)

                if fraction > 0, item.userData.watched != true {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.2))
                            Capsule()
                                .fill(LumenColors.accent)
                                .frame(width: max(0, geo.size.width * fraction))
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 260)
                }

                HStack(spacing: 12) {
                    Button {
                        let target = playTarget
                        onPlay(target.id, target.resumeMs)
                    } label: {
                        Label(
                            canResume ? "Resume" : "Play",
                            systemImage: "play.fill"
                        )
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(LumenColors.accent)
                        .foregroundStyle(LumenColors.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AppDestination.item(item.id)) {
                        Text("Details")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(LumenColors.surface2.opacity(0.85))
                            .foregroundStyle(LumenColors.text)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LumenColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 360)
        .clipped()
    }

    private var metaLine: String {
        var parts: [String] = []
        if let year = item.year { parts.append(String(year)) }
        parts.append(item.kind == "Series" ? "Series" : "Movie")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var backdrop: some View {
        let path = item.artwork.backdrop ?? item.artwork.poster
        if let url = UrlUtils.artworkUrl(
            baseUrl: baseUrl,
            path: path,
            width: 1600,
            height: 900,
            quality: 70,
            accessToken: accessToken
        ) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.05)
                default:
                    LumenColors.surface2
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
        } else {
            LumenColors.surface2
        }
    }
}
