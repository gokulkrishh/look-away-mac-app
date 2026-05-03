import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var mediaPermissionTrusted: Bool = false

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

            Section("Sound") {
                Toggle("Break end sound", isOn: $state.breakEndSoundEnabled)
                Text("Plays a chime when your break is over so you know it's time to get back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Media") {
                Toggle("Pause media during breaks", isOn: $state.pauseMediaDuringBreak)
                Text("Sends the macOS Play/Pause key when a break starts. Works with Spotify, Apple Music, and video in Safari, Chrome, and Firefox. You'll need to resume manually after the break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if state.pauseMediaDuringBreak && !mediaPermissionTrusted {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("LookAway needs Accessibility permission to send the media key.")
                            .font(.caption)
                        Spacer()
                        Button("Open Settings") { state.media.openAccessibilitySettings() }
                            .controlSize(.small)
                    }
                }
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
        .frame(width: 420, height: 460)
        .onChange(of: state.workIntervalMinutes) { _, _ in state.syncSchedulerSettings() }
        .onChange(of: state.breakSecondsDuration) { _, _ in state.syncSchedulerSettings() }
        .onChange(of: state.idlePauseSeconds) { _, _ in state.syncSchedulerSettings() }
        .onChange(of: state.breakEndSoundEnabled) { _, _ in state.syncSchedulerSettings() }
        .onChange(of: state.pauseMediaDuringBreak) { _, isOn in
            if isOn { state.media.requestAccessibilityIfNeeded() }
            mediaPermissionTrusted = state.media.isAccessibilityTrusted
        }
        .onAppear { mediaPermissionTrusted = state.media.isAccessibilityTrusted }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            mediaPermissionTrusted = state.media.isAccessibilityTrusted
        }
    }
}
