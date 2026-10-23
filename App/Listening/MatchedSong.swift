import Foundation

struct MatchedSong: Equatable {
    let title: String
    let artist: String
    let isrc: String?
    let artworkURL: URL?
    /// Where we were in the song (seconds) at `matchedAt`.
    let offset: TimeInterval
    let matchedAt: Date

    /// Same recording, ignoring when or where in it we matched.
    func isSameSong(as other: MatchedSong) -> Bool {
        if let isrc, let otherISRC = other.isrc { return isrc == otherISRC }
        return title.caseInsensitiveCompare(other.title) == .orderedSame
            && artist.caseInsensitiveCompare(other.artist) == .orderedSame
    }

    func position(at date: Date) -> TimeInterval {
        offset + date.timeIntervalSince(matchedAt)
    }
}
