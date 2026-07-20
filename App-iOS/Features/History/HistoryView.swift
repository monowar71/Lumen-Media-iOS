import SwiftUI
import LumenMediaCore

struct HistoryView: View {
    @EnvironmentObject private var env: AppEnvironment
    var onPlay: (String, Int64) -> Void

    var body: some View {
        StatefulViewModel(
            HistoryViewModel(api: env.api, settingsStore: env.settingsStore)
        ) { viewModel in
            HistoryContent(viewModel: viewModel, onPlay: onPlay)
        }
    }
}

private struct HistoryContent: View {
    @ObservedObject var viewModel: HistoryViewModel
    @EnvironmentObject private var env: AppEnvironment
    var onPlay: (String, Int64) -> Void
    @State private var confirmClear = false

    var body: some View {
        Group {
            let state = viewModel.state
            if state.loading && state.entries.isEmpty {
                LoadingStateView()
            } else if let error = state.error, state.entries.isEmpty {
                ErrorStateView(message: error) {
                    Task { await viewModel.refresh() }
                }
            } else if state.entries.isEmpty {
                EmptyStateView(
                    title: "No history yet",
                    message: "Watched titles will show up here.",
                    systemImage: "clock"
                )
            } else {
                List {
                    ForEach(state.entries, id: \.id) { entry in
                        historyRow(entry, baseUrl: state.baseUrl)
                            .listRowBackground(LumenColors.surface)
                            .onAppear {
                                if entry.id == state.entries.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                    }

                    if state.loadingMore {
                        HStack {
                            Spacer()
                            ProgressView().tint(LumenColors.accent)
                            Spacer()
                        }
                        .listRowBackground(LumenColors.bg)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { confirmClear = true }
                    .disabled(viewModel.state.entries.isEmpty || viewModel.state.clearing)
            }
        }
        .confirmationDialog(
            "Clear watch history?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear history", role: .destructive) {
                Task { await viewModel.clear() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }

    private func historyRow(_ entry: HistoryEntry, baseUrl: String) -> some View {
        let title = entry.title ?? "Untitled"
        let subtitle: String = {
            if let series = entry.seriesTitle,
               let s = entry.seasonNumber,
               let e = entry.episodeNumber
            {
                return "\(series) · S\(s)E\(e)"
            }
            return entry.kind ?? ""
        }()

        return Button {
            if let itemId = entry.itemId {
                onPlay(itemId, entry.positionMs ?? 0)
            }
        } label: {
            HStack(spacing: 12) {
                PosterImage(
                    path: entry.artwork?.poster ?? entry.artwork?.thumb,
                    baseUrl: baseUrl,
                    accessToken: env.sessionStore.accessToken,
                    width: 120,
                    height: 180
                )
                .aspectRatio(LumenLayout.posterAspect, contentMode: .fill)
                .frame(width: 52, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LumenColors.text)
                        .lineLimit(2)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(LumenColors.muted)
                    }
                    if let position = entry.positionMs, let duration = entry.durationMs, duration > 0 {
                        Text("\(Formatters.time(position)) / \(Formatters.time(duration))")
                            .font(.caption2)
                            .foregroundStyle(LumenColors.muted)
                    }
                }
                Spacer()
                if entry.watched == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LumenColors.accent)
                } else {
                    Image(systemName: "play.circle")
                        .foregroundStyle(LumenColors.muted)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(entry.itemId == nil)
    }
}
