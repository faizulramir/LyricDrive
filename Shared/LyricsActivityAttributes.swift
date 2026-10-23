import ActivityKit
import Foundation

/// Shared between the app (which starts and updates the Live Activity)
/// and the widget extension (which draws it).
///
/// One activity covers a whole listening session, so the song lives in the
/// changing `ContentState`, not in the fixed attributes: iOS only lets an app
/// start a Live Activity while it is in the foreground, and songs change
/// while the phone is locked.
struct LyricsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case listening      // no song matched yet
            case findingLyrics  // song matched, LRCLIB lookup running
            case synced         // timed lyrics, line by line
            case untimed        // LRCLIB only has plain lyrics
            case notFound       // no lyrics for this song
        }

        var phase: Phase
        var title: String?
        var artist: String?
        var currentLine: String?
        var nextLine: String?
        /// When the current line started and when the next one starts, so the
        /// progress hairline can animate on its own between updates.
        var lineStart: Date?
        var lineEnd: Date?

        static let listening = ContentState(phase: .listening)
    }
}
