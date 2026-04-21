import Foundation

@MainActor
final class BreakScheduler: ObservableObject {
    enum Phase {
        case working
        case breaking
        case pausedManual(until: Date?)
    }

    @Published private(set) var phase: Phase = .working
    @Published private(set) var activeSeconds: TimeInterval = 0
    @Published private(set) var breakRemaining: TimeInterval = 0

    var workInterval: TimeInterval = 20 * 60
    var breakDuration: TimeInterval = 20
    var activeThreshold: TimeInterval = 15
    var idlePauseThreshold: TimeInterval = 120
    var idleResetThreshold: TimeInterval = 300

    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?

    private var timer: Timer?

    func start() {
        stop()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func triggerBreakNow() {
        startBreak()
    }

    func skipBreak() {
        endBreak(resetAccumulator: true)
    }

    func snoozeBreak(minutes: Int) {
        endBreak(resetAccumulator: true)
        activeSeconds = max(0, workInterval - TimeInterval(minutes * 60))
    }

    func pauseForHour() {
        phase = .pausedManual(until: Date().addingTimeInterval(3600))
    }

    func resume() {
        phase = .working
    }

    private func tick() {
        switch phase {
        case .pausedManual(let until):
            if let until, Date() >= until { phase = .working }
            return
        case .breaking:
            breakRemaining -= 1
            if breakRemaining <= 0 { endBreak(resetAccumulator: true) }
            return
        case .working:
            break
        }

        let idle = IdleMonitor.secondsSinceLastInput()

        if idle >= idleResetThreshold {
            activeSeconds = 0
            return
        }
        if idle >= idlePauseThreshold {
            return
        }
        if idle < activeThreshold {
            activeSeconds += 1
            if activeSeconds >= workInterval {
                startBreak()
            }
        }
    }

    private func startBreak() {
        breakRemaining = breakDuration
        phase = .breaking
        onBreakStart?()
    }

    private func endBreak(resetAccumulator: Bool) {
        if resetAccumulator { activeSeconds = 0 }
        breakRemaining = 0
        phase = .working
        onBreakEnd?()
    }
}
