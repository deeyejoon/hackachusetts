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
    private let minStandardDeviation: Double

    /// - Parameters:
    ///   - windowSize: how many recent samples define "normal" (e.g. 60 = ~1 min at 1Hz).
    ///   - minStandardDeviation: a floor on SD (bpm). Real heart rate always has at least a
    ///     little beat-to-beat variation; without a floor, an unusually flat warmup window
    ///     drives SD toward zero and makes every tiny bump look like a giant z-score.
    public init(windowSize: Int = 60, minStandardDeviation: Double = 1.5) {
        self.capacity = max(2, windowSize)
        self.minStandardDeviation = max(0, minStandardDeviation)
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
        guard window.count > 1 else { return minStandardDeviation }
        let m = mean
        let variance = window.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(window.count - 1)
        return max(variance.squareRoot(), minStandardDeviation)
    }

    /// How many standard deviations above the mean `bpm` is. Returns 0 before warm-up.
    public func zScore(for bpm: Double) -> Double {
        guard isWarmedUp else { return 0 }
        return (bpm - mean) / standardDeviation
    }

    /// Add a sample to the rolling window, evicting the oldest if at capacity.
    public mutating func add(_ bpm: Double) {
        window.append(bpm)
        if window.count > capacity {
            window.removeFirst(window.count - capacity)
        }
    }
}
