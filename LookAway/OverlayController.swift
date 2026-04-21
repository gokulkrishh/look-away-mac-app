import AppKit
import SwiftUI

enum OverlayAction {
    case skip
    case snooze
}

@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []

    func show(durationSeconds: TimeInterval, onAction: @escaping (OverlayAction) -> Void) {
        hide()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.animationBehavior = .none

            let view = BreakOverlayView(duration: durationSeconds) { action in
                onAction(action)
            }
            let hosting = NSHostingView(rootView: view)
            hosting.frame = screen.frame
            window.contentView = hosting

            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    func hide() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
    }
}
