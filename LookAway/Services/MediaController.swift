import Foundation

/// Pauses and resumes "now playing" media (Spotify, Apple Music, Safari/Chrome video, etc.)
/// using Apple's private MediaRemote framework. Uses dedicated pause/play commands rather
/// than a play/pause toggle, so we never accidentally start playback that wasn't running.
@MainActor
final class MediaController {
    private typealias GetIsPlayingFunc = @convention(c) (DispatchQueue, @escaping @Sendable (Bool) -> Void) -> Void
    private typealias SendCommandFunc = @convention(c) (Int32, CFDictionary?) -> Bool

    // MRCommand values from MediaRemote.framework
    private static let kMRPlay: Int32 = 0
    private static let kMRPause: Int32 = 1

    private var getIsPlaying: GetIsPlayingFunc?
    private var sendCommand: SendCommandFunc?
    private var didPause = false

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY) else { return }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getIsPlaying = unsafeBitCast(sym, to: GetIsPlayingFunc.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: SendCommandFunc.self)
        }
    }

    func pauseIfPlaying() {
        guard let getIsPlaying else { return }
        getIsPlaying(.main) { [weak self] isPlaying in
            guard isPlaying else { return }
            Task { @MainActor in
                guard let self, let send = self.sendCommand else { return }
                if send(Self.kMRPause, nil) {
                    self.didPause = true
                }
            }
        }
    }

    func resumeIfPaused() {
        guard didPause, let sendCommand else { return }
        didPause = false
        _ = sendCommand(Self.kMRPlay, nil)
    }
}
