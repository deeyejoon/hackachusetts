//  ChatMessage.swift
//  The single message model used throughout the Chat screen.

import Foundation

struct ChatMessage: Identifiable, Equatable {
    /// Who authored the message.
    enum Role: String {
        case user
        case assistant
    }

    /// Visual + semantic treatment of the bubble.
    enum Style {
        case normal   // standard chat bubble
        case signal   // passive physiological trigger insight
        case crisis   // safety response with hotline links
    }

    let id: UUID
    let role: Role
    let text: String
    var style: Style = .normal

    /// For `.signal` messages: a human-readable time label (e.g. "2:14 PM").
    var signalTimestamp: String? = nil

    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        style: Style = .normal,
        signalTimestamp: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.style = style
        self.signalTimestamp = signalTimestamp
        self.timestamp = timestamp
    }
}
