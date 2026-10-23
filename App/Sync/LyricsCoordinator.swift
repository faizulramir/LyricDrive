import Foundation
import Observation

/// Ties the pieces together: Shazam match -> LRCLIB lookup -> line timing ->
/// Live Activity. The app screen reads the same state.
@MainActor
@Observable
final class LyricsCoordinator {
    enum LyricsState: Equatable {
        case none
        case loading
        case loaded(Lyrics)
        case failed(String)
    }

    let listener = ShazamListener()
    private(set) var lyricsState: LyricsState = .none
    private(set) var moment: LyricMoment?

    private let service = LyricsService()
    private let liveActivity = LiveActivityController()
    private var lookup: Task<Void, Never>?
    private var clock: Task<Void, Never>?
    private var activityQueue: Task<Void, Never>?

    init() {
        listener.onMatch = { [weak self] song, isNewSong in
            self?.handleMatch(song, isNewSong: isNewSong)
        }
    }

    var isListening: Bool { listener.status == .listening }
    private(set) var isDemoRunning = false
    var isRunning: Bool { isListening || isDemoRunning }
    private var demoSong: MatchedSong?
    /// The song on screen: Shazam's match, or the made-up one in the preview.
    var song: MatchedSong? { listener.song ?? demoSong }

    #if DEBUG
    /// Runs made-up lines through the real clock and Live Activity, so the
    /// Lock Screen, Dynamic Island and CarPlay views can be checked without
    /// music or Shazam.
    func startDemo() {
        let verse = [
            "Lines already sung drift up and fade,",
            "so your eyes stay on what is happening now.",
            "This is the line you are hearing right now.",
            "The next line waits below, a little quieter.",
            "Everything after it stays soft until its turn.",
        ]
        // Four rounds, about a minute: time to lock the phone and look.
        let lines = Array(repeating: verse, count: 4).joined().enumerated()
            .map { LyricLine(time: Double($0.offset) * 3 + 1, text: $0.element) }
        let song = MatchedSong(title: "Demo song", artist: "LyricDrive", isrc: nil, artworkURL: nil, offset: 0, matchedAt: .now)
        isDemoRunning = true
        demoSong = song
        lyricsState = .loaded(.synced(lines))
        enqueue { await $0.start(.init(phase: .findingLyrics, title: song.title, artist: song.artist)) }
        runClock(lines: lines, song: song)
    }
    #endif

    func start() async {
        await listener.start()
        // The listening session keeps the app alive in the background, which
        // is what lets it keep updating the Live Activity line by line.
        guard isListening else { return }
        enqueue { await $0.start(.listening) }
    }

    func stop() {
        listener.stop()
        isDemoRunning = false
        demoSong = nil
        lookup?.cancel()
        clock?.cancel()
        lyricsState = .none
        moment = nil
        enqueue { await $0.end() }
    }

    /// Looks the current song up again, after a failed lookup.
    func retryLyrics() {
        guard let song = listener.song else { return }
        loadLyrics(for: song)
    }

    /// For songs whose artist name LRCLIB spells differently: search by the
    /// cleaned title alone.
    func searchByTitleOnly() {
        guard let song = listener.song else { return }
        loadLyrics(for: song, titleOnly: true)
    }

    private func handleMatch(_ song: MatchedSong, isNewSong: Bool) {
        if isNewSong {
            loadLyrics(for: song)
        } else if case .loaded(.synced(let lines)) = lyricsState {
            // Same song heard again: restart the clock from the fresher
            // position, which corrects drift after a pause or a skip.
            runClock(lines: lines, song: song)
        }
    }

    private func loadLyrics(for song: MatchedSong, titleOnly: Bool = false) {
        lookup?.cancel()
        clock?.cancel()
        moment = nil
        lyricsState = .loading
        publish(.init(phase: .findingLyrics, title: song.title, artist: song.artist))

        lookup = Task {
            let lyrics: Lyrics
            do {
                lyrics = try await service.lyrics(title: song.title, artist: song.artist, titleOnly: titleOnly)
            } catch {
                guard !Task.isCancelled else { return }
                lyricsState = .failed(error.localizedDescription)
                publish(.init(phase: .notFound, title: song.title, artist: song.artist))
                return
            }
            guard !Task.isCancelled else { return }
            lyricsState = .loaded(lyrics)
            switch lyrics {
            case .synced(let lines):
                runClock(lines: lines, song: song)
            case .plain:
                publish(.init(phase: .untimed, title: song.title, artist: song.artist))
            case .notFound:
                publish(.init(phase: .notFound, title: song.title, artist: song.artist))
            }
        }
    }

    /// Wakes up exactly when the next line starts, rather than polling.
    private func runClock(lines: [LyricLine], song: MatchedSong) {
        clock?.cancel()
        clock = Task {
            while !Task.isCancelled {
                // The listener may have matched again since this clock started.
                let song = listener.song ?? song
                let now = Date.now
                let current = LyricClock.moment(lines: lines, song: song, at: now)
                moment = current
                publish(.init(
                    phase: .synced,
                    title: song.title,
                    artist: song.artist,
                    currentLine: current.currentLine,
                    nextLine: current.nextLine,
                    lineStart: current.lineStart,
                    lineEnd: current.lineEnd
                ))
                // After the last line, stay put until the next song matches.
                guard let wake = current.lineEnd else { return }
                let delay = max(wake.timeIntervalSince(now), 0.05)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func publish(_ state: LyricsActivityAttributes.ContentState) {
        enqueue { await $0.update(state) }
    }

    /// Chains Live Activity calls so they run in order; separate tasks could
    /// otherwise let an older line land after a newer one.
    private func enqueue(_ work: @escaping @MainActor (LiveActivityController) async -> Void) {
        let previous = activityQueue
        let controller = liveActivity
        activityQueue = Task {
            await previous?.value
            await work(controller)
        }
    }
}
