import SwiftUI
import LumenMediaCore

struct LibrariesListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var libraries: [LibraryDto] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && libraries.isEmpty {
                LoadingStateView()
            } else if let error, libraries.isEmpty {
                ErrorStateView(message: error) {
                    Task { await load() }
                }
            } else if libraries.isEmpty {
                EmptyStateView(
                    title: "No libraries",
                    message: "Ask an admin to add a library, or create one in Settings.",
                    systemImage: "rectangle.stack"
                )
            } else {
                List(libraries) { library in
                    NavigationLink(value: AppDestination.library(library.id)) {
                        HStack(spacing: 14) {
                            Image(systemName: library.type == "Series" ? "tv.fill" : "film.fill")
                                .font(.title3)
                                .foregroundStyle(LumenColors.accent)
                                .frame(width: 36, height: 36)
                                .background(LumenColors.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(library.name)
                                    .font(.headline)
                                    .foregroundStyle(LumenColors.text)
                                Text("\(library.type) · \(library.itemCount) items")
                                    .font(.caption)
                                    .foregroundStyle(LumenColors.muted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(LumenColors.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationTitle("Libraries")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            libraries = try await env.api.libraries()
            loading = false
        } catch {
            loading = false
            self.error = error.lumenUserMessage("Failed to load libraries")
        }
    }
}
