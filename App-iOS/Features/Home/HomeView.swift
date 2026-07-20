import SwiftUI
import LumenMediaCore

struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    var onPlay: (String, Int64) -> Void

    var body: some View {
        StatefulViewModel(
            HomeViewModel(api: env.api, settingsStore: env.settingsStore)
        ) { viewModel in
            HomeContent(viewModel: viewModel, onPlay: onPlay)
        }
    }
}

private struct HomeContent: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    var onPlay: (String, Int64) -> Void

    var body: some View {
        Group {
            let state = viewModel.state
            if state.loading && state.sections.isEmpty {
                LoadingStateView()
            } else if let error = state.error, state.sections.isEmpty {
                ErrorStateView(message: error) {
                    Task { await viewModel.refresh() }
                }
            } else if state.sections.isEmpty {
                EmptyStateView(
                    title: "Nothing here yet",
                    message: "Add a library and scan your media to get started.",
                    systemImage: "house"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if let hero = state.heroItem {
                            HeroBanner(
                                item: hero,
                                baseUrl: state.baseUrl,
                                accessToken: env.sessionStore.accessToken,
                                onPlay: onPlay
                            )
                        }

                        ForEach(state.sections) { section in
                            MediaRow(
                                title: section.title,
                                items: section.items,
                                baseUrl: state.baseUrl,
                                accessToken: env.sessionStore.accessToken,
                                cardWidth: sizeClass == .regular
                                    ? LumenLayout.cardWidthPad
                                    : LumenLayout.cardWidthPhone
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        // Let the hero breathe — no opaque black strip over CONTINUE WATCHING.
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}
