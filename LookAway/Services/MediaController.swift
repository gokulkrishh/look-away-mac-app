import AppKit
import ApplicationServices

/// Pauses "now playing" media (Spotify, Apple Music, video in Safari/Chrome/Firefox, etc.)
/// by posting the system Play/Pause key event — the same event Apple keyboards send on F8.
/// Requires Accessibility permission; until granted, the post is a silent no-op.
@MainActor
final class MediaController {
    // NX_KEYTYPE_PLAY from <IOKit/hidsystem/ev_keymap.h>
    private static let mediaKeyPlayPause: UInt32 = 16

    /// Sends one Play/Pause key press. The hardware key is a toggle, so this pauses what's
    /// playing — but if nothing is playing, the system may launch the default media app
    /// (typically Music). That's a known macOS behavior we can't suppress without private APIs.
    func pauseMedia() {
        postMediaKey(down: true)
        postMediaKey(down: false)
    }

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Triggers the system Accessibility prompt the first time it's called for this app.
    @discardableResult
    func requestAccessibilityIfNeeded() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func postMediaKey(down: Bool) {
        let phase: Int = down ? 0xA : 0xB
        let data1 = Int((Self.mediaKeyPlayPause << 16) | UInt32(phase << 8))
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
