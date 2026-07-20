import SwiftUI
import LumenMediaCore

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        StatefulViewModel(
            SettingsViewModel(
                api: env.api,
                settingsStore: env.settingsStore,
                sessionStore: env.sessionStore,
                offline: env.offline
            )
        ) { viewModel in
            SettingsContent(viewModel: viewModel)
        }
    }
}

private struct SettingsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Form {
            generalSection
            playbackSection
            offlineSection
            accountSection
            if viewModel.state.isAdmin {
                adminLibrariesSection
                adminJobsSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(LumenColors.bg.ignoresSafeArea())
        .navigationTitle("Settings")
        .tint(LumenColors.accent)
        .task {
            await viewModel.loadAdminData()
        }
    }

    private var generalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Server address")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LumenColors.muted)
                TextField(
                    "http://192.168.0.2:8096",
                    text: Binding(
                        get: { viewModel.state.baseUrl },
                        set: { viewModel.onBaseUrlChange($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            }

            Picker(
                "Language",
                selection: Binding(
                    get: { viewModel.state.locale },
                    set: { viewModel.onLocaleChange($0) }
                )
            ) {
                Text("Русский").tag("ru")
                Text("English").tag("en")
            }

            Button("Save client settings") {
                viewModel.saveClientSettings()
            }

            if let saved = viewModel.state.savedMessage {
                Text(saved)
                    .font(.caption)
                    .foregroundStyle(LumenColors.accent)
            }
        } header: {
            Text("General")
        } footer: {
            Text("Changing the server address requires signing in again after save.")
        }
        .listRowBackground(LumenColors.surface)
    }

    private var playbackSection: some View {
        Section("Playback") {
            Picker(
                "Preferred mode",
                selection: Binding(
                    get: { viewModel.state.preferredMode },
                    set: { viewModel.onPreferredModeChange($0) }
                )
            ) {
                Text("Auto").tag("auto")
                Text("Direct Play").tag("direct")
                Text("Transcode").tag("transcode")
            }

            Stepper(
                "LAN cap: \(capLabel(viewModel.state.lanCapKbps))",
                value: Binding(
                    get: { viewModel.state.lanCapKbps },
                    set: { viewModel.onLanCapChange($0) }
                ),
                in: 0...100_000,
                step: 1_000
            )

            Stepper(
                "Cellular / external cap: \(capLabel(viewModel.state.externalCapKbps))",
                value: Binding(
                    get: { viewModel.state.externalCapKbps },
                    set: { viewModel.onExternalCapChange($0) }
                ),
                in: 0...100_000,
                step: 1_000
            )

            Button("Save playback settings") {
                viewModel.saveClientSettings()
            }
        }
        .listRowBackground(LumenColors.surface)
    }

    private var offlineSection: some View {
        Section {
            LabeledContent("Cached items") {
                Text("\(viewModel.state.offlineSummary.readyCount)")
            }
            LabeledContent("Used") {
                Text(formatBytes(viewModel.state.offlineSummary.readyBytes))
            }
            if viewModel.state.offlineSummary.activeCount > 0 {
                LabeledContent("In progress") {
                    Text("\(viewModel.state.offlineSummary.activeCount)")
                }
            }

            Stepper(
                "Max cache: \(formatCacheLimit(viewModel.state.maxCacheBytes))",
                value: Binding(
                    get: {
                        let bytes = viewModel.state.maxCacheBytes
                        if bytes <= 0 { return 0.0 }
                        return Double(bytes) / (1024 * 1024 * 1024)
                    },
                    set: { viewModel.onMaxCacheGibChange($0) }
                ),
                in: 0...200,
                step: 5
            )

            Button("Save cache settings") {
                viewModel.saveClientSettings()
            }

            ForEach(viewModel.state.offlineEntries.prefix(20)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayTitle)
                            .font(.subheadline)
                            .lineLimit(2)
                        Text(offlineStatusLabel(item))
                            .font(.caption)
                            .foregroundStyle(LumenColors.muted)
                    }
                    Spacer()
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.removeOffline(item.mediaId) }
                    }
                    .font(.caption)
                }
            }

            if viewModel.state.offlineEntries.contains(where: { $0.status == .failed }) {
                Button("Remove failed downloads") {
                    Task { await viewModel.removeFailedOffline() }
                }
            }

            Button("Clear offline cache", role: .destructive) {
                Task { await viewModel.clearOfflineCache() }
            }
        } header: {
            Text("Offline cache")
        } footer: {
            Text("Downloads originals via the server download API. Playback uses the local file when available.")
        }
        .listRowBackground(LumenColors.surface)
    }

    private var accountSection: some View {
        Section("Account") {
            if let name = auth.state.displayName {
                LabeledContent("Signed in as", value: name)
            }
            if let role = auth.state.role {
                LabeledContent("Role", value: role)
            }
            Button("Sign out", role: .destructive) {
                Task { await auth.logout() }
            }
        }
        .listRowBackground(LumenColors.surface)
    }

    private var adminLibrariesSection: some View {
        Section {
            if viewModel.state.loadingLibraries && viewModel.state.libraries.isEmpty {
                ProgressView()
                    .tint(LumenColors.accent)
            }

            ForEach(viewModel.state.libraries) { library in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(library.name)
                                .font(.headline)
                            Text("\(library.type) · \(library.itemCount) items")
                                .font(.caption)
                                .foregroundStyle(LumenColors.muted)
                        }
                        Spacer()
                    }
                    HStack {
                        Button("Scan") {
                            Task { await viewModel.scanLibrary(library.id) }
                        }
                        .buttonStyle(.bordered)
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteLibrary(library.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Add library")
                    .font(.subheadline.weight(.semibold))
                TextField(
                    "Name",
                    text: Binding(
                        get: { viewModel.state.newLibraryName },
                        set: { viewModel.onNewLibraryName($0) }
                    )
                )
                Picker(
                    "Type",
                    selection: Binding(
                        get: { viewModel.state.newLibraryType },
                        set: { viewModel.onNewLibraryType($0) }
                    )
                ) {
                    Text("Movies").tag("Movies")
                    Text("Series").tag("Series")
                }
                .pickerStyle(.segmented)
                TextField(
                    "Path on server",
                    text: Binding(
                        get: { viewModel.state.newLibraryPath },
                        set: { viewModel.onNewLibraryPath($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                Button("Create library") {
                    Task { await viewModel.createLibrary() }
                }
                .buttonStyle(.borderedProminent)
                .tint(LumenColors.accent)
                .foregroundStyle(LumenColors.onAccent)
            }
            .padding(.vertical, 4)

            if let error = viewModel.state.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
            }
        } header: {
            Text("Admin · Libraries")
        }
        .listRowBackground(LumenColors.surface)
    }

    private var adminJobsSection: some View {
        Section("Admin · Recent jobs") {
            if viewModel.state.jobs.isEmpty {
                Text("No recent jobs")
                    .foregroundStyle(LumenColors.muted)
            } else {
                ForEach(viewModel.state.jobs.prefix(10)) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.type)
                            .font(.subheadline.weight(.semibold))
                        Text("\(job.state) · \(Int(job.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(LumenColors.muted)
                        if let message = job.message {
                            Text(message)
                                .font(.caption2)
                                .foregroundStyle(LumenColors.muted)
                        }
                    }
                }
            }
        }
        .listRowBackground(LumenColors.surface)
    }

    private func capLabel(_ kbps: Int) -> String {
        if kbps <= 0 { return "Unlimited" }
        if kbps >= 1000 {
            return String(format: "%.1f Mbps", Double(kbps) / 1000.0)
        }
        return "\(kbps) kbps"
    }

    private func formatCacheLimit(_ bytes: Int64) -> String {
        if bytes <= 0 { return "Unlimited" }
        let gib = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.0f GiB", gib)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 B" }
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 { return String(format: "%.2f GiB", gb) }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MiB", mb)
    }

    private func offlineStatusLabel(_ item: OfflineCachedItem) -> String {
        switch item.status {
        case .ready: return "Ready · \(formatBytes(max(item.bytesTotal, item.bytesDownloaded)))"
        case .queued: return "Queued"
        case .downloading: return "Downloading \(Int(item.progress * 100))%"
        case .failed: return item.errorMessage ?? "Failed"
        }
    }
}
