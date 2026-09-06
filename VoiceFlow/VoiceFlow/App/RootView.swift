import SwiftUI

/// Root navigation: Home with tabs to History; the capture flow is a full-screen cover.
struct RootView: View {
    @Environment(AppServices.self) private var services
    @State private var showingCapture = false

    var body: some View {
        TabView {
            HomeView(onStartCapture: { showingCapture = true })
                .tabItem { Label("Сегодня", systemImage: "mic.fill") }

            HistoryView()
                .tabItem { Label("История", systemImage: "clock") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: $showingCapture) {
            CaptureFlowView()
        }
    }
}
