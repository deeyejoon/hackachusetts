//  MonitorViewModel.swift
//  Drives the on-device physiological-monitoring screen.
//
//  This is the app-side glue around PulseKit's `PhysiologicalMonitor`. It:
//    • starts a heart-rate source — a real `WhoopBLESource` on device, a
//      `MockHeartRateSource` in the Simulator (where BLE/ReplayKit don't work),
//    • drains OCR keyword events the broadcast extension wrote to the shared App Group
//      queue and feeds them into the engine,
//    • fires a real local notification on each spike (via LiveAlertService inside the
//      monitor), and
//    • mirrors each spike into the app's shared `SignalStore` so Insights + Chat stay in
//      sync with what the engine detects.
//
//  REAL (device) path:
//      WhoopBLESource → engine ← ScreenKeywordCapture (broadcast ext) via SharedContentLog
//                         │
//                         └─ onSpike → LiveAlertService (notification) + SignalStore + report
//
//  SIMULATOR path: MockHeartRateSource + the typed-keyword fallback (`simulateReaction`),
//  since neither BLE nor screen broadcast is available in the Simulator.

import Foundation
import Combine

#if canImport(PulseKit)
import PulseCore
import PulseKit

@MainActor
final class MonitorViewModel: ObservableObject {

    /// The PulseKit object that wires source → engine → alerts + weekly report.
    let monitor: PhysiologicalMonitor

    /// Bundle id of the broadcast extension, handed to the broadcast picker.
    let broadcastExtensionBundleID: String =
        (Bundle.main.bundleIdentifier ?? "com.hackachusetts.sage") + ".Broadcast"

    /// The app's shared signal store, so a detected spike also shows up in Insights
    /// and seeds the Chat signal card.
    private let store: SignalStore

    /// Non-nil only in the Simulator / no-hardware builds, used by `simulateReaction`.
    private let mockSource: MockHeartRateSource?

    /// Latest keyword used to label a reaction (shown in the UI).
    @Published private(set) var lastTopic: String?

    /// True when running the real device pipeline (BLE + screen broadcast available).
    let isDeviceMode: Bool

    private var drainTimer: Timer?

    init(store: SignalStore) {
        self.store = store

        #if targetEnvironment(simulator)
        self.isDeviceMode = false
        #else
        self.isDeviceMode = true
        #endif

        // Choose the heart-rate source for this environment.
        let source: HeartRateSource
        if isDeviceMode {
            source = WhoopBLESource()      // live band over CoreBluetooth
            self.mockSource = nil
        } else {
            let mock = MockHeartRateSource()
            source = mock
            self.mockSource = mock
        }

        // On device, persist spikes to the SHARED App Group store so the broadcast
        // extension and the app agree on history. In the Simulator (no App Group
        // container), fall back to the app's caches dir.
        let reportURL = SharedContainer.spikeLogURL ?? MonitorViewModel.fallbackReportURL()
        let reportStore = WeeklyReportStore(fileURL: reportURL)

        self.monitor = PhysiologicalMonitor(source: source, store: reportStore)

        bridgeSpikesIntoStore()
    }

    /// Request notification permission, start streaming heart-rate samples, and (on
    /// device) begin draining OCR keyword events from the shared queue into the engine.
    func start() async {
        await monitor.start()
        if isDeviceMode {
            startDrainingContentQueue()
        }
    }

    func stop() {
        drainTimer?.invalidate()
        drainTimer = nil
        monitor.stop()
    }

    /// SIMULATOR DEMO: stand in for the OCR path by typing the on-screen text.
    ///
    /// Feeds the engine a keyword `ContentEvent` (tokenised exactly like
    /// `ScreenKeywordCapture`), then injects a heart-rate spike into the mock source.
    /// No-op on device, where real OCR + BLE drive the pipeline instead.
    func simulateReaction(rawKeywords: String = "exam results") {
        guard let mockSource else { return }
        let keywords = Self.tokenize(rawKeywords)
        guard !keywords.isEmpty else { return }

        lastTopic = keywords.first
        monitor.ingest(
            content: ContentEvent(
                keywords: keywords,
                appName: "instagram",
                source: .mock
            )
        )
        mockSource.injectSpike()
    }

    /// Mirror of `ScreenKeywordCapture.extractKeywords` tokenisation for the typed path.
    static func tokenize(_ text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
        for word in words where word.count >= 3 {
            if seen.insert(word).inserted {
                result.append(word)
            }
        }
        return result
    }

    // MARK: - Private

    /// Poll the shared App Group queue the broadcast extension writes to, and feed any
    /// new OCR keyword events into the engine so they can correlate with spikes.
    private func startDrainingContentQueue() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                for event in SharedContentLog.drain() {
                    self.monitor.ingest(content: event)
                    if let first = event.keywords.first { self.lastTopic = first }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.drainTimer = timer
    }

    /// Mirror the monitor's detected spikes into the app's SignalStore for Insights/Chat.
    private func bridgeSpikesIntoStore() {
        monitor.$lastSpikeKeywords
            .dropFirst()
            .sink { [weak self] keywords in
                guard let self else { return }
                let signal = PhysioSignal(
                    timestamp: Date(),
                    bpm: self.monitor.currentBPM,
                    baselineBpm: self.monitor.baselineBPM,
                    zScore: 0, // display-only mirror; exact z lives in the weekly report
                    keywords: keywords,
                    appName: nil
                )
                self.store.record(signal)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    /// Simulator fallback when no App Group container exists.
    private static func fallbackReportURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("sage-spikes.json")
    }
}
#endif
