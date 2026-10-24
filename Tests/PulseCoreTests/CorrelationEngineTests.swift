import XCTest
@testable import PulseCore

final class CorrelationEngineTests: XCTestCase {

    /// Feed a steady resting baseline so the tracker warms up and stabilizes.
    private func warmUp(_ engine: CorrelationEngine, bpm: Double = 68, beats: Int = 60, start: Date) {
        for i in 0..<beats {
            let ts = start.addingTimeInterval(Double(i))
            // tiny deterministic jitter so SD > 0
            let jitter = (i % 2 == 0) ? 0.5 : -0.5
            engine.ingest(sample: HRSample(bpm: bpm + jitter, timestamp: ts))
        }
    }

    func testNoSpikeDuringNormalBaseline() {
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        // A reading within normal variation should not spike.
        let spike = engine.ingest(sample: HRSample(bpm: 69, timestamp: start.addingTimeInterval(61)))
        XCTAssertNil(spike)
    }

    func testExtraordinaryJumpProducesSpike() {
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        // A large jump well above baseline variation should be flagged.
        let spike = engine.ingest(sample: HRSample(bpm: 110, timestamp: start.addingTimeInterval(61)))
        XCTAssertNotNil(spike)
        XCTAssertGreaterThan(spike!.zScore, 2.5)
        XCTAssertEqual(spike!.bpm, 110)
    }

    func testSpikeCorrelatesWithRecentContent() {
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        let spikeTime = start.addingTimeInterval(61)
        // Content seen 2s before the spike should be joined.
        engine.ingest(content: ContentEvent(
            keywords: ["whiskey", "bar", "happy hour"],
            appName: "instagram",
            source: .mock,
            timestamp: spikeTime.addingTimeInterval(-2)
        ))

        let spike = engine.ingest(sample: HRSample(bpm: 112, timestamp: spikeTime))
        XCTAssertNotNil(spike)
        XCTAssertEqual(spike!.correlatedContent.count, 1)
        XCTAssertTrue(spike!.correlatedContent.first!.keywords.contains("whiskey"))
    }

    func testOldContentIsNotCorrelated() {
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        let spikeTime = start.addingTimeInterval(61)
        // Content seen 30s earlier is outside the 8s correlation window.
        engine.ingest(content: ContentEvent(
            keywords: ["stale"],
            source: .mock,
            timestamp: spikeTime.addingTimeInterval(-30)
        ))

        let spike = engine.ingest(sample: HRSample(bpm: 112, timestamp: spikeTime))
        XCTAssertNotNil(spike)
        XCTAssertTrue(spike!.correlatedContent.isEmpty)
    }

    func testRefractoryPeriodDebouncesSpikes() {
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        let t = start.addingTimeInterval(61)
        let first = engine.ingest(sample: HRSample(bpm: 115, timestamp: t))
        // A second high reading 3s later is within the 10s refractory window → suppressed.
        let second = engine.ingest(sample: HRSample(bpm: 116, timestamp: t.addingTimeInterval(3)))

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testOnSpikeCallbackFires() {
        let engine = CorrelationEngine()
        let start = Date()
        var captured: SpikeEvent?
        engine.onSpike = { captured = $0 }

        warmUp(engine, start: start)
        engine.ingest(sample: HRSample(bpm: 120, timestamp: start.addingTimeInterval(61)))

        XCTAssertNotNil(captured)
    }

    func testAttributesMostRecentContentNotNeutralNeighbors() {
        // Default config: attributeMostRecentOnly = true.
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        let spikeTime = start.addingTimeInterval(61)
        // Neutral content 3s before, the real trigger 1s before.
        engine.ingest(content: ContentEvent(keywords: ["pasta", "recipe"], source: .mock,
                                            timestamp: spikeTime.addingTimeInterval(-3)))
        engine.ingest(content: ContentEvent(keywords: ["whiskey", "bar"], source: .mock,
                                            timestamp: spikeTime.addingTimeInterval(-1)))

        let spike = engine.ingest(sample: HRSample(bpm: 112, timestamp: spikeTime))
        XCTAssertNotNil(spike)
        // Only the most-recent (trigger) content is attributed, not the neutral neighbor.
        XCTAssertEqual(spike!.correlatedContent.count, 1)
        let keys = spike!.correlatedContent.flatMap { $0.keywords }
        XCTAssertTrue(keys.contains("whiskey"))
        XCTAssertFalse(keys.contains("pasta"))
    }

    func testContentAfterSpikeIsNotAttributed() {
        let engine = CorrelationEngine()
        let start = Date()
        warmUp(engine, start: start)

        let spikeTime = start.addingTimeInterval(61)
        // Content that appears well after the spike cannot have caused it.
        let spike = engine.ingest(sample: HRSample(bpm: 112, timestamp: spikeTime))
        engine.ingest(content: ContentEvent(keywords: ["later"], source: .mock,
                                            timestamp: spikeTime.addingTimeInterval(5)))
        XCTAssertNotNil(spike)
        XCTAssertTrue(spike!.correlatedContent.isEmpty)
    }

    func testZScoreStaysSaneWithFlatBaseline() {
        // Even a perfectly flat warmup must not produce an exploding z-score, thanks to
        // the standard-deviation floor in BaselineTracker.
        let engine = CorrelationEngine()
        let start = Date()
        for i in 0..<60 {
            engine.ingest(sample: HRSample(bpm: 68, timestamp: start.addingTimeInterval(Double(i))))
        }
        let spike = engine.ingest(sample: HRSample(bpm: 90, timestamp: start.addingTimeInterval(61)))
        XCTAssertNotNil(spike)
        // +22 bpm over a 1.5 bpm SD floor => z ~= 14.7, not thousands.
        XCTAssertLessThan(spike!.zScore, 20)
        XCTAssertGreaterThan(spike!.zScore, 5)
    }
}
