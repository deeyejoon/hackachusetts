//  MonitorViewModel.swift
//  Drives the on-device physiological-monitoring screen.
//
//  This is the app-side glue around PulseKit's `PhysiologicalMonitor`. It:
//    • starts a heart-rate source (mock for Simulator/demo, WHOOP BLE on device),
//    • feeds the engine content keywords (OCR-style `ContentEvent`s),
//    • fires a real local notification on each spike (via LiveAlertService inside
//      the monitor), and
//    • mirrors each spike into the app's shared `SignalStore` so Insights + Chat
//      stay in sync with what the engine detects.
//
//  For the hackathon demo (no WHOOP band), `simulateReaction(topic:)` injects a
//  realistic spike into the mock source AND primes the engine with a keyword so the
//  resulting notification and signal are labelled — proving the live pipeline end
//  to end in the Simulator.

import Foundation
import Combine

#if canImport(PulseKit)
import PulseCore
import PulseKit

@MainActor
final class MonitorViewModel: ObservableObject {

    /// The PulseKit object that wires source → engine → alerts + weekly report.
    let monitor: PhysiologicalMonitor

    /// Mock source so the whole pipeline runs with no hardware. On a real build you
    /// would construct the monitor with a `WhoopBLESource` instead.
    private let mockSource: MockHeartRateSource

    /// The app's shared signal store, so a detected spike also shows up in Insights
    /// and seeds the Chat signal card.
    private let store: SignalStore

    /// Latest keyword used to label a simulated reaction (shown in the UI).
    @Published private(set) var lastTopic: String?

    init(store: SignalStore) {
        self.store = store

        let source = MockHeartRateSource()
        self.mockSource = source

        // Persist the spike log in the app's caches dir. On device with the ReplayKit
        // extension you would point this at a shared App Group container instead so the
        // extension and app read/write the same file.
        let reportURL = MonitorViewModel.reportFileURL()
        let reportStore = WeeklyReportStore(fileURL: reportURL)

        self.monitor = PhysiologicalMonitor(source: source, store: reportStore)

        // Mirror every detected spike into the app's SignalStore. The monitor's own
        // onSpike (alerts + weekly report) still runs; this adds the app-UI sync.
        bridgeSpikesIntoStore()
    }

    /// Request notification permission and begin streaming heart-rate samples.
    func start() async {
        await monitor.start()
    }

    func stop() {
        monitor.stop()
    }

    /// DEMO: simulate an unusually strong reaction to on-screen content.
    ///
    /// Feeds the engine a keyword `ContentEvent` (as the OCR extension would), then
    /// injects a heart-rate spike into the mock source. The engine time-joins the two,
    /// emits a `SpikeEvent`, and the monitor fires a real local notification labelled
    /// with the topic.
    func simulateReaction(topic: String = "exam") {
        lastTopic = topic
        monitor.ingest(
            content: ContentEvent(
                keywords: [topic],
                appName: "instagram",
                source: .mock
            )
        )
        // Let the content land just before the spike, matching the engine's causal window.
        mockSource.injectSpike()
    }

    // MARK: - Private

    /// Wire a lightweight observer that converts each engine spike into a `PhysioSignal`
    /// and records it in the app's SignalStore. We chain onto the engine via the monitor's
    /// public ingest path by observing the weekly report is not enough, so we subscribe to
    /// the same spikes the monitor sees through a dedicated callback on the shared engine.
    ///
    /// `PhysiologicalMonitor` owns the engine privately, so instead we react to its published
    /// `lastSpikeKeywords`/report changes. Simpler and sufficient for the UI: whenever the
    /// monitor reports a new spike's keywords, record a matching signal.
    private func bridgeSpikesIntoStore() {
        monitor.$lastSpikeKeywords
            .dropFirst() // ignore the initial empty value
            .sink { [weak self] keywords in
                guard let self else { return }
                let signal = PhysioSignal(
                    timestamp: Date(),
                    bpm: self.monitor.currentBPM,
                    baselineBpm: self.monitor.baselineBPM,
                    zScore: 0, // display-only mirror; exact z lives in the weekly report
                    keywords: keywords,
                    appName: "instagram"
                )
                self.store.record(signal)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    /// Spike-log location. Caches dir keeps it out of iCloud/backup and is fine for a demo.
    private static func reportFileURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("sage-spikes.json")
    }
}
#endif
