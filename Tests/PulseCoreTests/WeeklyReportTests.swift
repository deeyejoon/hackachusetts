import XCTest
@testable import PulseCore

final class WeeklyReportTests: XCTestCase {

    private func spike(keywords: [String], z: Double, bpm: Double, baseline: Double = 68) -> SpikeEvent {
        SpikeEvent(
            timestamp: Date(),
            bpm: bpm,
            baselineBpm: baseline,
            zScore: z,
            correlatedContent: [ContentEvent(keywords: keywords, source: .mock)]
        )
    }

    func testEmptyReport() {
        let report = WeeklyReport(spikes: [])
        XCTAssertEqual(report.totalSpikes, 0)
        XCTAssertTrue(report.keywords.isEmpty)
        XCTAssertEqual(report.summaryLine, "No unusual physiological responses detected this week.")
    }

    func testKeywordRankingByOccurrence() {
        let spikes = [
            spike(keywords: ["whiskey", "bar"], z: 3.0, bpm: 110),
            spike(keywords: ["whiskey"], z: 2.8, bpm: 105),
            spike(keywords: ["bar"], z: 2.6, bpm: 100),
            spike(keywords: ["whiskey"], z: 3.5, bpm: 118)
        ]
        let report = WeeklyReport(spikes: spikes)

        XCTAssertEqual(report.totalSpikes, 4)
        // "whiskey" appears in 3 spikes, "bar" in 2 → whiskey ranks first.
        XCTAssertEqual(report.keywords.first?.keyword, "whiskey")
        XCTAssertEqual(report.keywords.first?.occurrences, 3)
    }

    func testIntensityAveraging() {
        let spikes = [
            spike(keywords: ["ad"], z: 2.0, bpm: 100, baseline: 68),
            spike(keywords: ["ad"], z: 4.0, bpm: 120, baseline: 68)
        ]
        let report = WeeklyReport(spikes: spikes)
        let insight = report.keywords.first { $0.keyword == "ad" }

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight!.averageIntensity, 3.0, accuracy: 0.001)
        XCTAssertEqual(insight!.averageBpmDelta, 42.0, accuracy: 0.001) // ((100-68)+(120-68))/2
    }

    func testSummaryLineListsTopTriggers() {
        let spikes = [
            spike(keywords: ["whiskey"], z: 3.0, bpm: 110),
            spike(keywords: ["whiskey"], z: 3.0, bpm: 110),
            spike(keywords: ["gambling"], z: 2.9, bpm: 108),
            spike(keywords: ["gambling"], z: 2.9, bpm: 108),
            spike(keywords: ["ex"], z: 2.7, bpm: 102)
        ]
        let report = WeeklyReport(spikes: spikes)
        XCTAssertTrue(report.summaryLine.contains("whiskey"))
        XCTAssertTrue(report.summaryLine.hasPrefix("You had unusual physiological responses to:"))
    }
}
