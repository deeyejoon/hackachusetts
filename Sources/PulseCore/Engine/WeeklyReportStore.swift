import Foundation

/// Persists spike events so the weekly report survives app restarts and actually spans a week.
///
/// The CorrelationEngine produces spikes in memory; without persistence the "weekly report"
/// would reset every launch. This store appends each spike to a JSON file, prunes anything
/// older than the retention window, and builds a `WeeklyReport` on demand from the last 7 days.
///
/// It lives in PulseCore (no iOS-only APIs) so it is unit-testable on macOS. The file location
/// is injectable: the iOS app passes a URL inside the shared App Group container so the
/// ReplayKit broadcast extension and the main app read/write the same store.
public final class WeeklyReportStore {

    private let fileURL: URL
    private let retention: TimeInterval
    private let queue = DispatchQueue(label: "pulse.weeklyreportstore")

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// - Parameters:
    ///   - fileURL: where to store the spike log (JSON).
    ///   - retention: how far back to keep spikes. Defaults to 7 days.
    public init(fileURL: URL, retention: TimeInterval = 7 * 24 * 60 * 60) {
        self.fileURL = fileURL
        self.retention = retention
    }

    /// Append a spike and prune anything older than the retention window. Thread-safe;
    /// safe to wire directly to `CorrelationEngine.onSpike`.
    public func record(_ spike: SpikeEvent) {
        queue.sync {
            var all = loadUnsafe()
            all.append(spike)
            all = prune(all, now: Date())
            saveUnsafe(all)
        }
    }

    /// All retained spikes, oldest first.
    public func allSpikes() -> [SpikeEvent] {
        queue.sync { prune(loadUnsafe(), now: Date()).sorted { $0.timestamp < $1.timestamp } }
    }

    /// Build the report over the retained window (default: last 7 days).
    public func generateReport(now: Date = Date()) -> WeeklyReport {
        let spikes = queue.sync { prune(loadUnsafe(), now: now) }
        return WeeklyReport(spikes: spikes, generatedAt: now)
    }

    /// Remove all stored spikes (e.g. a "clear history" action).
    public func reset() {
        queue.sync { try? FileManager.default.removeItem(at: fileURL) }
    }

    // MARK: - Private (must be called on `queue`)

    private func prune(_ spikes: [SpikeEvent], now: Date) -> [SpikeEvent] {
        let cutoff = now.addingTimeInterval(-retention)
        return spikes.filter { $0.timestamp >= cutoff }
    }

    private func loadUnsafe() -> [SpikeEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let spikes = try? decoder.decode([SpikeEvent].self, from: data) else {
            return []
        }
        return spikes
    }

    private func saveUnsafe(_ spikes: [SpikeEvent]) {
        guard let data = try? encoder.encode(spikes) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
