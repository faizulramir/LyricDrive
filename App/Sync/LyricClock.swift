import Foundation

/// What to show at one moment of a song.
struct LyricMoment: Equatable {
    /// Index of the line being sung, nil before the first line.
    let index: Int?
    /// Empty for an instrumental gap, nil before the first line.
    let currentLine: String?
    /// The next line that has words, skipping instrumental gaps.
    let nextLine: String?
    let lineStart: Date?
    /// When the next line (of any kind) starts: the moment to update again.
    let lineEnd: Date?
}

/// Turns Shazam's position in the song plus LRC timestamps into the line
/// being sung. Pure functions, so the timing is easy to test.
enum LyricClock {
    /// Wall-clock time at which a line starts, given where Shazam placed us.
    static func date(of line: LyricLine, in song: MatchedSong) -> Date {
        song.matchedAt.addingTimeInterval(line.time - song.offset)
    }

    static func moment(lines: [LyricLine], song: MatchedSong, at date: Date) -> LyricMoment {
        let index = lines.currentIndex(at: song.position(at: date))
        let following = (index ?? -1) + 1
        let nextWithWords = lines[min(following, lines.count)...].first { !$0.text.isEmpty }
        return LyricMoment(
            index: index,
            currentLine: index.map { lines[$0].text },
            nextLine: nextWithWords?.text,
            lineStart: index.map { Self.date(of: lines[$0], in: song) },
            lineEnd: following < lines.count ? Self.date(of: lines[following], in: song) : nil
        )
    }
}
