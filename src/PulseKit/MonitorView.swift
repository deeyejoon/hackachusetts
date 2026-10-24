#if canImport(SwiftUI)
import SwiftUI
import PulseCore

/// The main screen for the physiological-response slice: live heart rate, band connection
/// status, and the weekly trigger report. Binds to a `PhysiologicalMonitor` and updates live.
///
/// Drop this into the Xcode app target. Create the monitor with a real `WhoopBLESource` for
/// device builds, or a `MockHeartRateSource` for previews/demos with no band.
@available(iOS 16.0, *)
public struct MonitorView: View {
    @StateObject private var monitor: PhysiologicalMonitor

    public init(monitor: PhysiologicalMonitor) {
        _monitor = StateObject(wrappedValue: monitor)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heartRateCard
                    if !monitor.lastSpikeKeywords.isEmpty {
                        lastReactionCard
                    }
                    weeklyReportCard
                }
                .padding()
            }
            .navigationTitle("Pulse")
            .task { await monitor.start() }
        }
    }

    // Live BPM + baseline + connection state.
    private var heartRateCard: some View {
        VStack(spacing: 8) {
            Text(monitor.connectionState)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
                Text("\(Int(monitor.currentBPM))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("bpm").font(.title3).foregroundStyle(.secondary)
            }
            if monitor.baselineBPM > 0 {
                Text("baseline \(Int(monitor.baselineBPM)) bpm")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }

    // Shows the keywords tied to the most recent spike.
    private var lastReactionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Latest reaction", systemImage: "bolt.heart")
                .font(.headline)
            Text(monitor.lastSpikeKeywords.joined(separator: ", "))
                .font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    // The weekly ranked trigger keywords.
    private var weeklyReportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("This week", systemImage: "calendar")
                .font(.headline)
            Text(monitor.latestReport.summaryLine)
                .font(.subheadline).foregroundStyle(.secondary)

            if monitor.latestReport.keywords.isEmpty {
                Text("No unusual reactions recorded yet.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(monitor.latestReport.keywords.prefix(8)) { insight in
                    HStack {
                        Text(insight.keyword).fontWeight(.medium)
                        Spacer()
                        Text("×\(insight.occurrences)")
                            .foregroundStyle(.secondary)
                        Text("+\(Int(insight.averageBpmDelta)) bpm")
                            .font(.caption).foregroundStyle(.pink)
                    }
                    .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }
}
#endif
