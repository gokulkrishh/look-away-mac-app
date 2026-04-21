import SwiftUI

struct BreakOverlayView: View {
    let duration: TimeInterval
    let onAction: (OverlayAction) -> Void

    @State private var remaining: TimeInterval
    @State private var startedAt: Date = .now

    init(duration: TimeInterval, onAction: @escaping (OverlayAction) -> Void) {
        self.duration = duration
        self.onAction = onAction
        self._remaining = State(initialValue: duration)
    }

    private var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / duration))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            GlassEffectContainer {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 10)
                            .frame(width: 180, height: 180)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 180, height: 180)
                            .animation(.linear(duration: 0.5), value: progress)
                        Text("\(Int(ceil(remaining)))")
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Look away")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Rest your eyes until the ring completes.")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack(spacing: 12) {
                        Button("Snooze 5 min") { onAction(.snooze) }
                            .buttonStyle(.glass)
                            .controlSize(.large)
                        Button("Skip") { onAction(.skip) }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                    }
                }
                .padding(48)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
            }
            .frame(maxWidth: 420)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { now in
            let elapsed = now.timeIntervalSince(startedAt)
            remaining = max(0, duration - elapsed)
        }
    }
}
