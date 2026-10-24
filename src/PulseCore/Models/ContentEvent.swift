import Foundation

/// Where a piece of observed content came from.
///
/// Each case maps to one of the iOS-sanctioned capture mechanisms. The engine
/// treats them uniformly; only the resolution/trust differs.
public enum ContentSource: String, Codable, Sendable {
    /// System-level app/website usage window (DeviceActivity). App-level, automatic.
    case deviceActivity
    /// Real on-screen text recognized during a user-started screen broadcast (ReplayKit + Vision OCR).
    case screenBroadcast
    /// A post/link the user explicitly shared into the app (Share Extension).
    case shareExtension
    /// Synthetic content, used by the mock pipeline for development and demos.
    case mock
}

/// A moment of content exposure: what the user was looking at, when, and from which mechanism.
///
/// Content events are time-joined against the HR stream to determine what the user was
/// exposed to around a physiological spike.
public struct ContentEvent: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    /// Keywords extracted from the content (OCR text, shared caption, app name, etc.), lowercased.
    public let keywords: [String]
    /// The app or website the content came from, when known (e.g. "instagram", "tiktok").
    public let appName: String?
    /// Capture mechanism that produced this event.
    public let source: ContentSource
    /// When the content was on screen.
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        keywords: [String],
        appName: String? = nil,
        source: ContentSource,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.keywords = keywords.map { $0.lowercased() }
        self.appName = appName
        self.source = source
        self.timestamp = timestamp
    }
}
