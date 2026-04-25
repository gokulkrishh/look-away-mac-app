import Foundation
import AVFoundation

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
    var breakEndSoundEnabled: Bool = true

    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?

    private var timer: Timer?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioReady = false

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
        endBreak(resetAccumulator: true, playSound: false)
    }

    func snoozeBreak(minutes: Int) {
        endBreak(resetAccumulator: true, playSound: false)
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
            if breakRemaining <= 0 { endBreak(resetAccumulator: true, playSound: true) }
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

    private func endBreak(resetAccumulator: Bool, playSound: Bool) {
        if resetAccumulator { activeSeconds = 0 }
        breakRemaining = 0
        phase = .working
        if playSound && breakEndSoundEnabled { playBreakEndSound() }
        onBreakEnd?()
    }

    // C major arpeggio: C5 → E5 → G5 → C6, layered into one buffer
    private func playBreakEndSound() {
        let sampleRate = 44100.0
        let noteSpacing = 0.13 // seconds between each note onset
        let noteDuration = 0.9 // each note's envelope window
        let totalDuration = noteSpacing * 3 + noteDuration

        // (delay, frequency, decayRate) — last note sustains longer for drama
        let notes: [(delay: Double, freq: Double, decay: Double)] = [
            (0.0,              523.25, 7.0),  // C5
            (noteSpacing,      659.25, 6.5),  // E5
            (noteSpacing * 2,  783.99, 6.0),  // G5
            (noteSpacing * 3, 1046.50, 4.5),  // C6 — slowest decay, rings out
        ]

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) { samples[i] = 0 }

        for note in notes {
            let start = Int(note.delay * sampleRate)
            let noteFrames = Int(noteDuration * sampleRate)
            for i in 0..<noteFrames {
                let idx = start + i
                guard idx < Int(frameCount) else { break }
                let t = Double(i) / sampleRate
                let attack = min(1.0, t / 0.005)           // 5ms attack, no click
                let decay = exp(-note.decay * t)            // exponential bell-like decay
                let envelope = Float(attack * decay)
                // fundamental + 2nd harmonic for warmth
                let wave = sin(2 * .pi * note.freq * t) + 0.18 * sin(4 * .pi * note.freq * t)
                samples[idx] += Float(wave) * envelope * 0.3
            }
        }

        if !audioReady {
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
            try? audioEngine.start()
            audioReady = true
        }
        playerNode.scheduleBuffer(buffer)
        if !playerNode.isPlaying { playerNode.play() }
    }
}
