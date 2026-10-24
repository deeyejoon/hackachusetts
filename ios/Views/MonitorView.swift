//  MonitorView.swift
//  The on-device physiological-monitoring screen (the "Pulse" tab).
//
//  Shows live heart rate + baseline from PulseKit's PhysiologicalMonitor, the most
//  recent reaction's keywords, and — for demos without a WHOOP band — a button that
//  simulates a strong reaction. A simulated reaction flows through the real engine and
//  fires a real local notification, so this screen demonstrates the live-alert pipeline
//  end to end in the Simulator.
//
//  When PulseKit is not linked (e.g. a macOS build of the sources), a small placeholder
//  is shown instead so the file always compiles.

import SwiftUI

#if canImport(PulseKit)

struct SageMonitorView: View {
    @EnvironmentObject private var store: SignalStore
    @StateObject private var vm: MonitorViewModel

    /// What the user types to stand in for on-screen text the OCR path would read.
    @State private var keywordText: String = "exam results"
    @FocusState private var keywordFocused: Bool

    init(store: SignalStore? = nil) {
        _vm = StateObject(wrappedValue: MonitorViewModel(store: store ?? SignalStore()))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.sageBorder)

            ScrollView {
                VStack(spacing: 20) {
                    heartRateCard
                    if let topic = vm.lastTopic {
                        lastReactionCard(topic: topic)
                    }
                    demoCard
                }
                .padding(20)
            }
        }
        .background(Color.sageBackground.ignoresSafeArea())
        .task { await vm.start() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse")
                    .font(SageFont.serif(26, weight: .semibold))
                    .foregroundColor(.sageText)
                Text(vm.monitor.connectionState)
                    .font(SageFont.body(13))
                    .foregroundColor(.sageMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.sageBackground)
    }

    // MARK: - Cards

    private var heartRateCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "heart.fill").foregroundColor(.sageMoss)
                Text("\(Int(vm.monitor.currentBPM))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.sageText)
                Text("bpm").font(SageFont.body(18)).foregroundColor(.sageMuted)
            }
            if vm.monitor.baselineBPM > 0 {
                Text("baseline \(Int(vm.monitor.baselineBPM)) bpm")
                    .font(SageFont.body(13)).foregroundColor(.sageMuted)
            } else {
                Text("learning your baseline…")
                    .font(SageFont.body(13)).foregroundColor(.sageMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sageSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sageBorder, lineWidth: 1))
    }

    private func lastReactionCard(topic: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Latest reaction")
                .font(SageFont.body(15, weight: .semibold))
                .foregroundColor(.sageText)
            Text("Strong response around “\(topic)”.")
                .font(SageFont.body(14))
                .foregroundColor(.sageMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sageSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sageBorder, lineWidth: 1))
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyword detection (Simulator)")
                .font(SageFont.body(15, weight: .semibold))
                .foregroundColor(.sageText)
            Text("Real screen-OCR needs a physical device. In the Simulator, type the words you'd be looking at — they run through the same engine, fire a live notification, and appear in Insights.")
                .font(SageFont.body(13))
                .foregroundColor(.sageMuted)

            TextField("e.g. exam results deadline", text: $keywordText)
                .font(SageFont.body(16))
                .foregroundColor(.sageText)
                .focused($keywordFocused)
                .submitLabel(.go)
                .onSubmit(triggerDetection)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.sageBackground))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sageBorder, lineWidth: 1))

            Button(action: triggerDetection) {
                Text("Detect keywords & trigger reaction")
                    .font(SageFont.body(16, weight: .semibold))
                    .foregroundColor(.sageSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(detectEnabled ? Color.sageMoss : Color.sageMuted)
                    )
            }
            .disabled(!detectEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.sageSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sageBorder, lineWidth: 1))
    }

    private var detectEnabled: Bool {
        !keywordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func triggerDetection() {
        keywordFocused = false
        vm.simulateReaction(rawKeywords: keywordText)
    }
}

#else

/// Fallback when PulseKit isn't linked (keeps the file compiling everywhere).
struct SageMonitorView: View {
    init(store: SignalStore? = nil) {}
    var body: some View {
        Text("Monitoring requires PulseKit (iOS).")
            .foregroundColor(.sageMuted)
    }
}

#endif
