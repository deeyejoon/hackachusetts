//  PhysioSignal.swift
//  The app-side mirror of PulseCore's `SpikeEvent` + `WeeklyReport`.
//
//  Why this exists:
//  PulseCore (the Swift Package in `Sources/`) is the canonical engine. Its public
//  models — `SpikeEvent`, `ContentEvent`, `WeeklyReport` — are the source of truth.
//  But the SwiftUI app is a set of loose `.swift` files that must compile and run in
//  the Simulator *before* the Xcode target links PulseCore over SPM. So we keep a
//  tiny, dependency-free value type here whose fields line up 1:1 with `SpikeEvent`.
//
//  Once the Xcode app target adds PulseCore as a local package, `PulseCoreBridge`
//  converts a real `SpikeEvent` into a `PhysioSignal` with zero change to any view.
//  See docs/INTEGRATION.md, Contract 1.

import Foundation

/// One detected "extraordinary" physiological reaction, correlated with on-screen
/// content. Mirrors `PulseCore.SpikeEvent` (+ its first correlated `ContentEvent`).
///
/// Like the engine, this makes NO claim about healthy vs. harmful — it only records
/// that something was statistically unusual for this user, and what was on screen.
struct PhysioSignal: Identifiable, Equatable {
    let id: UUID
    /// When the spike was detected.
    let timestamp: Date
    /// BPM at the moment of detection.
    let bpm: Double
    /// Rolling baseline BPM the spike was measured against.
    let baselineBpm: Double
    /// How many standard deviations above baseline (the "unusualness" score).
    let zScore: Double
    /// Keywords from the correlated content (OCR text, caption, etc.), lowercased.
    let keywords: [String]
    /// App/website the content came from, when known (e.g. "instagram").
    let appName: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        bpm: Double,
        baselineBpm: Double,
        zScore: Double,
        keywords: [String],
        appName: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
        self.baselineBpm = baselineBpm
        self.zScore = zScore
        self.keywords = keywords.map { $0.lowercased() }
        self.appName = appName
    }

    /// Absolute BPM increase over baseline, for human-readable reporting.
    var bpmDelta: Double { bpm - baselineBpm }

    /// A short time label for the Chat signal card (e.g. "2:14 PM").
    var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }

    /// The payload sent to the backend as `signal_context` (docs/INTEGRATION.md,
    /// Contract 3). Keys are snake_case to match the Flask API.
    var backendContext: [String: Any] {
        var ctx: [String: Any] = ["keywords": keywords]
        if let appName { ctx["app_name"] = appName }
        ctx["bpm_delta"] = Int(bpmDelta.rounded())
        return ctx
    }
}

/// One keyword and how strongly/often it co-occurred with physiological spikes.
/// Mirrors `PulseCore.WeeklyReport.KeywordInsight`.
struct KeywordInsight: Identifiable, Equatable {
    var id: String { keyword }
    let keyword: String
    let occurrences: Int
    let averageIntensity: Double   // average z-score
    let averageBpmDelta: Double
}

/// The weekly insight the user sees on the Insights screen: ranked trigger keywords
/// aggregated from a set of signals. The ranking logic mirrors
/// `PulseCore.WeeklyReport` (occurrences first, then intensity) so the app and the
/// engine agree on what "top triggers" means.
struct WeeklySignalReport: Equatable {
    let totalSignals: Int
    let keywords: [KeywordInsight]

    init(signals: [PhysioSignal]) {
        self.totalSignals = signals.count

        // keyword -> the signals it appeared in
        var buckets: [String: [PhysioSignal]] = [:]
        for signal in signals {
            for key in Set(signal.keywords) {
                buckets[key, default: []].append(signal)
            }
        }

        self.keywords = buckets.map { keyword, related in
            let avgZ = related.map(\.zScore).reduce(0, +) / Double(related.count)
            let avgDelta = related.map(\.bpmDelta).reduce(0, +) / Double(related.count)
            return KeywordInsight(
                keyword: keyword,
                occurrences: related.count,
                averageIntensity: avgZ,
                averageBpmDelta: avgDelta
            )
        }
        .sorted {
            $0.occurrences != $1.occurrences
                ? $0.occurrences > $1.occurrences
                : $0.averageIntensity > $1.averageIntensity
        }
    }

    /// Short human-readable summary of the top triggers.
    var summaryLine: String {
        guard !keywords.isEmpty else {
            return "No unusual physiological responses detected this week."
        }
        let top = keywords.prefix(3).map(\.keyword).joined(separator: ", ")
        return "You had unusual physiological responses to: \(top)."
    }
}
