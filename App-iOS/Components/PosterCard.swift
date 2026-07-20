import SwiftUI
import LumenMediaCore

struct PosterCard: View {
    let item: MediaItemSummary
    let baseUrl: String
    var accessToken: String?
    /// Fixed width for horizontal rows; `nil` fills available (grid) width.
    var width: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                poster
                badges
                progressBar
            }
            .aspectRatio(LumenLayout.posterAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LumenColors.border.opacity(0.5), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LumenColors.text)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LumenColors.muted)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private var poster: some View {
        GeometryReader { geo in
            PosterImage(
                path: item.artwork.poster,
                baseUrl: baseUrl,
                accessToken: accessToken,
                width: Int(geo.size.width * 2),
                height: Int(geo.size.height * 2)
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var badges: some View {
        if item.userData.watched == true {
            Text("WATCHED")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(LumenColors.accent)
                .foregroundStyle(LumenColors.onAccent)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        let fraction = Formatters.progressFraction(
            positionMs: item.userData.playbackPositionMs,
            durationMs: item.runtimeMs
        )
        if fraction > 0, item.userData.watched != true {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color.black.opacity(0.55)
                    LumenColors.accent
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let year = item.year { parts.append(String(year)) }
        if item.kind == "Series" { parts.append("Series") }
        return parts.joined(separator: " · ")
    }
}
