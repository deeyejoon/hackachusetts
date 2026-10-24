//  ConnectView.swift
//  Screen 3 — Connect. Insurance-matched professional care. Mocked data.

import SwiftUI

struct ConnectView: View {

    private struct Provider: Identifiable {
        let id = UUID()
        let initials: String
        let name: String
        let credentials: String
        let tags: [String]
        let copay: String
        let sessionType: String
    }

    private let filters = ["BCBS", "Anxiety", "Virtual", "Evenings"]
    @State private var selectedFilters: Set<String> = ["BCBS", "Anxiety"]

    private let providers: [Provider] = [
        Provider(
            initials: "RM",
            name: "Dr. Rachel Mehta",
            credentials: "PhD, Licensed Psychologist",
            tags: ["Anxiety", "CBT", "Students"],
            copay: "$20 copay",
            sessionType: "Virtual or in-person"
        ),
        Provider(
            initials: "JC",
            name: "James Carter",
            credentials: "LMHC",
            tags: ["Stress", "Sleep", "Mindfulness"],
            copay: "$15 copay",
            sessionType: "Virtual"
        ),
        Provider(
            initials: "SP",
            name: "Dr. Sofia Park",
            credentials: "PsyD",
            tags: ["Depression", "Anxiety", "ACT"],
            copay: "$25 copay",
            sessionType: "In-person"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                filterChips

                ForEach(providers) { provider in
                    providerCard(provider)
                }
            }
            .padding(20)
        }
        .background(Color.sageBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Find your match")
                .font(SageFont.serif(26, weight: .semibold))
                .foregroundColor(.sageText)
            Text("In-network with Blue Cross Blue Shield · PPO")
                .font(SageFont.body(14))
                .foregroundColor(.sageMuted)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    let active = selectedFilters.contains(filter)
                    Text(filter)
                        .font(SageFont.body(14, weight: .medium))
                        .foregroundColor(active ? .sageSurface : .sageText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(active ? Color.sageMoss : Color.sageSurface)
                        )
                        .overlay(
                            Capsule().stroke(active ? Color.clear : Color.sageBorder, lineWidth: 1)
                        )
                        .onTapGesture {
                            if active { selectedFilters.remove(filter) }
                            else { selectedFilters.insert(filter) }
                        }
                }
            }
        }
    }

    private func providerCard(_ provider: Provider) -> some View {
        SageCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text(provider.initials)
                        .font(SageFont.body(18, weight: .semibold))
                        .foregroundColor(.sageSurface)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.sageMoss))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.name)
                            .font(SageFont.body(17, weight: .semibold))
                            .foregroundColor(.sageText)
                        Text(provider.credentials)
                            .font(SageFont.body(13))
                            .foregroundColor(.sageMuted)
                    }
                    Spacer()
                }

                FlowTags(tags: provider.tags)

                HStack(spacing: 14) {
                    Label(provider.copay, systemImage: "creditcard")
                    Label(provider.sessionType, systemImage: "video")
                }
                .font(SageFont.body(13))
                .foregroundColor(.sageMuted)

                Button(action: {}) {
                    Text("Request session")
                        .font(SageFont.body(15, weight: .semibold))
                        .foregroundColor(.sageSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.sageMoss))
                }
            }
        }
    }
}

/// A simple left-aligned wrapping row of tag pills.
struct FlowTags: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(SageFont.body(12, weight: .medium))
                    .foregroundColor(.sageMoss)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.sageMoss.opacity(0.12)))
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ConnectView()
}
