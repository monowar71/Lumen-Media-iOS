import SwiftUI
import LumenMediaCore

struct ItemDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    let itemId: String
    var onPlay: (String, Int64) -> Void

    var body: some View {
        StatefulViewModel(
            DetailsViewModel(
                itemId: itemId,
                api: env.api,
                settingsStore: env.settingsStore,
                offline: env.offline
            )
        ) { viewModel in
            ItemDetailContent(viewModel: viewModel, onPlay: onPlay)
        }
    }
}

private struct ItemDetailContent: View {
    @ObservedObject var viewModel: DetailsViewModel
    @EnvironmentObject private var env: AppEnvironment
    var onPlay: (String, Int64) -> Void

    var body: some View {
        Group {
            let state = viewModel.state
            if state.loading && state.movie == nil && state.series == nil {
                LoadingStateView()
            } else if let error = state.error, state.movie == nil, state.series == nil {
                ErrorStateView(message: error) {
                    Task { await viewModel.refresh() }
                }
            } else if let movie = state.movie {
                movieDetail(movie, baseUrl: state.baseUrl)
            } else if let series = state.series {
                seriesDetail(series, state: state)
            } else {
                EmptyStateView(title: "Item not found", systemImage: "questionmark.circle")
            }
        }
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
    }

    // MARK: - Movie

