import SwiftUI
import SwiftData

@main
struct VoiceFlowApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .tint(Theme.Palette.accent)
        }
        .modelContainer(for: [VoiceNote.self, CommandRecord.self])
    }
}
