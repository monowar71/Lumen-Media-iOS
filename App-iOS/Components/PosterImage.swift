import SwiftUI
import LumenMediaCore

struct PosterImage: View {
    let path: String?
    let baseUrl: String
    var accessToken: String?
    var width: Int = 320
    var height: Int = 480

    var body: some View {
        Group {
            if let url = UrlUtils.artworkUrl(
                baseUrl: baseUrl,
                path: path,
                width: width,
                height: height,
                accessToken: accessToken
            ) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                            .overlay { ProgressView().tint(LumenColors.muted) }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            LumenColors.surface2
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(LumenColors.muted.opacity(0.5))
        }
    }
}
