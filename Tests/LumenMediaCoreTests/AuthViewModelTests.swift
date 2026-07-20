import XCTest
@testable import LumenMediaCore

@MainActor
final class AuthViewModelTests: XCTestCase {
    private var api: MockLumenMediaAPI!
    private var sessionStore: SessionStore!
    private var settingsStore: SettingsStore!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        api = MockLumenMediaAPI()
        sessionStore = SessionStore()
        sessionStore.clear()
        sessionStore.clearSavedCredentials()
        suiteName = "test.lumen.auth.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.setBaseUrl("http://192.168.0.2:8096")
        api.serverInfoResult = .success(ServerInfo(setupCompleted: true))
    }

    override func tearDown() async throws {
        sessionStore.clear()
        sessionStore.clearSavedCredentials()
        defaults.removePersistentDomain(forName: suiteName)
        api = nil
        sessionStore = nil
        settingsStore = nil
        defaults = nil
        suiteName = nil
    }

    func testLoginSuccess_savesSessionAndAuthenticates() async {
        api.loginResult = .success(
            TokenResponse(
                accessToken: "access",
                refreshToken: "refresh",
                expiresInSec: 3600,
                tokenType: "Bearer",
                user: UserDto(id: "u1", username: "admin", role: "Admin")
            )
        )

        let vm = AuthViewModel(api: api, sessionStore: sessionStore, settingsStore: settingsStore)
        vm.onUsernameChange("admin")
        vm.onPasswordChange("secret")
        vm.onRememberCredentialsChange(false)
        await vm.submit()

        XCTAssertEqual(vm.state.status, .authenticated)
        XCTAssertEqual(vm.state.displayName, "admin")
        XCTAssertEqual(vm.state.role, "Admin")
        XCTAssertNil(vm.state.error)
        XCTAssertNotNil(sessionStore.currentSession)
        XCTAssertEqual(sessionStore.currentSession?.accessToken, "access")
        XCTAssertNil(sessionStore.readSavedCredentials())
    }

    func testSetupPath_callsSetupThenLogin() async {
        api.serverInfoResult = .success(ServerInfo(setupCompleted: false))
        api.loginResult = .success(
            TokenResponse(
                accessToken: "a",
                refreshToken: "r",
                user: UserDto(id: "u1", username: "owner", role: "Admin")
            )
        )

        let vm = AuthViewModel(api: api, sessionStore: sessionStore, settingsStore: settingsStore)
        await vm.refreshServerInfo()
        XCTAssertEqual(vm.state.needsSetup, true)

        vm.onUsernameChange("owner")
        vm.onPasswordChange("pass")
        vm.onServerNameChange("MyServer")
        await vm.submit()

        XCTAssertTrue(api.setupCalled)
        XCTAssertEqual(vm.state.status, .authenticated)
        XCTAssertEqual(vm.state.needsSetup, false)
        XCTAssertEqual(vm.state.displayName, "owner")
    }

    func testValidationError_requiresUsernameAndPassword() async {
        let vm = AuthViewModel(api: api, sessionStore: sessionStore, settingsStore: settingsStore)
        vm.onUsernameChange("  ")
        vm.onPasswordChange("")
        await vm.submit()

        XCTAssertEqual(vm.state.error, "Username and password are required")
        XCTAssertNotEqual(vm.state.status, .authenticated)
        XCTAssertNil(sessionStore.currentSession)
        XCTAssertFalse(api.setupCalled)
    }

    func testLogout_clearsSessionAndReturnsAnonymous() async {
        sessionStore.saveSession(
            AuthSession(
                accessToken: "a",
                refreshToken: "r",
                userId: "u1",
                username: "admin",
                role: "Admin"
            )
        )
        sessionStore.saveCredentials(username: "admin", password: "secret")

        let vm = AuthViewModel(api: api, sessionStore: sessionStore, settingsStore: settingsStore)
        await vm.logout()

        XCTAssertEqual(vm.state.status, .anonymous)
        XCTAssertNil(vm.state.displayName)
        XCTAssertNil(vm.state.role)
        XCTAssertNil(sessionStore.currentSession)
        XCTAssertEqual(vm.state.username, "admin")
        XCTAssertEqual(vm.state.password, "secret")
    }

    func testRememberCredentials_defaultsOnAndPersistsAcrossLogin() async {
        api.loginResult = .success(
            TokenResponse(
                accessToken: "access",
                refreshToken: "refresh",
                user: UserDto(id: "u1", username: "admin", role: "Admin")
            )
        )

        let vm = AuthViewModel(api: api, sessionStore: sessionStore, settingsStore: settingsStore)
        XCTAssertTrue(vm.state.rememberCredentials, "Remember should default to on")

        vm.onUsernameChange("admin")
        vm.onPasswordChange("secret")
        await vm.submit()

        XCTAssertEqual(vm.state.status, .authenticated)
        let saved = sessionStore.readSavedCredentials()
        XCTAssertEqual(saved?.username, "admin")
        XCTAssertEqual(saved?.password, "secret")

        // Simulate cold start of a new AuthViewModel
        let restored = AuthViewModel(api: api, sessionStore: SessionStore(), settingsStore: settingsStore)
        XCTAssertEqual(restored.state.username, "admin")
        XCTAssertEqual(restored.state.password, "secret")
        XCTAssertTrue(restored.state.rememberCredentials)
    }
}
