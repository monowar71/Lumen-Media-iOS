import SwiftUI
import LumenMediaCore

struct MediaRow: View {
    let title: String
    let items: [MediaItemSummary]
    let baseUrl: String
    var accessToken: String?
    var cardWidth: CGFloat = LumenLayout.cardWidthPhone

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(LumenColors.text)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: AppDestination.item(item.id)) {
                            PosterCard(
                                item: item,
                                baseUrl: baseUrl,
                                accessToken: accessToken,
                                width: cardWidth
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
}
