import SwiftUI

@main
struct LookAwayApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(state)
        } label: {
            Label("LookAway", systemImage: iconName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(state)
        }
    }

    private var iconName: String {
        switch state.scheduler.phase {
        case .breaking: return "eye.fill"
        default: return "eye"
        }
    }
}
