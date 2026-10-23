import Foundation

struct LyricLine: Codable, Equatable, Sendable {
    /// Seconds from the start of the song.
    let time: TimeInterval
    /// Empty for an instrumental gap.
    let text: String
}

enum LRCParser {
    /// Parses LRC text such as `[01:23.45]Some line`.
    /// Handles several timestamps on one line, `[mm:ss]`, `[mm:ss.x]` to
    /// `[mm:ss.xxx]`, and skips metadata tags like `[ar:Artist]`.
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for rawLine in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(rawLine)
            var times: [TimeInterval] = []
            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                guard let time = parseTimestamp(tag) else { break }
                times.append(time)
                rest = rest[rest.index(after: close)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            lines += times.map { LyricLine(time: $0, text: text) }
        }
        return lines.sorted { $0.time < $1.time }
    }

    private static func parseTimestamp(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let minutes = Int(parts[0]), minutes >= 0,
              let seconds = Double(parts[1]), seconds >= 0, seconds < 60
        else { return nil }
        return TimeInterval(minutes * 60) + seconds
    }
}

extension Array where Element == LyricLine {
    /// Index of the line being sung at `position`, or nil before the first line.
    func currentIndex(at position: TimeInterval) -> Int? {
        // Binary search for the last line whose time is <= position.
        var low = 0, high = count - 1, found: Int?
        while low <= high {
            let mid = (low + high) / 2
            if self[mid].time <= position {
                found = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return found
    }
}
