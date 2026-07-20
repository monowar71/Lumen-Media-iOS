import SwiftUI
import LumenMediaCore

struct SearchView: View {
    @EnvironmentObject private var env: AppEnvironment
    var onPlay: (String, Int64) -> Void

    var body: some View {
        StatefulViewModel(
            SearchViewModel(api: env.api, settingsStore: env.settingsStore)
        ) { viewModel in
            SearchContent(viewModel: viewModel, onPlay: onPlay)
        }
    }
}

private struct SearchContent: View {
    @ObservedObject var viewModel: SearchViewModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    var onPlay: (String, Int64) -> Void

    var body: some View {
        Group {
            let state = viewModel.state
            if state.query.count <= 1 {
                EmptyStateView(
                    title: "Search your library",
                    message: "Type at least 2 characters to find movies, series, and episodes.",
                    systemImage: "magnifyingglass"
                )
            } else if state.loading && state.isEmpty {
                LoadingStateView(message: "Searching…")
            } else if let error = state.error, state.isEmpty {
                ErrorStateView(message: error) {
                    Task { await viewModel.search() }
                }
            } else if state.isEmpty {
                EmptyStateView(
                    title: "No results",
                    message: "Nothing matched “\(state.query)”.",
                    systemImage: "magnifyingglass"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if !state.movies.isEmpty {
                            MediaRow(
                                title: "Movies",
                                items: state.movies,
                                baseUrl: state.baseUrl,
                                accessToken: env.sessionStore.accessToken,
                                cardWidth: sizeClass == .regular
                                    ? LumenLayout.cardWidthPad
                                    : LumenLayout.cardWidthPhone
                            )
                        }
                        if !state.series.isEmpty {
                            MediaRow(
                                title: "Series",
                                items: state.series,
                                baseUrl: state.baseUrl,
                                accessToken: env.sessionStore.accessToken,
                                cardWidth: sizeClass == .regular
                                    ? LumenLayout.cardWidthPad
                                    : LumenLayout.cardWidthPhone
                            )
                        }
                        if !state.episodes.isEmpty {
                            episodeResults(state.episodes, baseUrl: state.baseUrl)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationTitle("Search")
        .searchable(
            text: Binding(
                get: { viewModel.state.query },
                set: { viewModel.onQueryChange($0) }
            ),
            prompt: "Movies, series, episodes"
        )
    }

    private func episodeResults(_ episodes: [EpisodeSummary], baseUrl: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.title3.weight(.bold))
                .foregroundStyle(LumenColors.text)
                .padding(.horizontal, 16)

            ForEach(episodes) { episode in
                Button {
                    onPlay(episode.id, episode.userData.playbackPositionMs ?? 0)
                } label: {
                    HStack(spacing: 12) {
                        PosterImage(
                            path: episode.artwork.thumb ?? episode.artwork.poster,
                            baseUrl: baseUrl,
                            accessToken: env.sessionStore.accessToken,
                            width: 240,
                            height: 135
                        )
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(width: 100, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.title ?? "Episode \(episode.episodeNumber)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LumenColors.text)
                                .lineLimit(1)
                            Text("S\(episode.seasonNumber)E\(episode.episodeNumber)")
                                .font(.caption)
                                .foregroundStyle(LumenColors.muted)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(LumenColors.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
