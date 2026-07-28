import SwiftUI
import SwiftData

@main
struct SteadyApp: App {
    @State private var app = AppState()
    @State private var backend = Backend()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(backend)
                .tint(Color.sageDeep)
                .task { await backend.restore() }
        }
        .modelContainer(for: [SessionRecord.self, CheckinRecord.self])
    }
}
