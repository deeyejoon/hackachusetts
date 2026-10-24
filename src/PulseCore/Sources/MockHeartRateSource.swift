import Foundation

/// A synthetic heart-rate source for development and demos — no WHOOP band required.
///
/// It emits a realistic resting BPM with small natural variation, and lets you
/// `injectSpike()` on demand (or wire it to a UI button / a flagged keyword scrolling
/// into view). Everything downstream behaves identically to a real band, so the entire
/// pipeline can be built and demoed without hardware.
public final class MockHeartRateSource: HeartRateSource, @unchecked Sendable {
    public let samples: AsyncStream<HRSample>
    private let continuation: AsyncStream<HRSample>.Continuation

    private let restingBpm: Double
    private let naturalVariation: Double
    private let interval: TimeInterval

    /// Remaining elevated-beat count for an active injected spike, and its magnitude.
    private var spikeBeatsRemaining = 0
    private var spikeMagnitude: Double = 0

    private var timer: Timer?
    private let lock = NSLock()

    /// - Parameters:
    ///   - restingBpm: baseline resting heart rate the stream hovers around.
    ///   - naturalVariation: +/- random jitter applied each beat (keeps baseline realistic).
    ///   - interval: seconds between emitted samples.
    public init(
        restingBpm: Double = 68,
        naturalVariation: Double = 2.5,
        interval: TimeInterval = 1.0
    ) {
        self.restingBpm = restingBpm
        self.naturalVariation = naturalVariation
        self.interval = interval

        var cont: AsyncStream<HRSample>.Continuation!
        self.samples = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func start() {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.emit()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        continuation.finish()
    }

    /// Simulate a physiological reaction: BPM ramps up by `magnitude` and decays over
    /// `durationBeats` samples, mimicking the shape of a real arousal response.
    public func injectSpike(magnitude: Double = 28, durationBeats: Int = 8) {
        lock.lock()
        spikeMagnitude = magnitude
        spikeBeatsRemaining = durationBeats
        lock.unlock()
    }

    private func emit() {
        lock.lock()
        var bpm = restingBpm + Double.random(in: -naturalVariation...naturalVariation)
        if spikeBeatsRemaining > 0 {
            // Decay the spike linearly so it rises then eases back toward baseline.
            let progress = Double(spikeBeatsRemaining) / 8.0
            bpm += spikeMagnitude * min(progress, 1.0)
            spikeBeatsRemaining -= 1
        }
        lock.unlock()

        let rr = 60_000.0 / bpm // crude R-R interval in ms derived from BPM
        continuation.yield(HRSample(bpm: bpm, rrIntervalMs: rr, timestamp: Date()))
    }
}
