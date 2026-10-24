//  InsightsView.swift
//  Screen 2 — Insights. Mocked data.

import SwiftUI

struct InsightsView: View {

    // MARK: - Mock data

    private struct Emotion: Identifiable {
        let id = UUID()
        let name: String
        let percent: Int
        let color: Color
    }

    private let emotions: [Emotion] = [
        Emotion(name: "Anxious", percent: 34, color: .sageTerracotta),
        Emotion(name: "Hopeful", percent: 27, color: .sageMoss),
        Emotion(name: "Tired", percent: 21, color: .sageMuted),
        Emotion(name: "Calm", percent: 18, color: Color(hex: 0x8AA5C2)),
    ]

    private struct Signal: Identifiable {
        let id = UUID()
        let category: String
        let detail: String
        let count: Int
    }

    private let signals: [Signal] = [
        Signal(category: "Academic pressure", detail: "Heart rate spiked around exam-result posts", count: 5),
        Signal(category: "Social comparison", detail: "Elevated readings while scrolling highlight reels", count: 3),
        Signal(category: "Late-night news", detail: "Sustained spikes after 11 PM feeds", count: 2),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                emotionsCard

                signalsCard

                patternCard
            }
            .padding(20)
        }
        .background(Color.sageBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your week, in feelings")
                .font(SageFont.serif(26, weight: .semibold))
                .foregroundColor(.sageText)
            Text("Oct 18 – Oct 24")
                .font(SageFont.body(14))
                .foregroundColor(.sageMuted)
        }
    }

    // MARK: - Card 1: emotions

    private var emotionsCard: some View {
        SageCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("How you felt")
                    .font(SageFont.body(17, weight: .semibold))
                    .foregroundColor(.sageText)

                ForEach(emotions) { emotion in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(emotion.name)
                                .font(SageFont.body(15))
                                .foregroundColor(.sageText)
                            Spacer()
                            Text("\(emotion.percent)%")
                                .font(SageFont.body(15, weight: .semibold))
                                .foregroundColor(.sageMuted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.sageBorder.opacity(0.6))
                                Capsule()
                                    .fill(emotion.color)
                                    .frame(width: geo.size.width * CGFloat(emotion.percent) / 100.0)
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
        }
    }

    // MARK: - Card 2: signals

    private var signalsCard: some View {
        SageCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Signals this week")
                    .font(SageFont.body(17, weight: .semibold))
                    .foregroundColor(.sageText)

                ForEach(signals) { signal in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(signal.category)
                                .font(SageFont.body(15, weight: .semibold))
                                .foregroundColor(.sageText)
                            Text(signal.detail)
                                .font(SageFont.body(13))
                                .foregroundColor(.sageMuted)
                        }
                        Spacer()
                        Text("\(signal.count)")
                            .font(SageFont.body(13, weight: .semibold))
                            .foregroundColor(.sageSurface)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.sageTerracotta))
                    }
                }

                Text("Based on your watch's heart rate data and the trigger categories you've flagged. Nothing here leaves your device unless you choose to share it.")
                    .font(SageFont.body(12))
                    .foregroundColor(.sageMuted)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Card 3: pattern (dark)

    private var patternCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pattern noticed")
                .font(SageFont.body(13, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.sageTerracotta)

            Text("Your anxious moments cluster on Sunday nights, right before the week starts. Want to set a gentle check-in for then?")
                .font(SageFont.body(17))
                .foregroundColor(.sageSurface)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {}) {
                Text("Set a Sunday check-in")
                    .font(SageFont.body(15, weight: .semibold))
                    .foregroundColor(.sageDark)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.sageSurface))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.sageDark))
    }
}

/// Shared white card container for the mocked screens.
struct SageCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.sageSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.sageBorder, lineWidth: 1)
            )
    }
}

#Preview {
    InsightsView()
}
