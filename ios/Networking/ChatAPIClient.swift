//  ChatAPIClient.swift
//  URLSession wrapper for the Sage /chat endpoint.
//
//  Deliberately isolated from the view model so it can be mocked in tests via
//  the `ChatSending` protocol. Nothing here touches SwiftUI or @Published state.

import Foundation

/// Decoded response from `POST /chat`.
struct ChatResponse: Decodable {
    let reply: String
    let crisis: Bool
    let model: String
}

/// Typed failures so the view model can show distinct, friendly messages.
enum ChatAPIError: Error {
    case invalidResponse
    case serverError(String)
    case decodingFailed
    case network(Error)
}

/// Optional physiological-signal context attached to a chat turn. Mirrors the
/// backend's `signal_context` shape (snake_case keys). See docs/INTEGRATION.md,
/// Contract 3.
struct SignalContext: Encodable {
    let keywords: [String]
    let appName: String?
    let bpmDelta: Int

    enum CodingKeys: String, CodingKey {
        case keywords
        case appName = "app_name"
        case bpmDelta = "bpm_delta"
    }

    init(keywords: [String], appName: String?, bpmDelta: Int) {
        self.keywords = keywords
        self.appName = appName
        self.bpmDelta = bpmDelta
    }

    /// Convenience: build directly from a `PhysioSignal`.
    init(signal: PhysioSignal) {
        self.keywords = signal.keywords
        self.appName = signal.appName
        self.bpmDelta = Int(signal.bpmDelta.rounded())
    }
}

/// Abstraction the view model depends on, so tests can inject a mock.
protocol ChatSending {
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        signalContext: SignalContext?
    ) async throws -> ChatResponse
}

extension ChatSending {
    /// Backward-compatible overload so existing callers/tests need no changes.
    func sendMessage(_ message: String, history: [ChatMessage]) async throws -> ChatResponse {
        try await sendMessage(message, history: history, signalContext: nil)
    }
}

final class ChatAPIClient: ChatSending {

    // MARK: - Configuration

    /// Base URL of the backend.
    ///
    /// Resolution order:
    ///   1. `SAGE_BASE_URL` in Info.plist (set via project.yml / env at generate time)
    ///   2. the compiled-in default below
    ///
    /// - Simulator: the default `http://127.0.0.1:5000` works.
    /// - Physical device: a phone can't reach the Mac's loopback. Point it at the
    ///   Mac's LAN IP, e.g. `http://136.167.121.9:5000`, by setting SAGE_BASE_URL
    ///   (see docs/DEVICE_INSTALL.md) — no source edit needed.
    static let baseURL: URL = {
        if let str = Bundle.main.object(forInfoDictionaryKey: "SAGE_BASE_URL") as? String,
           !str.isEmpty,
           let url = URL(string: str) {
            return url
        }
        return URL(string: "http://127.0.0.1:5000")!
    }()

    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL = ChatAPIClient.baseURL) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - Request / response shapes

    /// Mirrors the backend's expected history entry: { role, content }.
    private struct RequestTurn: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let message: String
        let history: [RequestTurn]
        let signalContext: SignalContext?

        enum CodingKeys: String, CodingKey {
            case message
            case history
            case signalContext = "signal_context"
        }

        /// Encode `signal_context` only when present, so a request with no signal is
        /// byte-identical to the pre-integration shape. (The synthesized encoder
        /// would otherwise emit an explicit `null`.)
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(message, forKey: .message)
            try c.encode(history, forKey: .history)
            if let signalContext {
                try c.encode(signalContext, forKey: .signalContext)
            }
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    // MARK: - API

    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        signalContext: SignalContext?
    ) async throws -> ChatResponse {
        let url = baseURL.appendingPathComponent("chat")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Map local messages to the backend's { role, content } turns.
        // Signal/crisis seed messages are UI-only and are not sent as history.
        let turns = history.map {
            RequestTurn(role: $0.role.rawValue, content: $0.text)
        }
        let body = RequestBody(message: message, history: turns, signalContext: signalContext)

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw ChatAPIError.decodingFailed
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ChatAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            // Try to surface the backend's { "error": ... } message.
            if let errBody = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw ChatAPIError.serverError(errBody.error)
            }
            throw ChatAPIError.serverError("Server returned status \(http.statusCode).")
        }

        do {
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw ChatAPIError.decodingFailed
        }
    }
}
