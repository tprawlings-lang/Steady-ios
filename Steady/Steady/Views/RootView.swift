import SwiftUI
import SwiftData

/// Root: if a server is configured but no one is signed in, show login;
/// otherwise gate on onboarding, then a four-tab layout.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context

    var body: some View {
        if backend.isConfigured && !backend.isAuthenticated {
            LoginView()
        } else if backend.isAuthenticated {
            // Signed in to the shared account: the server decides what's next.
            if let gating = backend.gating {
                if gating.nextStep == "ready" {
                    mainTabs
                } else {
                    PipelineView()
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ScreenBackground())
                    .task { try? await backend.loadMe() }
            }
        } else if app.hasOnboarded {
            mainTabs
        } else {
            OnboardingView()
        }
    }

    private var mainTabs: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            CheckinView()
                .tabItem { Label("Check-in", systemImage: "checkmark.circle.fill") }
            CompanionView()
                .tabItem { Label("Companion", systemImage: "bubble.left.and.bubble.right.fill") }
            GroundingView()
                .tabItem { Label("Ground", systemImage: "leaf.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.sageDeep)
        .task(id: backend.isAuthenticated) {
            if backend.isAuthenticated {
                // Honor the fitness screener's seizure soft-flag as an audio-only default.
                if backend.gating?.seizureFlag == true { app.audioOnlyDefault = true }
                await SyncEngine.sync(backend, context: context)
            }
        }
    }
}

/// Preferences + a discreet always-available crisis entry.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @State private var showCrisis = false
    @State private var showVoice = false
    @State private var syncing = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                Form {
                    accountSection
                    Section("You") {
                        TextField("Name", text: Binding(get: { app.name }, set: { app.name = $0 }))
                        TextField("Calm-place word", text: Binding(get: { app.calmPlace }, set: { app.calmPlace = $0 }))
                    }
                    Section("Sessions") {
                        Toggle("Audio-only bilateral stimulation", isOn: Binding(get: { app.audioOnlyDefault }, set: { app.audioOnlyDefault = $0 }))
                        Toggle("Haptic taps (left/right)", isOn: Binding(get: { app.hapticsEnabled }, set: { app.hapticsEnabled = $0 }))
                        if backend.isAuthenticated {
                            Button { showVoice = true } label: {
                                HStack {
                                    Label("Hands-free voice", systemImage: "mic.fill").foregroundStyle(Color.ground)
                                    Spacer()
                                    Text(backend.gating?.liveVoiceAvailable == true ? "On" : "Off")
                                        .font(.caption).foregroundStyle(Color.olive)
                                }
                            }
                        }
                    }
                    Section("Specialist review (demo)") {
                        Text("In production, higher-intensity modules unlock only after a licensed specialist reviews your progress. For this preview you can simulate that here.")
                            .font(.caption).foregroundStyle(Color.olive)
                        Toggle("Unlock specialist-gated modules", isOn: Binding(
                            get: { !app.unlockedGatedIds.isEmpty },
                            set: { on in
                                app.unlockedGatedIds = on
                                    ? Set(ModuleCatalog.all.filter { $0.tier == .gated }.map { $0.id })
                                    : []
                            }))
                    }
                    Section {
                        Button {
                            showCrisis = true
                        } label: {
                            Label("Need help now?", systemImage: "phone.fill").foregroundStyle(Color.support)
                        }
                    }
                    Section {
                        Text("Steady is a self-guided wellness program built on the EMDR method. Not therapy, not medical care, not for emergencies.")
                            .font(.caption2).foregroundStyle(Color.olive)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showCrisis) { NavigationStack { CrisisView() } }
            .sheet(isPresented: $showVoice) { VoiceConsentView() }
        }
    }

    @ViewBuilder private var accountSection: some View {
        Section("Account & sync") {
            if backend.isAuthenticated, let user = backend.currentUser {
                LabeledContent("Signed in", value: user.email)
                Button {
                    syncing = true
                    Task { @MainActor in await SyncEngine.sync(backend, context: context); syncing = false }
                } label: {
                    Label(syncing ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath")
                }.disabled(syncing)
                Button(role: .destructive) { backend.logout() } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Text("Sign in to sync your check-ins, sessions, and progress with the Steady website.")
                    .font(.caption).foregroundStyle(Color.olive)
                TextField("Server URL (https://…)", text: Binding(
                    get: { backend.baseURLString }, set: { backend.baseURLString = $0 }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                if backend.isConfigured {
                    Text("Reopen the app or pull to sign in.").font(.caption).foregroundStyle(Color.olive)
                }
            }
        }
    }
}
