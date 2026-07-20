import Foundation
import Combine

public enum AuthStatus: Equatable, Sendable {
    case restoring
    case authenticated
    case anonymous
}

public struct AuthUiState: Equatable, Sendable {
    public var status: AuthStatus = .restoring
    public var baseUrl: String = ""
    public var username: String = ""
    public var password: String = ""
    public var rememberCredentials: Bool = true
    public var serverName: String = "LumenMedia"
    public var needsSetup: Bool?
    public var submitting: Bool = false
    public var error: String?
    public var displayName: String?
    public var role: String?

    public init(
        status: AuthStatus = .restoring,
        baseUrl: String = "",
        username: String = "",
        password: String = "",
        rememberCredentials: Bool = true,
        serverName: String = "LumenMedia",
        needsSetup: Bool? = nil,
        submitting: Bool = false,
        error: String? = nil,
        displayName: String? = nil,
        role: String? = nil
    ) {
        self.status = status
        self.baseUrl = baseUrl
        self.username = username
        self.password = password
        self.rememberCredentials = rememberCredentials
        self.serverName = serverName
        self.needsSetup = needsSetup
        self.submitting = submitting
        self.error = error
        self.displayName = displayName
        self.role = role
    }
}

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public private(set) var state: AuthUiState

    private let api: any LumenMediaServing
    private let sessionStore: SessionStore
    private let settingsStore: SettingsStore

    public init(
        api: any LumenMediaServing,
        sessionStore: SessionStore,
        settingsStore: SettingsStore
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        var initial = AuthUiState(baseUrl: settingsStore.currentSettings.baseUrl)
        if let saved = sessionStore.readSavedCredentials() {
            initial.username = saved.username
            initial.password = saved.password
            initial.rememberCredentials = true
        } else {
            initial.rememberCredentials = sessionStore.rememberCredentials
        }
        self.state = initial
    }

    public func bootstrap() async {
        if let session = sessionStore.currentSession {
            state.status = .authenticated
            state.displayName = session.username
            state.role = session.role
            // Validate / refresh silently
            do {
                let user = try await api.me()
                state.displayName = user.username
                state.role = user.role
            } catch {
                // Try refresh path via a lightweight call; if it fails, fall anonymous.
                if sessionStore.refreshToken != nil {
                    do {
                        let user = try await api.me()
                        state.displayName = user.username
                        state.role = user.role
                    } catch {
                        sessionStore.clearSession()
                        state.status = .anonymous
                        state.displayName = nil
                        state.role = nil
                    }
                } else {
                    sessionStore.clearSession()
                    state.status = .anonymous
                }
            }
        } else {
            state.status = .anonymous
        }
        await refreshServerInfo()
    }

    public func onBaseUrlChange(_ value: String) {
        state.baseUrl = value
        state.error = nil
    }

    public func onUsernameChange(_ value: String) {
        state.username = value
        state.error = nil
    }

    public func onPasswordChange(_ value: String) {
        state.password = value
        state.error = nil
    }

    public func onServerNameChange(_ value: String) {
        state.serverName = value
    }

    public func onRememberCredentialsChange(_ value: Bool) {
        state.rememberCredentials = value
        sessionStore.setRememberCredentials(value)
        if !value {
            sessionStore.clearSavedCredentials()
        }
    }

    public func refreshServerInfo() async {
        settingsStore.setBaseUrl(state.baseUrl)
        do {
            let info = try await api.serverInfo()
            state.needsSetup = !info.setupCompleted
            state.error = nil
        } catch {
            state.needsSetup = nil
        }
    }

    public func submit() async {
        let current = state
        if current.username.trimmingCharacters(in: .whitespaces).isEmpty
            || current.password.isEmpty
        {
            state.error = "Username and password are required"
            return
        }
        state.submitting = true
        state.error = nil
        do {
            settingsStore.setBaseUrl(current.baseUrl)
            if current.needsSetup == true {
                _ = try await api.setup(
                    SetupRequest(
                        username: current.username,
                        password: current.password,
                        serverName: current.serverName.isEmpty ? "LumenMedia" : current.serverName
                    )
                )
            }
            let token = try await api.login(
                username: current.username,
                password: current.password,
                deviceId: sessionStore.deviceId,
                deviceName: deviceName()
            )
            let user: UserDto
            if let tokenUser = token.user {
                user = tokenUser
            } else {
                user = try await api.me()
            }
            sessionStore.saveSession(
                AuthSession(
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken,
                    userId: user.id,
                    username: user.username,
                    role: user.role
                )
            )
            if current.rememberCredentials {
                sessionStore.saveCredentials(username: current.username, password: current.password)
            } else {
                sessionStore.clearSavedCredentials()
                sessionStore.setRememberCredentials(false)
            }
            state.submitting = false
            state.status = .authenticated
            state.displayName = user.username
            state.role = user.role
            state.needsSetup = false
            if !current.rememberCredentials {
                state.password = ""
            }
        } catch {
            state.submitting = false
            state.error = error.lumenUserMessage(
                current.needsSetup == true ? "Setup failed" : "Login failed"
            )
        }
    }

    public func logout() async {
        await api.logout()
        sessionStore.clear()
        let saved = sessionStore.readSavedCredentials()
        state.status = .anonymous
        state.displayName = nil
        state.role = nil
        state.username = saved?.username ?? ""
        state.password = saved?.password ?? ""
        state.rememberCredentials = sessionStore.rememberCredentials || saved != nil
    }

    private func deviceName() -> String {
        #if os(iOS)
        return "LumenMedia iOS"
        #else
        return "LumenMedia"
        #endif
    }
}
