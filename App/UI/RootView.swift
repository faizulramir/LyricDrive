import SwiftUI

/// Picks the screen from the coordinator's state. Each case is one artboard
/// of the approved design (plus finding, untimed and the two failure cases,
/// which follow the same layout).
struct RootView: View {
    @State private var model = LyricsCoordinator()

    private enum ScreenState {
        case idle, listening, micOff
        case shazamFailed(String)
        case finding(MatchedSong)
        case singing(MatchedSong, [LyricLine])
        case untimed(MatchedSong, String)
        case noLyrics(MatchedSong)
        case lookupFailed(MatchedSong, String)
    }

    private var state: ScreenState {
        switch model.listener.status {
        case .micDenied: return .micOff
        case .failed(let message): return .shazamFailed(message)
        case .idle, .listening: break
        }
        guard model.isRunning else { return .idle }
        guard let song = model.song else { return .listening }
        switch model.lyricsState {
        case .none, .loading: return .finding(song)
        case .failed(let message): return .lookupFailed(song, message)
        case .loaded(.synced(let lines)): return .singing(song, lines)
        case .loaded(.plain(let text)): return .untimed(song, text)
        case .loaded(.notFound): return .noLyrics(song)
        }
    }

    var body: some View {
        Group {
            switch state {
            case .idle: idle
            case .listening: listening
            case .micOff: micOff
            case .shazamFailed(let message): shazamFailed(message)
            case .finding(let song): finding(song)
            case .singing(let song, let lines):
                NowSingingView(song: song, lines: lines, moment: model.moment, stop: model.stop)
            case .untimed(let song, let text): untimed(song, text)
            case .noLyrics(let song): noLyrics(song)
            case .lookupFailed(let song, let message): lookupFailed(song, message)
            }
        }
        #if DEBUG
        .task {
            // Lets the Live Activity preview start without a tap, for simulator checks.
            if ProcessInfo.processInfo.arguments.contains("-demoLiveActivity") {
                model.startDemo()
            }
        }
        #endif
    }

    private func startListening() {
        Task { await model.start() }
    }

    private var stopButton: some View {
        Button("Stop listening", action: model.stop).buttonStyle(.action(.surface))
    }

    // MARK: Empty, loading and error screens

    private var idle: some View {
        Screen {
            AppNameHeader()
        } middle: {
            Message(
                title: "Nothing playing yet.",
                detail: "Play a song in YouTube Music, then tap Start listening. The lyrics will follow along here, on your Lock Screen and in CarPlay."
            )
        } bottom: {
            Button("Start listening", action: startListening).buttonStyle(.action(.accent))
            Footnote(text: "The microphone is only on while listening.")
            #if DEBUG
            Button("Preview Live Activity (debug)", action: model.startDemo)
                .font(.footnote)
                .tint(AppColor.dim)
                .frame(minHeight: 44)
            #endif
        }
    }

    private var listening: some View {
        Screen {
            AppNameHeader()
        } middle: {
            VStack(alignment: .leading, spacing: 16) {
                ListeningMark()
                Message(
                    title: "Listening for the song",
                    detail: "Keep the music playing. Once Shazam knows the song, the lyrics start right where you are in it.",
                    centered: false
                )
            }
            .frame(maxHeight: .infinity, alignment: .center)
        } bottom: {
            stopButton
            Footnote(text: "In the car, LyricDrive uses the iPhone microphone, not the car's.")
        }
    }

    private var micOff: some View {
        Screen {
            AppNameHeader()
        } middle: {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "mic.slash")
                    .font(.system(size: 26))
                    .foregroundStyle(AppColor.dim)
                    .accessibilityHidden(true)
                Message(
                    title: "The microphone is off.",
                    detail: "Shazam has to hear the music to know the song. Turn on Microphone for LyricDrive in Settings, then come back.",
                    titleSize: 30,
                    centered: false
                )
            }
            .frame(maxHeight: .infinity, alignment: .center)
        } bottom: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.action(.accent))
        }
    }

    private func shazamFailed(_ message: String) -> some View {
        Screen {
            AppNameHeader()
        } middle: {
            VStack(alignment: .leading, spacing: 16) {
                Message(
                    title: "Shazam couldn't start.",
                    detail: "This is usually the network or the app's ShazamKit setup. The exact error is below.",
                    titleSize: 30,
                    centered: false
                )
                Text(message)
                    .font(.footnote.monospaced())
                    .foregroundStyle(AppColor.faint)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        } bottom: {
            Button("Try again") {
                model.stop()
                startListening()
            }
            .buttonStyle(.action(.accent))
            Button("Stop", action: model.stop).buttonStyle(.action(.quiet))
        }
    }

    private func finding(_ song: MatchedSong) -> some View {
        Screen {
            SongHeader(song: song)
        } middle: {
            HStack(spacing: 12) {
                ProgressView().tint(AppColor.dim)
                Text("Finding the lyrics")
                    .font(.lyric(22))
                    .foregroundStyle(AppColor.dim)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        } bottom: {
            stopButton
        }
    }

    private func untimed(_ song: MatchedSong, _ text: String) -> some View {
        Screen {
            SongHeader(song: song)
            Text("These lyrics have no timing, so they don't follow along.")
                .font(.footnote)
                .foregroundStyle(AppColor.faint)
                .padding(.top, 14)
        } middle: {
            ScrollView {
                Text(text)
                    .font(.lyric(19))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        } bottom: {
            stopButton
        }
    }

    private func noLyrics(_ song: MatchedSong) -> some View {
        Screen {
            SongHeader(song: song)
        } middle: {
            Message(
                title: "No lyrics for this song yet.",
                detail: "LRCLIB has nothing under this title and artist. Your Lock Screen still shows the song name, and LyricDrive keeps listening for the next one.",
                titleSize: 30
            )
        } bottom: {
            Button("Search by title only", action: model.searchByTitleOnly).buttonStyle(.action(.surface))
            Button("Stop listening", action: model.stop).buttonStyle(.action(.quiet))
        }
    }

    private func lookupFailed(_ song: MatchedSong, _ message: String) -> some View {
        Screen {
            SongHeader(song: song)
        } middle: {
            Message(
                title: "Couldn't reach LRCLIB.",
                detail: "\(message) Check the connection, then try again. LyricDrive keeps listening meanwhile.",
                titleSize: 30
            )
        } bottom: {
            Button("Try again", action: model.retryLyrics).buttonStyle(.action(.surface))
            Button("Stop listening", action: model.stop).buttonStyle(.action(.quiet))
        }
    }
}

/// Five amber bars: the design's sign that the microphone is on. It marks a
/// real state (listening), not the actual sound level.
private struct ListeningMark: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach([10, 22, 16, 28, 12], id: \.self) { height in
                RoundedRectangle(cornerRadius: 2).frame(width: 4, height: CGFloat(height))
            }
        }
        .foregroundStyle(AppColor.accent)
        .frame(height: 28, alignment: .bottom)
        .accessibilityLabel("Microphone on")
    }
}

#Preview { RootView() }
