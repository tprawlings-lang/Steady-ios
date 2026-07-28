import SwiftUI

/// Sign-in against the shared Steady backend. Reached when a server is
/// configured but no one is signed in. The member can also choose to keep
/// using the app on-device only.
struct LoginView: View {
    @Environment(Backend.self) private var backend
    @Environment(AppState.self) private var app

    @State private var email = ""
    @State private var password = ""
    @State private var server = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showSignup = false

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer().frame(height: 20)
                    Image(systemName: "leaf.fill").font(.system(size: 40)).foregroundStyle(Color.sageDeep)
                    Text("Sign in to Steady").serifTitle(30)
                    Text("Use the same account as the website. Your check-ins, sessions, and progress will sync between your devices.")
                        .font(.subheadline).foregroundStyle(Color.olive)

                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            labeled("Server URL") {
                                TextField("https://your-steady.example.com", text: $server)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .keyboardType(.URL).textFieldStyle(.roundedBorder)
                            }
                            labeled("Email") {
                                TextField("you@example.com", text: $email)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .keyboardType(.emailAddress).textFieldStyle(.roundedBorder)
                            }
                            labeled("Password") {
                                SecureField("Your password", text: $password).textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    if let error {
                        Text(error).font(.subheadline).foregroundStyle(Color.support)
                    }

                    PrimaryButton(title: busy ? "Signing in…" : "Sign in") { Task { await signIn() } }
                        .disabled(busy)

                    OutlineButton(title: "Create a new account") { showSignup = true }

                    OutlineButton(title: "Continue on this device only") {
                        // Clear the server so the app runs standalone (original mode).
                        backend.baseURLString = ""
                    }
                    Text("On-device mode keeps everything local to this phone — nothing syncs. You can sign in later from Settings.")
                        .font(.caption).foregroundStyle(Color.olive)
                }
                .padding(24)
            }
        }
        .onAppear { server = backend.baseURLString }
        .sheet(isPresented: $showSignup) { SignupView() }
    }

    private func labeled<V: View>(_ label: String, @ViewBuilder _ field: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.ground)
            field()
        }
    }

    private func signIn() async {
        error = nil
        let url = server.trimmingCharacters(in: .whitespaces)
        guard URL(string: url)?.scheme != nil else { error = "Enter a valid server URL (including https://)."; return }
        backend.baseURLString = url
        busy = true
        defer { busy = false }
        do {
            try await backend.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
            if app.name.isEmpty, let name = backend.currentUser?.name { app.name = name }
            app.hasOnboarded = true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign in failed. Check your details and server URL."
        }
    }
}
