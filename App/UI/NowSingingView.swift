import SwiftUI

/// The main screen: all lines, with the one being sung large and centered,
/// the next one a step quieter, and everything else soft.
struct NowSingingView: View {
    let song: MatchedSong
    let lines: [LyricLine]
    let moment: LyricMoment?
    let stop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: Int? { moment?.index }

    var body: some View {
        Screen {
            SongHeader(song: song)
            Text("Matched by Shazam. Synced lyrics from LRCLIB.")
                .font(.footnote)
                .foregroundStyle(AppColor.faint)
                .padding(.top, 14)
        } middle: {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            row(index: index, line: line).id(index)
                        }
                    }
                    // Lets the first and last lines reach the middle.
                    .padding(.vertical, 220)
                }
                .scrollIndicators(.hidden)
                .onChange(of: current, initial: true) { _, index in
                    guard let index else { return }
                    // The scroll is the line change itself, so it stays even at
                    // MOTION 1; reduced motion jumps instead of gliding.
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            .mask {
                // Soft edges so lines fade in and out instead of being cut.
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        } bottom: {
            Footnote(text: "Showing on your Lock Screen and CarPlay")
            Button("Stop listening", action: stop).buttonStyle(.action(.surface))
        }
    }

    @ViewBuilder
    private func row(index: Int, line: LyricLine) -> some View {
        let text = line.text.isEmpty ? "♪" : line.text
        if index == current {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.lyric(30, weight: .medium))
                    .foregroundStyle(AppColor.text)
                LineProgress(interval: interval)
            }
        } else if index == (current ?? -1) + 1 {
            Text(text).font(.lyric(22)).foregroundStyle(AppColor.dim)
        } else {
            Text(text).font(.lyric(19)).foregroundStyle(AppColor.faint)
        }
    }

    private var interval: ClosedRange<Date>? {
        guard let start = moment?.lineStart, let end = moment?.lineEnd, start < end else { return nil }
        return start...end
    }
}
