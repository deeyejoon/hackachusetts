//  ChatViewModel.swift
//  Owns chat state, networking orchestration, and history management.

import Foundation

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let client: ChatSending

    /// How many trailing messages to send to the backend as history.
    /// Keeps the payload small; the backend also trims to its own limit.
    private let historyWindow = 10

    init(client: ChatSending = ChatAPIClient()) {
        self.client = client
        seed()
    }

    /// Seed the conversation so the screen has content before the user types.
    private func seed() {
        messages = [
            ChatMessage(
                role: .assistant,
                text: "Your heart rate jumped while you were scrolling about exam results. Want to talk about what came up?",
                style: .signal,
                signalTimestamp: "2:14 PM"
            ),
            ChatMessage(
                role: .assistant,
                text: "Hey, I'm Sage. How are you feeling right now?",
                style: .normal
            ),
        ]
    }

    /// Send the current draft. Guards against empty input and concurrent sends.
    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        errorMessage = nil
        draft = ""

        // Optimistically append the user's message.
        let userMessage = ChatMessage(role: .user, text: text)
        messages.append(userMessage)

        // Capture the history to send (exclude UI-only seed styles and the
        // just-added message is included so the backend sees it as the turn).
        let history = historyForRequest(excluding: userMessage.id)

        isSending = true

        Task {
            defer { isSending = false }
            do {
                let response = try await client.sendMessage(text, history: history)
                let botMessage = ChatMessage(
                    role: .assistant,
                    text: response.reply,
                    style: response.crisis ? .crisis : .normal
                )
                messages.append(botMessage)
            } catch {
                handle(error)
            }
        }
    }

    /// Build the history payload: last N normal/crisis turns, excluding the
    /// seed `.signal` card (which is UI-only) and the newly added user message.
    private func historyForRequest(excluding newID: UUID) -> [ChatMessage] {
        let usable = messages.filter { $0.id != newID && $0.style != .signal }
        return Array(usable.suffix(historyWindow))
    }

    /// Translate a thrown error into a user-facing bubble + status message.
    private func handle(_ error: Error) {
        let friendly: String
        if let apiError = error as? ChatAPIError {
            switch apiError {
            case .network:
                friendly = "I can't reach the server right now. Check your connection and try again."
            case .serverError(let reason):
                friendly = "Something went wrong on the server: \(reason)"
            case .invalidResponse:
                friendly = "I got an unexpected response from the server."
            case .decodingFailed:
                friendly = "I couldn't read the server's reply."
            }
        } else {
            friendly = "Something went wrong. Please try again."
        }

        errorMessage = friendly
        // Also drop a graceful bubble into the thread so the failure is visible
        // inline rather than only in a transient banner.
        messages.append(
            ChatMessage(role: .assistant, text: friendly, style: .normal)
        )
    }
}
