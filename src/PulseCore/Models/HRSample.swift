import Foundation

/// A single physiological reading from a heart-rate source (WHOOP band, mock, etc.).
///
/// This is the lowest-level unit of data in the system. Everything downstream —
/// baseline tracking, spike detection, correlation — operates on streams of these.
public struct HRSample: Equatable, Codable, Sendable {
    /// Beats per minute at the moment of the reading.
    public let bpm: Double

    /// R-R interval in milliseconds (time between successive heartbeats), when available.
    /// Useful for HRV-based arousal detection; optional because not every source provides it.
    public let rrIntervalMs: Double?

    /// When the reading was taken.
    public let timestamp: Date

    public init(bpm: Double, rrIntervalMs: Double? = nil, timestamp: Date = Date()) {
        self.bpm = bpm
        self.rrIntervalMs = rrIntervalMs
        self.timestamp = timestamp
    }
}
