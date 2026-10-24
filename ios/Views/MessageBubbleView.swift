//  MessageBubbleView.swift
//  Renders a single chat bubble, switching on ChatMessage.style.

import SwiftUI

/// A rounded-rectangle bubble with one sharp "tail" corner.
///
/// User bubbles keep a sharp bottom-right corner; bot bubbles a sharp
/// bottom-left corner. Built with UIBezierPath so the corner rounding is
/// per-corner.
struct BubbleShape: Shape {
    enum Tail { case bottomLeft, bottomRight }

    var tail: Tail
    var radius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var corners: UIRectCorner = [.topLeft, .topRight]
        switch tail {
        case .bottomLeft:
            corners.insert(.bottomRight)   // sharp on bottom-left
        case .bottomRight:
            corners.insert(.bottomLeft)    // sharp on bottom-right
        }

        let bezier = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(bezier.cgPath)
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        switch message.style {
        case .normal:
            normalBubble
        case .signal:
            signalBubble
        case .crisis:
            crisisBubble
        }
    }

    // MARK: - Normal (user / assistant)

    private var isUser: Bool { message.role == .user }

    private var normalBubble: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            Text(message.text)
                .font(SageFont.body(16))
                .foregroundColor(isUser ? .sageSurface : .sageText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isUser {
                            Color.sageMoss
                        } else {
                            Color.sageSurface
                        }
                    }
                    .clipShape(BubbleShape(tail: isUser ? .bottomRight : .bottomLeft))
                )
                .overlay(
                    BubbleShape(tail: isUser ? .bottomRight : .bottomLeft)
                        .stroke(isUser ? Color.clear : Color.sageBorder, lineWidth: 1)
                )

            if !isUser { Spacer(minLength: 48) }
        }
    }

    // MARK: - Signal (passive trigger insight)

    private var signalBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(signalLabel)
                    .font(SageFont.body(11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.sageTerracotta)

                Text(message.text)
                    .font(SageFont.body(16))
                    .foregroundColor(.sageText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.sageTerracotta)
                        .frame(width: 3)
                    Color.sageSurface
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.sageBorder, lineWidth: 1)
            )

            Spacer(minLength: 48)
        }
    }

    private var signalLabel: String {
        if let ts = message.signalTimestamp {
            return "SIGNAL DETECTED · \(ts.uppercased())"
        }
        return "SIGNAL DETECTED"
    }

    // MARK: - Crisis (safety response)

    private var crisisBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(SageFont.body(16))
                    .foregroundColor(.sageSurface)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    crisisLink(title: "Call or text 988", url: "tel:988")
                    crisisLink(title: "Text HOME to 741741", url: "sms:741741&body=HOME")
                }
            }
            .padding(16)
            .background(
                Color.sageDark.clipShape(BubbleShape(tail: .bottomLeft))
            )

            Spacer(minLength: 32)
        }
    }

    private func crisisLink(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 13))
                Text(title)
                    .font(SageFont.body(15, weight: .semibold))
            }
            .foregroundColor(.sageSurface)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.sageSurface.opacity(0.4), lineWidth: 1)
            )
        }
    }
}
