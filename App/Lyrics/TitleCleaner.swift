import Foundation

/// Shazam and LRCLIB often format the same song differently. These helpers
/// strip the extras that make an exact lookup miss.
enum TitleCleaner {
    private static let noiseWords = [
        "official", "video", "audio", "lyric", "visualizer", "remaster",
        "feat", "ft.", "with ", "explicit", "radio edit",
    ]
    private static let bracketed = try! Regex(#"\s*[(\[]([^)\]]*)[)\]]"#)

    /// "Song (feat. X) [Official Video] - Remastered 2011" -> "Song"
    static func cleanTitle(_ title: String) -> String {
        // Bracketed parts that only describe the release, not the song.
        // Brackets that are part of the real title, like "(Interlude)", stay.
        var result = title.replacing(bracketed) { match in
            let whole = String(match.output[0].substring ?? "")
            let inner = match.output[1].substring?.lowercased() ?? ""
            return noiseWords.contains(where: inner.contains) ? "" : whole
        }
        // " - Remastered 2011", " - Live at ...", " - Radio Edit"
        if let dash = result.range(of: " - ") {
            let suffix = result[dash.upperBound...].lowercased()
            if noiseWords.contains(where: suffix.contains) || suffix.contains("live") {
                result = String(result[..<dash.lowerBound])
            }
        }
        // Unbracketed "Song feat. X"
        for marker in [" feat. ", " ft. ", " featuring "] {
            if let range = result.range(of: marker, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// "Artist A & Artist B, Artist C" -> "Artist A"
    static func primaryArtist(_ artist: String) -> String {
        var result = artist
        // Not " and ": it would cut "Florence and the Machine".
        for separator in [" & ", ", ", " x ", " feat. ", " ft. "] {
            if let range = result.range(of: separator, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
