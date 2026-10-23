import AVFAudio
import Foundation
import Observation
import ShazamKit

@MainActor
@Observable
final class ShazamListener {
    enum Status: Equatable {
        case idle
        case listening
        case micDenied
        /// Kept verbatim so a ShazamKit setup problem (for example an App ID
        /// without the ShazamKit service) shows its real domain and code.
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var song: MatchedSong?
    /// Called on every match. `isNewSong` is false when Shazam heard the same
    /// song again, which still carries a fresher position in it.
    var onMatch: ((_ song: MatchedSong, _ isNewSong: Bool) -> Void)?

    private var session: SHManagedSession?
    private var listenTask: Task<Void, Never>?

    func start() async {
        guard status != .listening else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            status = .micDenied
            return
        }
        do {
            try configureAudioSession()
        } catch {
            status = .failed("Audio session: \(Self.describe(error))")
            return
        }

        let session = SHManagedSession()
        self.session = session
        status = .listening
        listenTask = Task { [weak self] in
            for await result in session.results {
                self?.handle(result)
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        session?.cancel()
        session = nil
        status = .idle
        song = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handle(_ result: SHSession.Result) {
        switch result {
        case .match(let match):
            guard let item = match.mediaItems.first else { return }
            let matched = MatchedSong(
                title: item.title ?? "Unknown title",
                artist: item.artist ?? "Unknown artist",
                isrc: item.isrc,
                artworkURL: item.artworkURL,
                offset: item.predictedCurrentMatchOffset,
                matchedAt: .now
            )
            let isNew = song.map { !matched.isSameSong(as: $0) } ?? true
            // A repeat match of the same song still refreshes the offset,
            // which corrects drift after a pause or a seek.
            song = matched
            onMatch?(matched, isNew)
        case .noMatch:
            break
        case .error(let error, _):
            status = .failed(Self.describe(error))
        }
    }

    private func configureAudioSession() throws {
        let audio = AVAudioSession.sharedInstance()
        // mixWithOthers keeps YouTube Music playing while we record.
        // defaultToSpeaker: playAndRecord otherwise moves all sound, YouTube
        // Music included, to the earpiece, which sounds muffled and quiet.
        try audio.setCategory(.playAndRecord, mode: .default,
                              options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        // Keep the hardware at the rate the music already plays at; a switch
        // can make other apps' audio glitch or sound slowed for a moment.
        try? audio.setPreferredSampleRate(audio.sampleRate)
        try audio.setActive(true)
        // With CarPlay connected, the input can switch to the car's hands-free
        // mic, whose echo cancellation removes the music. Force the iPhone mic.
        if let builtIn = audio.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try audio.setPreferredInput(builtIn)
        }
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        var text = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += "\nUnderlying: \(underlying.domain) \(underlying.code): \(underlying.localizedDescription)"
        }
        return text
    }
}
