import XCTest
@testable import PulseCore

final class WeeklyReportStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    private func spike(keywords: [String], at date: Date, z: Double = 3.0, bpm: Double = 110) -> SpikeEvent {
        SpikeEvent(
            timestamp: date,
            bpm: bpm,
            baselineBpm: 68,
            zScore: z,
            correlatedContent: [ContentEvent(keywords: keywords, source: .mock, timestamp: date)]
        )
    }

    func testRecordPersistsAcrossInstances() {
        let store1 = WeeklyReportStore(fileURL: tempURL)
        store1.record(spike(keywords: ["whiskey"], at: Date()))

        // A fresh instance reading the same file must see the recorded spike.
        let store2 = WeeklyReportStore(fileURL: tempURL)
        XCTAssertEqual(store2.allSpikes().count, 1)
        XCTAssertEqual(store2.allSpikes().first?.correlatedContent.first?.keywords, ["whiskey"])
    }

    func testOldSpikesArePrunedByRetention() {
        let store = WeeklyReportStore(fileURL: tempURL, retention: 7 * 24 * 60 * 60)
        let now = Date()

        store.record(spike(keywords: ["recent"], at: now.addingTimeInterval(-1 * 24 * 60 * 60))) // 1 day ago
        store.record(spike(keywords: ["old"], at: now.addingTimeInterval(-10 * 24 * 60 * 60)))    // 10 days ago

        let kept = store.allSpikes().flatMap { $0.correlatedContent.flatMap(\.keywords) }
        XCTAssertTrue(kept.contains("recent"))
        XCTAssertFalse(kept.contains("old"))
    }

    func testGenerateReportFromPersistedSpikes() {
        let store = WeeklyReportStore(fileURL: tempURL)
        let now = Date()
        store.record(spike(keywords: ["whiskey", "bar"], at: now.addingTimeInterval(-3600)))
        store.record(spike(keywords: ["whiskey"], at: now.addingTimeInterval(-1800)))

        let report = store.generateReport(now: now)
        XCTAssertEqual(report.totalSpikes, 2)
        XCTAssertEqual(report.keywords.first?.keyword, "whiskey")
        XCTAssertEqual(report.keywords.first?.occurrences, 2)
    }

    func testResetClearsHistory() {
        let store = WeeklyReportStore(fileURL: tempURL)
        store.record(spike(keywords: ["x"], at: Date()))
        XCTAssertEqual(store.allSpikes().count, 1)

        store.reset()
        XCTAssertEqual(store.allSpikes().count, 0)
    }

    func testEmptyStoreGeneratesEmptyReport() {
        let store = WeeklyReportStore(fileURL: tempURL)
        let report = store.generateReport()
        XCTAssertEqual(report.totalSpikes, 0)
        XCTAssertTrue(report.keywords.isEmpty)
    }
}
