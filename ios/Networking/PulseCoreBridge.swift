//  PulseCoreBridge.swift
//  The seam between the PulseCore engine and the app's SignalStore.
//
//  See docs/INTEGRATION.md, Contract 1. This file is intentionally inert until the
//  Xcode app target adds PulseCore (the Swift Package in `Sources/`) as a local
//  dependency. The `#if canImport(PulseCore)` guard means:
//
//   • Before linking PulseCore: this file compiles to (almost) nothing, and the app
//     runs on `SignalStore`'s sample data.
//   • After linking PulseCore: the real bridge activates and converts each
//     `SpikeEvent` the engine emits into a `PhysioSignal` the UI already understands.
//     No view or view-model changes are needed.
//
//  To activate (one-time, after adding the package in Xcode):
//    1. File → Add Package Dependencies… → Add Local… → pick the repo root.
//    2. Add the PulseCore product (and PulseKit for on-device BLE/OCR/alerts).
//    3. That's it — `canImport(PulseCore)` becomes true and this bridge compiles in.

import Foundation

#if canImport(PulseCore)
import PulseCore

/// Converts PulseCore `SpikeEvent`s into app-side `PhysioSignal`s and forwards them
/// into the `SignalStore`. Also the place to attach a live heart-rate source.
@MainActor
final class PulseCoreBridge {

    private let store: SignalStore
    private let engine: CorrelationEngine

    /// - Parameters:
    ///   - store: the app's shared signal store to feed.
    ///   - engine: a configured CorrelationEngine. Defaults to engine defaults.
    init(store: SignalStore, engine: CorrelationEngine = CorrelationEngine()) {
        self.store = store
        self.engine = engine

        // Every spike the engine detects becomes a PhysioSignal in the store.
        engine.onSpike = { [weak store] spike in
            let signal = PulseCoreBridge.signal(from: spike)
            Task { @MainActor in store?.record(signal) }
        }
    }

    /// Start streaming from a heart-rate source into the engine.
    ///
    /// Pass a `MockHeartRateSource` for demos, or (in the PulseKit layer) a
    /// `WhoopBLESource` for a real band. Content events from ScreenKeywordCapture
    /// should be fed via `engine.ingest(content:)` separately.
    func start(source: HeartRateSource) {
        let engine = self.engine
        Task {
            for await sample in source.samples {
                engine.ingest(sample: sample)
            }
        }
        source.start()
    }

    /// Forward a content exposure (e.g. from ScreenKeywordCapture) to the engine so
    /// it can be time-joined to spikes.
    func ingest(content event: ContentEvent) {
        engine.ingest(content: event)
    }

    /// Map an engine `SpikeEvent` to the app's `PhysioSignal`. The first correlated
    /// content event supplies keywords + app name (the likeliest trigger).
    static func signal(from spike: SpikeEvent) -> PhysioSignal {
        let keywords = spike.correlatedContent.flatMap { $0.keywords }
        let appName = spike.correlatedContent.first?.appName
        return PhysioSignal(
            id: spike.id,
            timestamp: spike.timestamp,
            bpm: spike.bpm,
            baselineBpm: spike.baselineBpm,
            zScore: spike.zScore,
            keywords: keywords,
            appName: appName
        )
    }
}

#endif
