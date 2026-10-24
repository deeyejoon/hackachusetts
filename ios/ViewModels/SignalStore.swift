//  SignalStore.swift
//  Single source of truth for physiological signals across the app.
//
//  Both InsightsView (weekly report) and ChatViewModel (signal card seed) observe
//  this. It is injected into the environment by SageApp. See docs/INTEGRATION.md,
//  Contract 2.
//
//  Feeding it:
//   • Now (no hardware): `loadSampleData()` populates representative signals so the
//     Simulator shows a real-looking product.
//   • On device: `PulseCoreBridge` subscribes to `CorrelationEngine.onSpike` and
//     calls `record(_:)` for each real spike — no view changes required.

import Foundation
import Combine

@MainActor
final class SignalStore: ObservableObject {

    /// All signals recorded this session, oldest first.
    @Published private(set) var signals: [PhysioSignal] = []

    /// Set false before wiring real data if you want an empty store.
    init(seedWithSampleData: Bool = true) {
        if seedWithSampleData {
            loadSampleData()
        }
    }

    // MARK: - Reads (what the views consume)

    /// The most recent signal, used to seed the Chat screen's passive insight card.
    var latestSignal: PhysioSignal? { signals.last }

    /// The ranked weekly trigger report for the Insights screen.
    var weeklyReport: WeeklySignalReport { WeeklySignalReport(signals: signals) }

    // MARK: - Writes (what the engine bridge calls)

    /// Record a newly detected signal. Called by `PulseCoreBridge` on each spike.
    func record(_ signal: PhysioSignal) {
        signals.append(signal)
    }

    /// Replace all signals at once (e.g. after loading a persisted week).
    func replaceAll(_ newSignals: [PhysioSignal]) {
        signals = newSignals
    }

    // MARK: - Sample data (dev / demo, no WHOOP band)

    /// Representative signals mirroring the PulseDemo scenario, so the Insights and
    /// Chat screens are populated before real hardware is connected. Replace by
    /// wiring `PulseCoreBridge` once the Xcode target links PulseCore.
    func loadSampleData() {
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

        signals = [
            PhysioSignal(timestamp: ago(240), bpm: 92, baselineBpm: 68, zScore: 3.1,
                         keywords: ["exam", "results", "grades"], appName: "instagram"),
            PhysioSignal(timestamp: ago(180), bpm: 95, baselineBpm: 69, zScore: 3.6,
                         keywords: ["exam", "deadline"], appName: "instagram"),
            PhysioSignal(timestamp: ago(90), bpm: 88, baselineBpm: 67, zScore: 2.8,
                         keywords: ["highlight", "comparison", "vacation"], appName: "instagram"),
            PhysioSignal(timestamp: ago(30), bpm: 90, baselineBpm: 68, zScore: 3.0,
                         keywords: ["news", "politics"], appName: "safari"),
            PhysioSignal(timestamp: ago(6), bpm: 91, baselineBpm: 68, zScore: 3.2,
                         keywords: ["exam", "results"], appName: "instagram"),
        ]
    }
}
