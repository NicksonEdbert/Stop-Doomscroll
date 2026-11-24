import SwiftUI
import DoomCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "hourglass") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(item: $model.route) { route in
            switch route {
            case .pause(let app):
                PauseView(app: app)
            case .blocked(let app):
                BlockedView(app: app)
            }
        }
        .alert(
            "Open it yourself",
            isPresented: Binding(
                get: { model.openFailedFor != nil },
                set: { if !$0 { model.openFailedFor = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text("Couldn't jump straight to \(model.openFailedFor?.displayName ?? "the app"). Your session has started, so open it from your Home Screen.")
        }
        .onChange(of: scenePhase) { _, phase in
            model.scenePhaseChanged(phase)
        }
    }
}
