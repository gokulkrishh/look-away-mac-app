import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @AppStorage("workIntervalMinutes") var workIntervalMinutes: Int = 20
    @AppStorage("breakSecondsDuration") var breakSecondsDuration: Int = 20
    @AppStorage("idlePauseSeconds") var idlePauseSeconds: Int = 120
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    let scheduler = BreakScheduler()
    let overlay = OverlayController()

    private var bag = Set<AnyCancellable>()

    init() {
        syncSchedulerSettings()

        scheduler.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        scheduler.onBreakStart = { [weak self] in
            guard let self else { return }
            self.overlay.show(durationSeconds: self.scheduler.breakDuration) { action in
                switch action {
                case .skip: self.scheduler.skipBreak()
                case .snooze: self.scheduler.snoozeBreak(minutes: 5)
                }
            }
        }
        scheduler.onBreakEnd = { [weak self] in
            self?.overlay.hide()
        }

        scheduler.start()
    }

    func syncSchedulerSettings() {
        scheduler.workInterval = TimeInterval(max(1, workIntervalMinutes) * 60)
        scheduler.breakDuration = TimeInterval(max(5, breakSecondsDuration))
        scheduler.idlePauseThreshold = TimeInterval(max(30, idlePauseSeconds))
    }

    var nextBreakText: String {
        let remaining = max(0, Int(scheduler.workInterval - scheduler.activeSeconds))
        let m = remaining / 60
        let s = remaining % 60
        if m > 0 && s > 0 { return "\(m)m \(s)s" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}
