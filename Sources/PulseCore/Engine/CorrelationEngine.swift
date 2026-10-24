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
        /// How far *before* a spike to look for the content that caused it. A physiological
        /// reaction follows exposure, so correlation is causal: we look backward, not forward.
        public var causalLookback: TimeInterval
        /// Small grace window *after* the spike, to absorb clock jitter between the HR stream
        /// and content capture (content timestamped a hair after the first elevated beat).
        public var postSpikeGrace: TimeInterval
        /// When true, only the single most-recent content event before the spike is attributed
        /// (the likeliest trigger), instead of every event in the window. Avoids blaming neutral
        /// content that merely happened to be nearby.
        public var attributeMostRecentOnly: Bool
        /// Sliding-window size (samples) for the baseline.
        public var baselineWindowSize: Int

        public init(
            spikeZThreshold: Double = 2.5,
            refractoryPeriod: TimeInterval = 10,
            causalLookback: TimeInterval = 6,
            postSpikeGrace: TimeInterval = 1,
            attributeMostRecentOnly: Bool = true,
            baselineWindowSize: Int = 60
        ) {
            self.spikeZThreshold = spikeZThreshold
            self.refractoryPeriod = refractoryPeriod
            self.causalLookback = causalLookback
            self.postSpikeGrace = postSpikeGrace
            self.attributeMostRecentOnly = attributeMostRecentOnly
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
        let correlated = correlatedContent(forSpikeAt: sample.timestamp)

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

    /// Select the content responsible for a spike. Causal: content must have appeared within
    /// `causalLookback` seconds *before* the spike (plus a small post-spike grace for jitter).
    /// When `attributeMostRecentOnly` is set, only the single latest such event is returned —
    /// the likeliest trigger — rather than every nearby event.
    private func correlatedContent(forSpikeAt t: Date) -> [ContentEvent] {
        let inWindow = recentContent.filter {
            let dt = t.timeIntervalSince($0.timestamp) // positive => content before spike
            return dt >= -config.postSpikeGrace && dt <= config.causalLookback
        }
        guard config.attributeMostRecentOnly else { return inWindow }
        // Most recent content before (or at) the spike is the likeliest cause.
        if let latest = inWindow.max(by: { $0.timestamp < $1.timestamp }) {
            return [latest]
        }
        return []
    }

    /// Drop content events older than the causal lookback so the buffer stays small.
    private func pruneContent(now: Date) {
        let cutoff = now.addingTimeInterval(-config.causalLookback)
        recentContent.removeAll { $0.timestamp < cutoff }
    }
}
