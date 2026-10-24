//  CommunityView.swift
//  Screen 4 — Community. Peer support. Mocked data.

import SwiftUI

struct CommunityView: View {

    private struct Mentor: Identifiable {
        let id = UUID()
        let initials: String
        let name: String
        let tags: [String]
        let quote: String
    }

    private let mentors: [Mentor] = [
        Mentor(
            initials: "AL",
            name: "Alex L.",
            tags: ["Exam anxiety", "Junior year"],
            quote: "Sophomore year I could barely open my laptop without my chest tightening. Talking it through changed everything."
        ),
        Mentor(
            initials: "MT",
            name: "Maya T.",
            tags: ["Burnout", "First-gen"],
            quote: "I thought asking for help meant I was failing. It was actually the first thing that worked."
        ),
        Mentor(
            initials: "DK",
            name: "Devon K.",
            tags: ["Social anxiety", "Transfer student"],
            quote: "Moving schools wrecked me. A year later I run the thing I was too scared to walk into."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(mentors) { mentor in
                    mentorCard(mentor)
                }

                closingCard
            }
            .padding(20)
        }
        .background(Color.sageBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("You're not alone")
                .font(SageFont.serif(26, weight: .semibold))
                .foregroundColor(.sageText)
            Text("Peers who've been where you are")
                .font(SageFont.body(14))
                .foregroundColor(.sageMuted)
        }
    }

    private func mentorCard(_ mentor: Mentor) -> some View {
        SageCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text(mentor.initials)
                        .font(SageFont.body(18, weight: .semibold))
                        .foregroundColor(.sageSurface)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.sageTerracotta))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mentor.name)
                            .font(SageFont.body(17, weight: .semibold))
                            .foregroundColor(.sageText)
                        FlowTags(tags: mentor.tags)
                    }
                    Spacer()
                }

                Text("\u{201C}\(mentor.quote)\u{201D}")
                    .font(SageFont.serif(16, weight: .regular))
                    .italic()
                    .foregroundColor(.sageText)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: {}) {
                    Text("Say hello")
                        .font(SageFont.body(15, weight: .semibold))
                        .foregroundColor(.sageMoss)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().stroke(Color.sageMoss, lineWidth: 1.5)
                        )
                }
            }
        }
    }

    private var closingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Further along than you were?")
                .font(SageFont.serif(20, weight: .semibold))
                .foregroundColor(.sageSurface)

            Text("The people here helped because they'd been through it too. When you're ready, you can be that for someone else.")
                .font(SageFont.body(15))
                .foregroundColor(.sageSurface.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {}) {
                Text("Share your story")
                    .font(SageFont.body(15, weight: .semibold))
                    .foregroundColor(.sageDark)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.sageSurface))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.sageMoss))
    }
}

#Preview {
    CommunityView()
}
