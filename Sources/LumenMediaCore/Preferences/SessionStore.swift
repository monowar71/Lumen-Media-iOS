import Foundation
import Security

public struct AuthSession: Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var userId: String
    public var username: String
    public var role: String

    public init(
        accessToken: String,
        refreshToken: String,
        userId: String,
        username: String,
        role: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.username = username
        self.role = role
    }
}

/// Session + remembered credentials.
/// Prefers Keychain; falls back to UserDefaults when Keychain is unavailable
/// (unsigned Simulator builds often fail SecItemAdd silently).
public final class SessionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _accessToken: String?
    private var _refreshToken: String?
    private var _userId: String?
    private var _username: String?
    private var _role: String?

    private let service = "com.lumenmedia.ios"
    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"
    private let userIdKey = "userId"
    private let usernameKey = "username"
    private let roleKey = "role"
    private let savedUserKey = "savedUsername"
    private let savedPassKey = "savedPassword"
    private let rememberKey = "lumen.rememberCredentials"
    private let deviceIdKey = "lumen.deviceId"
    private let defaultsFallbackPrefix = "lumen.secure."

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _accessToken = readSecret(accessKey)
        _refreshToken = readSecret(refreshKey)
        _userId = readSecret(userIdKey)
        _username = readSecret(usernameKey)
        _role = readSecret(roleKey)
    }

    public var accessToken: String? {
        lock.lock(); defer { lock.unlock() }
        return _accessToken
    }

    public var refreshToken: String? {
        lock.lock(); defer { lock.unlock() }
        return _refreshToken
    }

    public var currentSession: AuthSession? {
        lock.lock(); defer { lock.unlock() }
        guard let access = _accessToken, let refresh = _refreshToken,
              let userId = _userId, let username = _username, let role = _role
        else { return nil }
        return AuthSession(
            accessToken: access,
            refreshToken: refresh,
            userId: userId,
            username: username,
            role: role
        )
    }

    public func saveSession(_ session: AuthSession) {
        lock.lock()
        _accessToken = session.accessToken
        _refreshToken = session.refreshToken
        _userId = session.userId
        _username = session.username
        _role = session.role
        lock.unlock()
        writeSecret(accessKey, session.accessToken)
        writeSecret(refreshKey, session.refreshToken)
        writeSecret(userIdKey, session.userId)
        writeSecret(usernameKey, session.username)
        writeSecret(roleKey, session.role)
    }

    public func updateTokens(access: String, refresh: String) {
        lock.lock()
        _accessToken = access
        _refreshToken = refresh
        lock.unlock()
        writeSecret(accessKey, access)
        writeSecret(refreshKey, refresh)
    }

    public func clearSession() {
        lock.lock()
        _accessToken = nil
        _refreshToken = nil
        _userId = nil
        _username = nil
        _role = nil
        lock.unlock()
        deleteSecret(accessKey)
        deleteSecret(refreshKey)
        deleteSecret(userIdKey)
        deleteSecret(usernameKey)
        deleteSecret(roleKey)
    }

    public func clear() {
        clearSession()
    }

    public func saveCredentials(username: String, password: String) {
        writeSecret(savedUserKey, username)
        writeSecret(savedPassKey, password)
        setRememberCredentials(true)
    }

    public func clearSavedCredentials() {
        deleteSecret(savedUserKey)
        deleteSecret(savedPassKey)
    }

    public func readSavedCredentials() -> (username: String, password: String)? {
        guard let u = readSecret(savedUserKey), let p = readSecret(savedPassKey),
              !u.isEmpty, !p.isEmpty
        else { return nil }
        return (u, p)
    }

    /// Defaults to `true` when the preference has never been set.
    public var rememberCredentials: Bool {
        if defaults.object(forKey: rememberKey) == nil {
            return true
        }
        return defaults.bool(forKey: rememberKey)
    }

    public func setRememberCredentials(_ value: Bool) {
        defaults.set(value, forKey: rememberKey)
    }

    public var deviceId: String {
        if let existing = defaults.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: deviceIdKey)
        return id
    }

    // MARK: - Secret storage (Keychain → UserDefaults fallback)

    private func writeSecret(_ account: String, _ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecSuccess {
            defaults.removeObject(forKey: defaultsFallbackPrefix + account)
            return
        }
        // Unsigned Simulator / missing keychain entitlement — keep values durable via defaults.
        defaults.set(value, forKey: defaultsFallbackPrefix + account)
    }

    private func readSecret(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let value = String(data: data, encoding: .utf8), !value.isEmpty
        {
            return value
        }
        return defaults.string(forKey: defaultsFallbackPrefix + account)
    }

    private func deleteSecret(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        defaults.removeObject(forKey: defaultsFallbackPrefix + account)
    }
}
