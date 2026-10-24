import Foundation

/// Aggregates a collection of spike events into the weekly insight the user sees:
/// "the keywords you had unusual physiological responses to this week."
public struct WeeklyReport: Codable, Sendable {

    /// One keyword and how strongly/often it co-occurred with physiological spikes.
    public struct KeywordInsight: Codable, Sendable, Identifiable {
        public var id: String { keyword }
        public let keyword: String
        /// Number of spikes this keyword was present for.
        public let occurrences: Int
        /// Average z-score (intensity of reaction) across those spikes.
        public let averageIntensity: Double
        /// Average BPM increase over baseline across those spikes.
        public let averageBpmDelta: Double
    }

    public let generatedAt: Date
    public let totalSpikes: Int
    /// Keyword insights, ranked by occurrences then intensity (most notable first).
    public let keywords: [KeywordInsight]

    /// Build a report from a week's worth of spike events.
    public init(spikes: [SpikeEvent], generatedAt: Date = Date()) {
        self.generatedAt = generatedAt
        self.totalSpikes = spikes.count

        // Gather every (keyword -> list of spikes it appeared in).
        var buckets: [String: [SpikeEvent]] = [:]
        for spike in spikes {
            let keys = Set(spike.correlatedContent.flatMap { $0.keywords })
            for key in keys {
                buckets[key, default: []].append(spike)
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

    /// A short human-readable summary line for the top triggers.
    public var summaryLine: String {
        guard !keywords.isEmpty else {
            return "No unusual physiological responses detected this week."
        }
        let top = keywords.prefix(3).map(\.keyword).joined(separator: ", ")
        return "You had unusual physiological responses to: \(top)."
    }
}
