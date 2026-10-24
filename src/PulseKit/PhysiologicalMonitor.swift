#if canImport(Combine)
import Foundation
import Combine
import PulseCore

/// The single object the app talks to. It wires the whole physiological-response slice
/// together so the UI doesn't have to know about engines, sources, or notifications:
///
///     HeartRateSource → CorrelationEngine → { LiveAlertService, WeeklyReportStore }
///
/// It is an `ObservableObject`, so a SwiftUI view can bind to `currentBPM`, `connectionState`,
/// and `latestReport` and update live. Pass any `HeartRateSource` — `WhoopBLESource` for a real
/// band, or `MockHeartRateSource` for development and demos with no hardware.
@MainActor
public final class PhysiologicalMonitor: ObservableObject {

    // Published state the UI binds to.
    @Published public private(set) var currentBPM: Double = 0
    @Published public private(set) var baselineBPM: Double = 0
    @Published public private(set) var connectionState: String = "Idle"
    @Published public private(set) var lastSpikeKeywords: [String] = []
    @Published public private(set) var latestReport: WeeklyReport

    private let source: HeartRateSource
    private let engine: CorrelationEngine
    private let alerts: LiveAlertService
    private let store: WeeklyReportStore
    private var streamTask: Task<Void, Never>?

    public init(
        source: HeartRateSource,
        store: WeeklyReportStore,
        engine: CorrelationEngine = CorrelationEngine(),
        alerts: LiveAlertService = LiveAlertService()
    ) {
        self.source = source
        self.store = store
        self.engine = engine
        self.alerts = alerts
        self.latestReport = store.generateReport()

        // When the engine flags a spike: notify the user, persist it, refresh the report, update UI.
        engine.onSpike = { [weak self] spike in
            guard let self else { return }
            self.alerts.handle(spike: spike)
            self.store.record(spike)
            Task { @MainActor in
                self.lastSpikeKeywords = spike.correlatedContent.flatMap { $0.keywords }
                self.latestReport = self.store.generateReport()
            }
        }

        // Surface BLE connection state to the UI (only meaningful for WhoopBLESource).
        if let ble = source as? WhoopBLESource {
            ble.onStateChange = { [weak self] state in
                Task { @MainActor in self?.connectionState = Self.describe(state) }
            }
        }
    }

    /// Request notification permission, then start streaming and processing samples.
    public func start() async {
        _ = await alerts.requestAuthorization()
        source.start()
        connectionState = "Connecting…"

        streamTask = Task { [weak self] in
            guard let self else { return }
            for await sample in self.source.samples {
                self.engine.ingest(sample: sample)
                await MainActor.run {
                    self.currentBPM = sample.bpm
                    self.baselineBPM = self.engine.currentBaseline
                }
            }
        }
    }

    public func stop() {
        streamTask?.cancel()
        source.stop()
        connectionState = "Stopped"
    }

    /// Feed a content event (e.g. from the ReplayKit OCR extension) into the engine.
    public func ingest(content event: ContentEvent) {
        engine.ingest(content: event)
    }

    private static func describe(_ state: WhoopBLESource.State) -> String {
        switch state {
        case .poweredOff:    return "Bluetooth off"
        case .unauthorized:  return "Bluetooth not allowed"
        case .scanning:      return "Searching for band…"
        case .connecting:    return "Connecting…"
        case .connected:     return "Connected"
        case .disconnected:  return "Disconnected"
        case .noDeviceFound: return "No band found — is HR Broadcast on?"
        }
    }
}
#endif
