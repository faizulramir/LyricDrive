import ActivityKit
import Foundation

/// Starts, updates and ends the one Live Activity of a listening session.
@MainActor
final class LiveActivityController {
    typealias State = LyricsActivityAttributes.ContentState

    private var activity: Activity<LyricsActivityAttributes>?
    private var lastState: State?

    /// Must be called while the app is in the foreground: iOS refuses to
    /// start a Live Activity from the background.
    func start(_ state: State) async {
        // A crash or force-quit can leave an old activity on the Lock Screen.
        for old in Activity<LyricsActivityAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(
            attributes: LyricsActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
        )
        lastState = state
    }

    /// Skips updates that would not change what is on screen, which keeps us
    /// well inside the system's update budget.
    func update(_ state: State) async {
        guard let activity, state != lastState else { return }
        lastState = state
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func end() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        lastState = nil
    }
}
