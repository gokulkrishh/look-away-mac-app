import SwiftUI
import AppKit

struct MenuBarContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openSettings) private var openSettings

    private func dismissMenuBar() {
        for window in NSApp.windows {
            let name = String(describing: type(of: window))
            if name.contains("MenuBarExtra") || name.contains("NSStatusBar") {
                window.orderOut(nil)
                return
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Next break in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(countdownText)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 6)

            Divider().padding(.vertical, 4)

            Button {
                dismissMenuBar()
                state.scheduler.triggerBreakNow()
            } label: {
                MenuRow(title: "Take a break now", systemImage: "eye.fill")
            }

            Button {
                dismissMenuBar()
                switch state.scheduler.phase {
                case .pausedManual: state.scheduler.resume()
                default: state.scheduler.pauseForHour()
                }
            } label: {
                MenuRow(title: pauseLabel, systemImage: pauseIcon)
            }

            Divider().padding(.vertical, 4)

            Button {
                dismissMenuBar()
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                MenuRow(title: "Settings…", systemImage: "gearshape")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                MenuRow(title: "Quit LookAway", systemImage: "power")
            }
        }
        .buttonStyle(MenuRowButtonStyle())
        .focusEffectDisabled()
        .padding(6)
        .frame(width: 260)
    }

    private var countdownText: String {
        switch state.scheduler.phase {
        case .breaking: return "On break"
        case .pausedManual: return "Paused"
        case .working: return state.nextBreakText
        }
    }

    private var pauseLabel: String {
        if case .pausedManual = state.scheduler.phase { return "Resume" }
        return "Pause for 1 hour"
    }

    private var pauseIcon: String {
        if case .pausedManual = state.scheduler.phase { return "play.fill" }
        return "pause.fill"
    }
}

private struct MenuRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18, alignment: .center)
            Text(title)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(background(pressed: configuration.isPressed))
            )
            .onHover { hovering = $0 }
    }

    private func background(pressed: Bool) -> Color {
        if pressed { return Color.accentColor.opacity(0.35) }
        if hovering { return Color.primary.opacity(0.12) }
        return .clear
    }
}
