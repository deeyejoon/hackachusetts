import Foundation

/// The core of the physiological-response slice.
///
/// It consumes two streams — heart-rate samples and content events — and produces
/// `SpikeEvent`s: moments where the user's heart rate was *extraordinarily* elevated
/// relative to their own rolling baseline, annotated with whatever content was on screen
/// around that moment.
///
/// Responsibilities:
///   1. Track a per-user rolling baseline (BaselineTracker).
///   2. Flag a sample as a spike when its z-score crosses a threshold.
///   3. Debounce so one physiological event isn't reported as many spikes.
///   4. Time-join recent content events to each spike.
///
/// It is source-agnostic: feed it from the mock source now, a WHOOP band later.
public final class CorrelationEngine {

    public struct Config {
        /// z-score above which a reading is considered extraordinary.
        public var spikeZThreshold: Double
        /// Minimum seconds between two reported spikes (debounce).
        public var refractoryPeriod: TimeInterval
        /// How far back/forward from a spike to look for related content.
        public var correlationWindow: TimeInterval
        /// Sliding-window size (samples) for the baseline.
        public var baselineWindowSize: Int

        public init(
            spikeZThreshold: Double = 2.5,
            refractoryPeriod: TimeInterval = 10,
            correlationWindow: TimeInterval = 8,
            baselineWindowSize: Int = 60
        ) {
            self.spikeZThreshold = spikeZThreshold
            self.refractoryPeriod = refractoryPeriod
            self.correlationWindow = correlationWindow
            self.baselineWindowSize = baselineWindowSize
        }
    }

    private let config: Config
    private var baseline: BaselineTracker
    private var recentContent: [ContentEvent] = []
    private var lastSpikeTime: Date?

    /// Called synchronously whenever a spike is detected. Wire this to live alerts + storage.
    public var onSpike: ((SpikeEvent) -> Void)?

    public init(config: Config = Config()) {
        self.config = config
        self.baseline = BaselineTracker(windowSize: config.baselineWindowSize)
    }

    /// Record a content exposure. Kept in a short rolling buffer for time-joining to spikes.
    public func ingest(content event: ContentEvent) {
        recentContent.append(event)
        pruneContent(now: event.timestamp)
    }

    /// Feed one heart-rate sample. May emit a spike via `onSpike` and return it.
    @discardableResult
    public func ingest(sample: HRSample) -> SpikeEvent? {
        let z = baseline.zScore(for: sample.bpm)

        // The baseline must be updated regardless of whether this is a spike, so that a
        // sustained elevation gradually becomes the new normal rather than alarming forever.
        defer { baseline.add(sample.bpm) }

        guard baseline.isWarmedUp, z >= config.spikeZThreshold else { return nil }

        // Debounce: suppress spikes that fall inside the refractory period of the last one.
        if let last = lastSpikeTime,
           sample.timestamp.timeIntervalSince(last) < config.refractoryPeriod {
            return nil
        }
        lastSpikeTime = sample.timestamp

        pruneContent(now: sample.timestamp)
        let correlated = recentContent.filter {
            abs($0.timestamp.timeIntervalSince(sample.timestamp)) <= config.correlationWindow
        }

        let spike = SpikeEvent(
            timestamp: sample.timestamp,
            bpm: sample.bpm,
            baselineBpm: baseline.mean,
            zScore: z,
            correlatedContent: correlated
        )
        onSpike?(spike)
        return spike
    }

    /// Drop content events older than the correlation window so the buffer stays small.
    private func pruneContent(now: Date) {
        let cutoff = now.addingTimeInterval(-config.correlationWindow)
        recentContent.removeAll { $0.timestamp < cutoff }
    }
}
