import SwiftUI
import LumenMediaCore

struct LibraryView: View {
    @EnvironmentObject private var env: AppEnvironment
    let libraryId: String

    var body: some View {
        StatefulViewModel(
            LibraryViewModel(
                libraryId: libraryId,
                api: env.api,
                settingsStore: env.settingsStore
            )
        ) { viewModel in
            LibraryContent(viewModel: viewModel)
        }
    }
}

private struct LibraryContent: View {
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            let state = viewModel.state
            if state.loading && state.items.isEmpty {
                LoadingStateView()
            } else if let error = state.error, state.items.isEmpty {
                ErrorStateView(message: error) {
                    Task { await viewModel.refresh() }
                }
            } else {
                GeometryReader { geo in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            filterBar
                                .padding(.horizontal, 16)

                            if state.items.isEmpty {
                                EmptyStateView(
                                    title: "No items",
                                    message: "Try a different filter or scan the library.",
                                    systemImage: "film"
                                )
                                .frame(minHeight: 280)
                            } else {
                                LazyVGrid(
                                    columns: LumenLayout.posterColumns(for: geo.size.width),
                                    spacing: 14
                                ) {
                                    ForEach(state.items) { item in
                                        NavigationLink(value: AppDestination.item(item.id)) {
                                            PosterCard(
                                                item: item,
                                                baseUrl: state.baseUrl,
                                                accessToken: env.sessionStore.accessToken,
                                                width: nil
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .onAppear {
                                            if item.id == state.items.last?.id {
                                                viewModel.loadMore()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                if state.loadingMore {
                                    ProgressView()
                                        .tint(LumenColors.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationTitle(viewModel.state.library?.name ?? "Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: Binding(
                get: { viewModel.state.query },
                set: { viewModel.onQueryChange($0) }
            ),
            prompt: "Search library"
        )
        .toolbar { toolbarContent }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(LibrarySort.allCases, id: \.self) { sort in
                        Button(sort.displayName) {
                            viewModel.onSortChange(sort)
                        }
                    }
                } label: {
                    chipLabel("Sort: \(viewModel.state.sort.displayName)", systemImage: "arrow.up.arrow.down")
                }

                Button {
                    viewModel.toggleOrder()
                } label: {
                    chipLabel(
                        viewModel.state.orderAscending ? "Asc" : "Desc",
                        systemImage: viewModel.state.orderAscending
                            ? "arrow.up" : "arrow.down"
                    )
                }

                Menu {
                    ForEach(LibraryUiState.WatchedFilter.allCases, id: \.self) { filter in
                        Button(filter.rawValue.capitalized) {
                            viewModel.onWatchedFilterChange(filter)
                        }
                    }
                } label: {
                    chipLabel(
                        "Watched: \(viewModel.state.watchedFilter.rawValue)",
                        systemImage: "eye"
                    )
                }

                Toggle(isOn: Binding(
                    get: { viewModel.state.inProgressFirst },
                    set: { viewModel.onInProgressFirstChange($0) }
                )) {
                    Text("In progress first")
                        .font(.caption.weight(.semibold))
                }
                .toggleStyle(.button)
                .tint(viewModel.state.inProgressFirst ? LumenColors.accent : LumenColors.surface2)
            }
        }
    }

    private func chipLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LumenColors.surface2)
            .foregroundStyle(LumenColors.text)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LumenColors.border, lineWidth: 1))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }
}
