import SwiftUI
import LumenMediaCore

struct MainShell: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedTab: PhoneTab = .home
    @State private var sidebarSelection: SidebarItem? = .home
    @State private var libraries: [LibraryDto] = []
    @State private var playerRoute: PlayerRoute?

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadShell
            } else {
                iPhoneShell
            }
        }
        .fullScreenCover(item: $playerRoute) { route in
            PlayerView(itemId: route.itemId, resumeMs: route.resumeMs)
                .environmentObject(env)
        }
        .task {
            await loadLibraries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumenPlayItem)) { note in
            guard let info = note.userInfo,
                  let itemId = info["itemId"] as? String
            else { return }
            let resume = (info["resumeMs"] as? Int64) ?? 0
            playerRoute = PlayerRoute(itemId: itemId, resumeMs: resume)
        }
    }

    // MARK: - iPhone

    private var iPhoneShell: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(onPlay: presentPlayer)
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(PhoneTab.home)

            NavigationStack {
                SearchView(onPlay: presentPlayer)
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(PhoneTab.search)

            NavigationStack {
                LibrariesListView()
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
            .tabItem { Label("Libraries", systemImage: "rectangle.stack.fill") }
            .tag(PhoneTab.libraries)

            NavigationStack {
                HistoryView(onPlay: presentPlayer)
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
            .tabItem { Label("History", systemImage: "clock.fill") }
            .tag(PhoneTab.history)

            NavigationStack {
                SettingsView()
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(PhoneTab.settings)
        }
        .toolbarBackground(LumenColors.bg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }

    // MARK: - iPad

    private var iPadShell: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Section("Browse") {
                    Label("Home", systemImage: "house.fill")
                        .tag(SidebarItem.home)
                    Label("Search", systemImage: "magnifyingglass")
                        .tag(SidebarItem.search)
                    Label("History", systemImage: "clock.fill")
                        .tag(SidebarItem.history)
                }

                Section("Libraries") {
                    if libraries.isEmpty {
                        Text("No libraries")
                            .foregroundStyle(LumenColors.muted)
                    } else {
                        ForEach(libraries) { lib in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lib.name)
                                    Text("\(lib.itemCount) items")
                                        .font(.caption)
                                        .foregroundStyle(LumenColors.muted)
                                }
                            } icon: {
                                Image(systemName: lib.type == "Series" ? "tv" : "film")
                            }
                            .tag(SidebarItem.library(lib.id))
                        }
                    }
                }

                Section {
                    Label("Settings", systemImage: "gearshape.fill")
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("LumenMedia")
            .scrollContentBackground(.hidden)
            .background(LumenColors.surface)
        } detail: {
            NavigationStack {
                detailContent
                    .navigationDestination(for: AppDestination.self) { dest in
                        destinationView(dest)
                    }
            }
        }
        .tint(LumenColors.accent)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch sidebarSelection ?? .home {
        case .home:
            HomeView(onPlay: presentPlayer)
        case .search:
            SearchView(onPlay: presentPlayer)
        case .history:
            HistoryView(onPlay: presentPlayer)
        case .library(let id):
            LibraryView(libraryId: id)
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private func destinationView(_ dest: AppDestination) -> some View {
        switch dest {
        case .item(let id):
            ItemDetailView(itemId: id, onPlay: presentPlayer)
        case .library(let id):
            LibraryView(libraryId: id)
        }
    }

    private func presentPlayer(itemId: String, resumeMs: Int64) {
        playerRoute = PlayerRoute(itemId: itemId, resumeMs: resumeMs)
    }

    private func loadLibraries() async {
        do {
            libraries = try await env.api.libraries()
        } catch {
            libraries = []
        }
    }
}

// MARK: - Tabs / Sidebar

private enum PhoneTab: Hashable {
    case home, search, libraries, history, settings
}

private enum SidebarItem: Hashable {
    case home, search, history, settings
    case library(String)
}

extension Notification.Name {
    static let lumenPlayItem = Notification.Name("lumen.playItem")
}
