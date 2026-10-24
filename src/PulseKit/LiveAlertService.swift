#if canImport(UserNotifications)
import Foundation
import UserNotifications
import PulseCore

/// Delivers a live, supportive notification the instant the engine flags an unusual
/// physiological reaction. This is the production stand-in for the `print()` in PulseDemo:
/// wire `CorrelationEngine.onSpike` to `handle(spike:)` and the user gets a gentle nudge
/// even when the app is backgrounded.
///
/// Tone is deliberate — this is a mental-health context, so the copy is a non-judgmental
/// invitation ("want to take a breath?"), never an accusation.
public final class LiveAlertService {

    private let center: UNUserNotificationCenter
    /// Avoid alert fatigue: suppress notifications fired within this interval of the last one.
    private let minInterval: TimeInterval
    private var lastAlert: Date?

    public init(center: UNUserNotificationCenter = .current(),
                minInterval: TimeInterval = 60) {
        self.center = center
        self.minInterval = minInterval
    }

    /// Request permission to show alerts. Call once during onboarding.
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Turn a detected spike into a local notification. Safe to pass directly as `onSpike`.
    public func handle(spike: SpikeEvent) {
        // Throttle so a burst of spikes doesn't spam the user.
        if let last = lastAlert, Date().timeIntervalSince(last) < minInterval { return }
        lastAlert = Date()

        let content = UNMutableNotificationContent()
        content.title = "Strong reaction noticed"
        content.body = Self.message(for: spike)
        content.sound = .default
        content.userInfo = [
            "bpm": spike.bpm,
            "baselineBpm": spike.baselineBpm,
            "zScore": spike.zScore,
            "keywords": spike.correlatedContent.flatMap { $0.keywords }
        ]

        let request = UNNotificationRequest(
            identifier: spike.id.uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        center.add(request, withCompletionHandler: nil)
    }

    /// Compose non-judgmental copy, naming the on-screen content when we captured it.
    static func message(for spike: SpikeEvent) -> String {
        let keywords = spike.correlatedContent.flatMap { $0.keywords }
        if let topic = keywords.first {
            return "Your body reacted strongly around \u{201C}\(topic)\u{201D}. Want to pause and take a breath?"
        }
        return "Your body just reacted strongly. Want to pause and take a breath?"
    }
}
#endif
