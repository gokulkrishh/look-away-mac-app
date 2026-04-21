import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section("Timing") {
                Stepper(value: $state.workIntervalMinutes, in: 1...120) {
                    LabeledContent("Work interval", value: "\(state.workIntervalMinutes) min")
                }
                Stepper(value: $state.breakSecondsDuration, in: 5...600, step: 5) {
                    LabeledContent("Break duration", value: "\(state.breakSecondsDuration) sec")
                }
            }

            Section("Idle") {
                Stepper(value: $state.idlePauseSeconds, in: 30...600, step: 30) {
                    LabeledContent("Pause after idle", value: "\(state.idlePauseSeconds) sec")
                }
                Text("Timer pauses when you're away from the keyboard, so breaks reflect real screen time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { newValue in
                        state.launchAtLogin = newValue
                        LaunchAtLogin.set(enabled: newValue)
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
        .onChange(of: state.workIntervalMinutes) { _, _ in state.syncSchedulerSettings() }
        .onChange(of: state.breakSecondsDuration) { _, _ in state.syncSchedulerSettings() }
        .onChange(of: state.idlePauseSeconds) { _, _ in state.syncSchedulerSettings() }
    }
}
