import SwiftUI

/// Shared frame for every screen: ground color, the design's margins, a top
/// block, a centered middle and actions pinned to the bottom.
struct Screen<Top: View, Middle: View, Bottom: View>: View {
    @ViewBuilder var top: Top
    @ViewBuilder var middle: Middle
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            top
            middle
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            VStack(spacing: 12) { bottom }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(AppColor.ground.ignoresSafeArea())
        .foregroundStyle(AppColor.text)
    }
}

/// App name as text: there is no logo yet.
struct AppNameHeader: View {
    var body: some View {
        Text("LyricDrive").font(.system(size: 17, weight: .semibold))
    }
}

/// A screen's message: serif headline plus one short explanation.
struct Message: View {
    let title: String
    let detail: String
    var titleSize: CGFloat = 34
    /// Off when the message sits in a group that centers itself.
    var centered = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.lyric(titleSize, weight: .medium))
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.system(size: 17))
                .foregroundStyle(AppColor.dim)
                .lineSpacing(4)
        }
        .frame(maxHeight: centered ? .infinity : nil, alignment: .center)
    }
}

struct Footnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppColor.faint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// Artwork from Shazam, with a quiet placeholder while it loads or if the
/// song has none.
struct Artwork: View {
    let url: URL?
    var size: CGFloat = 56

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4))
                .foregroundStyle(AppColor.faint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.surface)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct SongHeader: View {
    let song: MatchedSong

    var body: some View {
        HStack(spacing: 14) {
            Artwork(url: song.artworkURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title).font(.system(size: 17, weight: .semibold))
                Text(song.artist).font(.system(size: 15)).foregroundStyle(AppColor.dim)
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Amber hairline that fills as the current line plays. Driven by the
/// system timer, so it moves smoothly without the app redrawing.
struct LineProgress: View {
    let interval: ClosedRange<Date>?
    var height: CGFloat = 2

    var body: some View {
        if let interval {
            ProgressView(timerInterval: interval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(AppColor.accent)
            .frame(height: height)
            .accessibilityHidden(true)
        } else {
            Capsule().fill(AppColor.track).frame(height: height)
        }
    }
}