    private func movieDetail(_ movie: MovieDetail, baseUrl: String) -> some View {
        let canResume =
            (movie.userData.playbackPositionMs ?? 0) > 0 && movie.userData.watched != true
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                detailHero(
                    title: movie.title,
                    year: movie.year,
                    rating: movie.communityRating,
                    runtime: Formatters.runtime(movie.runtimeMs),
                    genres: movie.genres ?? [],
                    overview: movie.overview,
                    tagline: movie.tagline,
                    poster: movie.artwork.poster,
                    backdrop: movie.artwork.backdrop,
                    baseUrl: baseUrl,
                    watched: movie.userData.watched == true
                ) {
                    HStack(spacing: 12) {
                        Button {
                            onPlay(movie.id, movie.userData.playbackPositionMs ?? 0)
                        } label: {
                            Label(canResume ? "Resume" : "Play", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(LumenColors.accent)
                                .foregroundStyle(LumenColors.onAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        movieOfflineButton(movie.id)

                        Button {
                            Task { await viewModel.toggleMovieWatched() }
                        } label: {
                            Image(systemName: movie.userData.watched == true
                                  ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.title2)
                                .foregroundStyle(
                                    movie.userData.watched == true
                                    ? LumenColors.accent : LumenColors.muted
                                )
                                .frame(width: 52, height: 52)
                                .background(LumenColors.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(viewModel.state.markingWatched)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if let people = movie.people, !people.isEmpty {
                    peopleSection(people, baseUrl: baseUrl)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(movie.title)
    }

    // MARK: - Series

    private func seriesDetail(_ series: SeriesDetail, state: DetailsUiState) -> some View {
        let nextUp = series.userData.nextUp
        let resumeMs = nextUp?.userData.playbackPositionMs ?? 0
        let playId = nextUp?.id
        let seriesWatched = DetailsViewModel.isSeriesWatched(series)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                detailHero(
                    title: series.title,
                    year: series.year,
                    rating: series.communityRating,
                    runtime: "\(series.seasonCount) seasons · \(series.episodeCount) episodes",
                    genres: series.genres ?? [],
                    overview: series.overview,
                    tagline: series.status,
                    poster: series.artwork.poster,
                    backdrop: series.artwork.backdrop,
                    baseUrl: state.baseUrl,
                    watched: seriesWatched
                ) {
                    HStack(spacing: 12) {
                        if let playId {
                            Button {
                                onPlay(playId, resumeMs)
                            } label: {
                                Label(
                                    resumeMs > 0 ? "Resume" : "Play",
                                    systemImage: "play.fill"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(LumenColors.accent)
                                .foregroundStyle(LumenColors.onAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        Button {
                            Task { await viewModel.toggleSeriesWatched() }
                        } label: {
                            Image(systemName: seriesWatched
                                  ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.title2)
                                .foregroundStyle(seriesWatched ? LumenColors.accent : LumenColors.muted)
                                .frame(width: 52, height: 52)
                                .background(LumenColors.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(viewModel.state.markingWatched)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if !state.seasons.isEmpty {
                    seasonsSection(state: state)
                }

                if let people = series.people, !people.isEmpty {
                    peopleSection(people, baseUrl: state.baseUrl)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(series.title)
    }

    // MARK: - Shared hero

    private func detailHero<Actions: View>(
        title: String,
        year: Int?,
        rating: Double?,
        runtime: String,
        genres: [String],
        overview: String?,
        tagline: String?,
        poster: String?,
        backdrop: String?,
        baseUrl: String,
        watched: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                backdropImage(path: backdrop ?? poster, baseUrl: baseUrl)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [.clear, LumenColors.bg],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 16) {
                    PosterImage(
                        path: poster,
                        baseUrl: baseUrl,
                        accessToken: env.sessionStore.accessToken,
                        width: 240,
                        height: 360
                    )
                    .aspectRatio(LumenLayout.posterAspect, contentMode: .fit)
                    .frame(width: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(LumenColors.text)
                            .lineLimit(3)
                        Text(metaLine(year: year, rating: rating, runtime: runtime))
                            .font(.caption)
                            .foregroundStyle(LumenColors.muted)
                        if !genres.isEmpty {
                            Text(genres.prefix(3).joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(LumenColors.muted)
                        }
                        if watched {
                            Text("Watched")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LumenColors.accent)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if let tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline.italic())
                    .foregroundStyle(LumenColors.muted)
                    .padding(.horizontal, 16)
            }

            if let overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(LumenColors.text.opacity(0.9))
                    .padding(.horizontal, 16)
            }

            actions()
        }
    }

    private func metaLine(year: Int?, rating: Double?, runtime: String) -> String {
        var parts: [String] = []
        if let year { parts.append(String(year)) }
        if !runtime.isEmpty { parts.append(runtime) }
        if let rating { parts.append(String(format: "★ %.1f", rating)) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func backdropImage(path: String?, baseUrl: String) -> some View {
        if let url = UrlUtils.artworkUrl(
            baseUrl: baseUrl,
            path: path,
            width: 1200,
            height: 675,
            quality: 70,
            accessToken: env.sessionStore.accessToken
        ) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    LumenColors.surface2
                }
            }
        } else {
            LumenColors.surface2
        }
    }

    // MARK: - Seasons / episodes

    private func seasonsSection(state: DetailsUiState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Episodes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LumenColors.text)

                Spacer()

                Button {
                    Task { await viewModel.downloadSeason() }
                } label: {
                    Text(seasonOfflineLabel(state))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumenColors.accent)
                }
                .disabled(state.episodes.isEmpty)

                Button {
                    Task { await viewModel.toggleSeasonWatched() }
                } label: {
                    Text(
                        DetailsViewModel.isSeasonWatched(state.episodes)
                        ? "Mark season unwatched" : "Mark season watched"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LumenColors.accent)
                }
                .disabled(viewModel.state.markingWatched || state.episodes.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(state.seasons) { season in
                        Button {
                            Task { await viewModel.selectSeason(season.id) }
                        } label: {
                            Text(season.name)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    state.selectedSeasonId == season.id
                                    ? LumenColors.accent : LumenColors.surface2
                                )
                                .foregroundStyle(
                                    state.selectedSeasonId == season.id
                                    ? .black : LumenColors.text
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            LazyVStack(spacing: 0) {
                ForEach(state.episodes) { episode in
                    episodeRow(episode, baseUrl: state.baseUrl)
                    Divider().background(LumenColors.border)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func episodeRow(_ episode: EpisodeSummary, baseUrl: String) -> some View {
        let title = episode.title ?? "Episode \(episode.episodeNumber)"
        let canResume =
            (episode.userData.playbackPositionMs ?? 0) > 0 && episode.userData.watched != true

        return HStack(alignment: .top, spacing: 12) {
            PosterImage(
                path: episode.artwork.thumb ?? episode.artwork.poster,
                baseUrl: baseUrl,
                accessToken: env.sessionStore.accessToken,
                width: 320,
                height: 180
            )
            .aspectRatio(16 / 9, contentMode: .fill)
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("S\(episode.seasonNumber)E\(episode.episodeNumber) · \(title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LumenColors.text)
                    .lineLimit(2)
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(LumenColors.muted)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    Button {
                        onPlay(episode.id, episode.userData.playbackPositionMs ?? 0)
                    } label: {
                        Label(canResume ? "Resume" : "Play", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LumenColors.accent)
                    }
                    episodeOfflineControls(episode.id)
                    Button {
                        Task { await viewModel.toggleEpisodeWatched(episode.id) }
                    } label: {
                        Image(systemName: episode.userData.watched == true
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                episode.userData.watched == true
                                ? LumenColors.accent : LumenColors.muted
                            )
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func movieOfflineButton(_ mediaId: String) -> some View {
        let offline = viewModel.state.offlineByMediaId[mediaId]
        Button {
            Task {
                switch offline?.status {
                case .ready:
                    await viewModel.removeOffline(mediaId)
                case .queued, .downloading:
                    await viewModel.cancelOffline(mediaId)
                default:
                    await viewModel.downloadMovie()
                }
            }
        } label: {
            Image(systemName: offlineIcon(offline?.status))
                .font(.title2)
                .foregroundStyle(offline?.status == .failed ? .red : LumenColors.accent)
                .frame(width: 52, height: 52)
                .background(LumenColors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func episodeOfflineControls(_ episodeId: String) -> some View {
        let offline = viewModel.state.offlineByMediaId[episodeId]
        Button {
            Task {
                switch offline?.status {
                case .ready:
                    await viewModel.removeOffline(episodeId)
                case .queued, .downloading:
                    await viewModel.cancelOffline(episodeId)
                default:
                    await viewModel.downloadEpisode(episodeId)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: offlineIcon(offline?.status))
                if let offline {
                    Text(offlineBadge(offline))
                } else {
                    Text("Download")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(offline?.status == .failed ? .red : LumenColors.muted)
        }
    }

    private func offlineIcon(_ status: CachedMediaStatus?) -> String {
        switch status {
        case .ready: return "checkmark.circle.fill"
        case .downloading: return "arrow.down.circle"
        case .queued: return "clock"
        case .failed: return "exclamationmark.triangle"
        case nil: return "arrow.down.circle"
        }
    }

    private func offlineBadge(_ item: OfflineCachedItem) -> String {
        switch item.status {
        case .ready: return "Saved"
        case .queued: return "Queued"
        case .downloading: return "\(Int(item.progress * 100))%"
        case .failed: return "Retry"
        }
    }

    private func seasonOfflineLabel(_ state: DetailsUiState) -> String {
        let episodes = state.episodes
        guard !episodes.isEmpty else { return "Download season" }
        let allReady = episodes.allSatisfy { state.offlineByMediaId[$0.id]?.status == .ready }
        if allReady { return "Season saved" }
        let active = episodes.contains {
            let s = state.offlineByMediaId[$0.id]?.status
            return s == .queued || s == .downloading
        }
        return active ? "Downloading…" : "Download season"
    }

    private func peopleSection(_ people: [Person], baseUrl: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast & crew")
                .font(.title3.weight(.bold))
                .foregroundStyle(LumenColors.text)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(people.prefix(20)) { person in
                        VStack(spacing: 6) {
                            PosterImage(
                                path: person.thumb,
                                baseUrl: baseUrl,
                                accessToken: env.sessionStore.accessToken,
                                width: 160,
                                height: 160
                            )
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            Text(person.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LumenColors.text)
                                .lineLimit(1)
                            if let role = person.role {
                                Text(role)
                                    .font(.caption2)
                                    .foregroundStyle(LumenColors.muted)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 88)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
