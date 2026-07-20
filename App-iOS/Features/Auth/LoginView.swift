import SwiftUI
import UIKit
import LumenMediaCore

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LumenColors.bg, LumenColors.surface, LumenColors.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    brandHeader
                    formCard
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            LumenBrandMark(size: 64)
                .shadow(color: LumenColors.accent.opacity(0.35), radius: 20, y: 8)

            Text("LumenMedia")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(LumenColors.text)

            Text(
                auth.state.needsSetup == true
                    ? "Create the first admin account"
                    : "Sign in to your media server"
            )
            .font(.subheadline)
            .foregroundStyle(LumenColors.muted)
            .multilineTextAlignment(.center)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(
                title: "Server address",
                text: Binding(
                    get: { auth.state.baseUrl },
                    set: { auth.onBaseUrlChange($0) }
                ),
                placeholder: "http://192.168.0.2:8096",
                keyboard: .URL,
                autocapitalization: .never,
                accessibilityId: "login.server"
            )
            .onSubmit {
                Task { await auth.refreshServerInfo() }
            }
            .onChange(of: auth.state.baseUrl) { _, _ in
                Task { await auth.refreshServerInfo() }
            }

            if auth.state.needsSetup == true {
                field(
                    title: "Server name",
                    text: Binding(
                        get: { auth.state.serverName },
                        set: { auth.onServerNameChange($0) }
                    ),
                    placeholder: "LumenMedia"
                )
            }

            field(
                title: "Username",
                text: Binding(
                    get: { auth.state.username },
                    set: { auth.onUsernameChange($0) }
                ),
                placeholder: "Username",
                autocapitalization: .never,
                accessibilityId: "login.username"
            )

            SecureField("Password", text: Binding(
                get: { auth.state.password },
                set: { auth.onPasswordChange($0) }
            ))
            .accessibilityIdentifier("login.password")
            .textContentType(.password)
            .padding(14)
            .background(LumenColors.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LumenColors.border, lineWidth: 1)
            )
            .foregroundStyle(LumenColors.text)

            Toggle(
                "Remember credentials",
                isOn: Binding(
                    get: { auth.state.rememberCredentials },
                    set: { auth.onRememberCredentialsChange($0) }
                )
            )
            .tint(LumenColors.accent)
            .foregroundStyle(LumenColors.text)

            if let error = auth.state.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await auth.submit() }
            } label: {
                HStack {
                    if auth.state.submitting {
                        ProgressView()
                            .tint(LumenColors.onAccent)
                    }
                    Text(auth.state.needsSetup == true ? "Set up & sign in" : "Sign in")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LumenColors.accent)
                .foregroundStyle(LumenColors.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityIdentifier("login.submit")
            .disabled(auth.state.submitting)
        }
        .padding(20)
        .background(LumenColors.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LumenColors.border, lineWidth: 1)
        )
    }

    private func field(
        title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences,
        accessibilityId: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LumenColors.muted)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .padding(14)
                .background(LumenColors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(LumenColors.border, lineWidth: 1)
                )
                .foregroundStyle(LumenColors.text)
                .accessibilityIdentifier(accessibilityId ?? title)
        }
    }
}
