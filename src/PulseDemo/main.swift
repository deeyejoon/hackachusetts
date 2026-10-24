import Foundation
import PulseCore

// MARK: - PulseDemo
//
// An end-to-end, runnable simulation of the physiological-response slice — no WHOOP band,
// no simulator, no entitlements. It wires the *real* production pieces together:
//
//     MockHeartRateSource → CorrelationEngine → live alerts + weekly report
//
// Scenario: the user scrolls a feed. Neutral content goes by. Then an alcohol ad appears
// right as a physiological spike fires. The engine flags the spike, correlates the ad's
// keywords, prints a "live alert", and at the end produces the weekly trigger report.
//
// Run with:  swift run PulseDemo

// A scripted feed: (secondsFromStart, keywords, appName, isSpikeTrigger)
struct FeedItem {
    let at: TimeInterval
    let keywords: [String]
    let app: String
    let triggersSpike: Bool
}

let feed: [FeedItem] = [
    FeedItem(at: 2,  keywords: ["puppy", "cute", "wholesome"],          app: "instagram", triggersSpike: false),
    FeedItem(at: 4,  keywords: ["recipe", "pasta", "dinner"],           app: "instagram", triggersSpike: false),
    FeedItem(at: 6,  keywords: ["whiskey", "bar", "happy hour", "ad"],  app: "instagram", triggersSpike: true),
    FeedItem(at: 9,  keywords: ["travel", "beach", "sunset"],           app: "instagram", triggersSpike: false),
    FeedItem(at: 12, keywords: ["gambling", "bet", "casino", "ad"],     app: "tiktok",    triggersSpike: true),
    FeedItem(at: 15, keywords: ["workout", "gym", "motivation"],        app: "tiktok",    triggersSpike: false),
]

let runDuration: TimeInterval = 18

print("""
╔══════════════════════════════════════════════════════════════╗
║  PulseDemo — physiological-response engine (live simulation)   ║
║  MockHeartRateSource → CorrelationEngine → alerts + report     ║
╚══════════════════════════════════════════════════════════════╝
Baseline is warming up... scroll a feed and watch for unusual reactions.
""")

let start = Date()
func elapsed() -> String { String(format: "%5.1fs", Date().timeIntervalSince(start)) }

// Collect spikes across the "week" (here, the run) for the final report.
var weeklySpikes: [SpikeEvent] = []

// --- Wire up the real engine ---
let engine = CorrelationEngine(
    config: .init(
        spikeZThreshold: 2.3,
        refractoryPeriod: 2.0,     // short for the demo so both triggers show
        causalLookback: 4.0,       // look back up to 4s for the content that caused the spike
        postSpikeGrace: 1.0,
        attributeMostRecentOnly: true,
        baselineWindowSize: 8      // warms up fast for the demo
    )
)

// This is the "live alert" — in the iOS app it becomes a local notification.
engine.onSpike = { spike in
    weeklySpikes.append(spike)
    let triggers = spike.correlatedContent.flatMap { $0.keywords }
    let app = spike.correlatedContent.first?.appName ?? "unknown"
    print("""

    🚨 LIVE ALERT  [\(elapsed())]
       Unusual reaction detected — \(Int(spike.bpm)) bpm (baseline \(Int(spike.baselineBpm)), \
    +\(Int(spike.bpmDelta)) bpm, z=\(String(format: "%.1f", spike.zScore)))
       On screen: \(app) — \(triggers.isEmpty ? "(no content captured)" : triggers.joined(separator: ", "))
       → "Noticed a strong reaction. Want to take a breath?"

    """)
}

// --- The heart-rate source ---
let hr = MockHeartRateSource(restingBpm: 68, naturalVariation: 2.0, interval: 0.5)

var printedSince = Date.distantPast
Task {
    for await sample in hr.samples {
        engine.ingest(sample: sample)
        // Print a calm heartbeat line about once a second so the baseline is visible.
        if Date().timeIntervalSince(printedSince) >= 1.0 {
            printedSince = Date()
            print("   ❤️  [\(elapsed())] \(Int(sample.bpm)) bpm")
        }
    }
}
hr.start()

// --- Drive the scripted feed on the main run loop ---
for item in feed {
    Timer.scheduledTimer(withTimeInterval: item.at, repeats: false) { _ in
        let event = ContentEvent(
            keywords: item.keywords,
            appName: item.app,
            source: .screenBroadcast,   // pretend these came from a ReplayKit+OCR session
            timestamp: Date()
        )
        engine.ingest(content: event)
        print("   📱 [\(elapsed())] \(item.app): \(item.keywords.joined(separator: ", "))")

        // If this item is a known trigger, the user's body reacts ~0.3s later.
        if item.triggersSpike {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                hr.injectSpike(magnitude: 30, durationBeats: 6)
            }
        }
    }
}

// --- End of run: stop the stream and print the weekly report ---
Timer.scheduledTimer(withTimeInterval: runDuration, repeats: false) { _ in
    hr.stop()

    let report = WeeklyReport(spikes: weeklySpikes)
    print("""

    ╔══════════════════════════════════════════════════════════════╗
    ║  WEEKLY REPORT                                                 ║
    ╚══════════════════════════════════════════════════════════════╝
    \(report.summaryLine)
    Total unusual reactions: \(report.totalSpikes)

    Trigger keywords (ranked):
    """)
    if report.keywords.isEmpty {
        print("   (none)")
    } else {
        for k in report.keywords {
            print(String(
                format: "   • %-12@  ×%d   avg +%.0f bpm  (intensity z=%.1f)",
                k.keyword as NSString, k.occurrences, k.averageBpmDelta, k.averageIntensity
            ))
        }
    }
    print("")
    exit(0)
}

// Keep the run loop alive for the duration of the simulation.
RunLoop.main.run()
