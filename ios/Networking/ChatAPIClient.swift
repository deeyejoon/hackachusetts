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

/// Abstraction the view model depends on, so tests can inject a mock.
protocol ChatSending {
    func sendMessage(_ message: String, history: [ChatMessage]) async throws -> ChatResponse
}

final class ChatAPIClient: ChatSending {

    // MARK: - Configuration

    /// Base URL of the backend.
    ///
    /// - Simulator: use `http://127.0.0.1:5000`
    /// - Physical device: use your Mac's LAN IP, e.g. `http://192.168.1.42:5000`
    ///
    /// Switching environments is a one-line change here.
    static let baseURL = URL(string: "http://127.0.0.1:5000")!

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
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    // MARK: - API

    func sendMessage(_ message: String, history: [ChatMessage]) async throws -> ChatResponse {
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
        let body = RequestBody(message: message, history: turns)

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
