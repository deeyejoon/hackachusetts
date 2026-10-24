import Foundation

/// Maintains a rolling statistical baseline of the user's heart rate.
///
/// "Unusual" is defined *per user, continuously* — not against a fixed threshold. We keep
/// a sliding window of recent samples and compute a running mean and standard deviation.
/// A new reading's z-score (how many standard deviations above the mean) is the basis for
/// spike detection. This is what lets the system report "extraordinary changes" rather than
/// guessing at absolute numbers that differ from person to person.
public struct BaselineTracker {
    private var window: [Double] = []
    private let capacity: Int

    /// - Parameter windowSize: how many recent samples define "normal" (e.g. 60 = ~1 min at 1Hz).
    public init(windowSize: Int = 60) {
        self.capacity = max(2, windowSize)
    }

    /// Number of samples currently in the window.
    public var count: Int { window.count }

    /// True once there are enough samples for a statistically meaningful baseline.
    public var isWarmedUp: Bool { window.count >= min(capacity, 10) }

    public var mean: Double {
        guard !window.isEmpty else { return 0 }
        return window.reduce(0, +) / Double(window.count)
    }

    public var standardDeviation: Double {
        guard window.count > 1 else { return 0 }
        let m = mean
        let variance = window.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(window.count - 1)
        return variance.squareRoot()
    }

    /// How many standard deviations above the mean `bpm` is. Returns 0 before warm-up
    /// or when there's no variation yet (avoids divide-by-zero false positives).
    public func zScore(for bpm: Double) -> Double {
        let sd = standardDeviation
        guard isWarmedUp, sd > 0.001 else { return 0 }
        return (bpm - mean) / sd
    }

    /// Add a sample to the rolling window, evicting the oldest if at capacity.
    public mutating func add(_ bpm: Double) {
        window.append(bpm)
        if window.count > capacity {
            window.removeFirst(window.count - capacity)
        }
    }
}
