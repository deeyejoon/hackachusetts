import Foundation

/// A detected "extraordinary" physiological change — a deviation from the user's
/// personal baseline large enough to be flagged as unusual.
///
/// Importantly, this makes NO claim about whether the arousal is healthy or harmful.
/// It only says: "this was statistically unusual for *you*, right now." Meaning is
/// supplied later by correlated content keywords and by the user's own labeling.
public struct SpikeEvent: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    /// When the spike was detected.
    public let timestamp: Date
    /// BPM at the moment of detection.
    public let bpm: Double
    /// The rolling baseline BPM the spike was measured against.
    public let baselineBpm: Double
    /// How many standard deviations above baseline this reading was (the "unusualness" score).
    public let zScore: Double

    /// Content the user was exposed to around the time of the spike, filled in by correlation.
    public var correlatedContent: [ContentEvent]

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        bpm: Double,
        baselineBpm: Double,
        zScore: Double,
        correlatedContent: [ContentEvent] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
        self.baselineBpm = baselineBpm
        self.zScore = zScore
        self.correlatedContent = correlatedContent
    }

    /// Absolute BPM increase over baseline, for human-readable reporting.
    public var bpmDelta: Double { bpm - baselineBpm }
}
