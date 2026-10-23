import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LyricDriveWidgets: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivity()
    }
}

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Palette.ground)
                .activitySystemActionForegroundColor(Palette.text)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedIslandView(state: context.state)
                }
            } compactLeading: {
                ArtworkMark(size: 22)
            } compactTrailing: {
                LinesMotif()
            } minimal: {
                LinesMotif()
            }
        }
        // `.small` is the layout CarPlay (and Apple Watch) use.
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - What to say in each phase

private extension LyricsActivityAttributes.ContentState {
    var header: String {
        switch (title, artist) {
        case let (title?, artist?): "\(title), \(artist)"
        case let (title?, nil): title
        default: "LyricDrive"
        }
    }

    var mainLine: String {
        switch phase {
        case .listening: "Listening for the song"
        case .findingLyrics: "Finding the lyrics"
        case .untimed: "These lyrics have no timing."
        case .notFound: "No lyrics for this song yet."
        // Before the first line and in instrumental gaps there are no words.
        case .synced: (currentLine?.isEmpty ?? true) ? "♪" : currentLine!
        }
    }

    var secondLine: String? {
        switch phase {
        case .synced: nextLine
        case .untimed: "Open LyricDrive to read them."
        default: nil
        }
    }

    var lineInterval: ClosedRange<Date>? {
        guard phase == .synced, let lineStart, let lineEnd, lineStart < lineEnd else { return nil }
        return lineStart...lineEnd
    }
}

// MARK: - Lock Screen and CarPlay

private struct LockScreenView: View {
    let state: LyricsActivityAttributes.ContentState
    @Environment(\.activityFamily) private var family

    var body: some View {
        if family == .small {
            CarPlayView(state: state)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ArtworkMark(size: 28)
                    Text(state.header)
                        .font(.footnote)
                        .foregroundStyle(Palette.dim)
                        .lineLimit(1)
                }
                LinePair(state: state, mainSize: 22, nextSize: 16, barHeight: 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }
}

/// Built for a half-second glance while driving: no song name, just the
/// line, as large as the tile allows.
private struct CarPlayView: View {
    let state: LyricsActivityAttributes.ContentState

    var body: some View {
        LinePair(state: state, mainSize: 28, nextSize: 19, barHeight: 3)
            .minimumScaleFactor(0.6)
            .padding(14)
    }
}

// MARK: - Dynamic Island

private struct ExpandedIslandView: View {
    let state: LyricsActivityAttributes.ContentState

    // The expanded island is short: a two-line lyric, the hairline and the
    // next line fill it, so the song name (already on the Lock Screen) stays out.
    var body: some View {
        LinePair(state: state, mainSize: 20, nextSize: 15, barHeight: 2, mainLineLimit: 2, nextLineLimit: 1)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }
}

// MARK: - Shared pieces

/// The design's motif: the line you hear at full strength, the next one
/// quieter underneath, with an amber hairline for progress through the line.
private struct LinePair: View {
    let state: LyricsActivityAttributes.ContentState
    let mainSize: CGFloat
    let nextSize: CGFloat
    let barHeight: CGFloat
    var mainLineLimit = 3
    var nextLineLimit = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.mainLine)
                .font(.lyric(mainSize, weight: .medium))
                .foregroundStyle(Palette.text)
                .lineLimit(mainLineLimit)
                // Live Activities lay text out on one line unless allowed to
                // grow; a long lyric should wrap, not end in "...".
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            if let interval = state.lineInterval {
                // Counts up by itself between updates; no extra updates needed.
                ProgressView(timerInterval: interval, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(Palette.accent)
                .frame(height: barHeight)
                .accessibilityLabel("Progress through the current line")
            }
            if let next = state.secondLine {
                Text(next)
                    .font(.lyric(nextSize))
                    .foregroundStyle(Palette.dim)
                    .lineLimit(nextLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Stands in for the artwork. Showing the real cover needs it downloaded into
/// a shared App Group, which needs another App ID setting; left for later.
private struct ArtworkMark: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(Palette.surface)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Palette.faint)
            }
            .accessibilityHidden(true)
    }
}

/// Two short bars, bright then quiet: "current line, next line" in miniature.
private struct LinesMotif: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Capsule().fill(Palette.accent).frame(width: 16, height: 3)
            Capsule().fill(Palette.quietBar).frame(width: 11, height: 3)
        }
        .accessibilityLabel("Lyrics following along")
    }
}
