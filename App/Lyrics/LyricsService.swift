import CryptoKit
import Foundation

enum Lyrics: Codable, Equatable, Sendable {
    case synced([LyricLine])
    case plain(String)
    case notFound
}

/// Looks lyrics up on LRCLIB (https://lrclib.net), a free, crowdsourced
/// lyrics database. Found lyrics are cached on the device, so each song is
/// only fetched once.
struct LyricsService: Sendable {
    enum Failure: Error, LocalizedError {
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): "LRCLIB answered with HTTP \(code)."
            }
        }
    }

    private struct Record: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private let session: URLSession
    private let cacheDirectory: URL?

    init(session: URLSession = .shared, cacheDirectory: URL? = Self.defaultCacheDirectory) {
        self.session = session
        self.cacheDirectory = cacheDirectory
    }

    static var defaultCacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Lyrics", isDirectory: true)
    }

    /// `titleOnly` searches by the cleaned title alone, for when LRCLIB spells
    /// the artist differently from Shazam. Its results are still cached under
    /// this title and artist, so the song is found directly next time.
    func lyrics(title: String, artist: String, titleOnly: Bool = false) async throws -> Lyrics {
        let key = cacheKey(title: title, artist: artist)
        if let cached = readCache(key) { return cached }

        // Exact names first, then names with release extras stripped,
        // then a free-text search as a last try.
        let cleanTitle = TitleCleaner.cleanTitle(title)
        let mainArtist = TitleCleaner.primaryArtist(artist)
        var attempts: [[URLQueryItem]] = titleOnly ? [[.init(name: "track_name", value: cleanTitle)]] : [
            [.init(name: "track_name", value: title), .init(name: "artist_name", value: artist)],
        ]
        if !titleOnly, cleanTitle != title || mainArtist != artist {
            attempts.append([.init(name: "track_name", value: cleanTitle), .init(name: "artist_name", value: mainArtist)])
        }
        if !titleOnly {
            attempts.append([.init(name: "q", value: "\(mainArtist) \(cleanTitle)")])
        }

        for (index, query) in attempts.enumerated() {
            let records: [Record]
            do {
                records = try await search(query)
            } catch where index > 0 {
                // The first search already reached LRCLIB, so a failing fallback
                // is LRCLIB struggling (its free-text search can answer 503 on
                // long queries), not the network. Treat it as no result.
                continue
            }
            if let found = bestMatch(in: records) {
                writeCache(found, key: key)
                return found
            }
        }
        // Not cached: LRCLIB is crowdsourced, so the song may be added later.
        return .notFound
    }

    private func search(_ query: [URLQueryItem]) async throws -> [Record] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        // LRCLIB asks clients to identify themselves.
        request.setValue("LyricDrive/0.1 (personal iOS app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.badResponse(status) }
        return try JSONDecoder().decode([Record].self, from: data)
    }

    /// Prefers synced lyrics, then plain ones. Search results come ranked by
    /// relevance, so the first usable record wins.
    private func bestMatch(in records: [Record]) -> Lyrics? {
        for record in records {
            if let synced = record.syncedLyrics {
                let lines = LRCParser.parse(synced)
                if !lines.isEmpty { return .synced(lines) }
            }
        }
        for record in records {
            if let plain = record.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
                return .plain(plain)
            }
        }
        return nil
    }

    // MARK: Cache

    private func cacheKey(title: String, artist: String) -> String {
        let normalized = "\(artist.lowercased())|\(title.lowercased())"
        return SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func readCache(_ key: String) -> Lyrics? {
        guard let url = cacheDirectory?.appendingPathComponent("\(key).json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(Lyrics.self, from: data)
    }

    private func writeCache(_ lyrics: Lyrics, key: String) {
        guard let directory = cacheDirectory,
              let data = try? JSONEncoder().encode(lyrics)
        else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(key).json"), options: .atomic)
    }
}
