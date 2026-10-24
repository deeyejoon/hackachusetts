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

    /// Shared physiological signals. Used to seed the passive insight card with the
    /// real latest spike, and to attach `signal_context` to the next message so Sage
    /// can gently reference it. See docs/INTEGRATION.md, Contracts 2 and 3.
    private let store: SignalStore?

    /// How many trailing messages to send to the backend as history.
    /// Keeps the payload small; the backend also trims to its own limit.
    private let historyWindow = 10

    init(client: ChatSending = ChatAPIClient(), store: SignalStore? = nil) {
        self.client = client
        self.store = store
        seed()
    }

    /// Seed the conversation so the screen has content before the user types. When a
    /// real latest signal is available, the passive insight card reflects it;
    /// otherwise we fall back to a warm generic opener.
    private func seed() {
        var seeded: [ChatMessage] = []

        if let latest = store?.latestSignal, let topic = latest.keywords.first {
            seeded.append(
                ChatMessage(
                    role: .assistant,
                    text: "Your heart rate jumped while you were looking at content about \(topic). Want to talk about what came up?",
                    style: .signal,
                    signalTimestamp: latest.timeLabel
                )
            )
        }

        seeded.append(
            ChatMessage(
                role: .assistant,
                text: "Hey, I'm Sage. How are you feeling right now?",
                style: .normal
            )
        )

        messages = seeded
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

        // Attach the most recent physiological signal (if any) so the backend can
        // fold a gentle, non-clinical note into Sage's reply. Optional + backward
        // compatible — see docs/INTEGRATION.md, Contract 3.
        let signalContext = store?.latestSignal.map { SignalContext(signal: $0) }

        isSending = true

        Task {
            defer { isSending = false }
            do {
                let response = try await client.sendMessage(text, history: history, signalContext: signalContext)
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
