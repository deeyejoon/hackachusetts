#if canImport(Vision) && canImport(ReplayKit)
import Foundation
import Vision
import CoreMedia
import PulseCore

/// Extracts real on-screen keywords from screen-capture frames using Vision OCR, and emits
/// them as `ContentEvent`s for the CorrelationEngine. This replaces PulseDemo's hardcoded
/// `["whiskey","bar"]` feed with text actually read off the user's screen.
///
/// Designed to run inside a ReplayKit **Broadcast Upload Extension** (`RPBroadcastSampleHandler`):
/// the extension forwards each video sample buffer to `process(sampleBuffer:)`. Because broadcast
/// extensions have a hard ~50MB memory limit, this class:
///   • throttles OCR to at most one frame every `minFrameInterval` seconds, and
///   • runs a fast recognition level,
/// so it won't get killed by Jetsam.
///
/// The user explicitly starts the broadcast (system picker + persistent red indicator); there is
/// no silent/background capture on iOS, and this class does not attempt one.
public final class ScreenKeywordCapture {

    /// Called with a content event whenever meaningful text is recognized. Wire to
    /// `CorrelationEngine.ingest(content:)`.
    public var onContent: ((ContentEvent) -> Void)?

    /// App currently being broadcast, if known (set by the host when available).
    public var currentAppName: String?

    private let minFrameInterval: TimeInterval
    private var lastProcessed = Date.distantPast
    private let minConfidence: Float
    private let maxKeywords: Int

    public init(minFrameInterval: TimeInterval = 1.0,
                minConfidence: Float = 0.4,
                maxKeywords: Int = 12) {
        self.minFrameInterval = minFrameInterval
        self.minConfidence = minConfidence
        self.maxKeywords = maxKeywords
    }

    /// Feed one screen-capture frame. Throttled; OCR runs off the caller's thread.
    public func process(sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) >= minFrameInterval else { return }
        lastProcessed = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        recognizeText(in: pixelBuffer, at: now)
    }

    private func recognizeText(in pixelBuffer: CVPixelBuffer, at timestamp: Date) {
        let request = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let keywords = Self.extractKeywords(
                from: observations,
                minConfidence: self.minConfidence,
                limit: self.maxKeywords
            )
            guard !keywords.isEmpty else { return }

            let event = ContentEvent(
                keywords: keywords,
                appName: self.currentAppName,
                source: .screenBroadcast,
                timestamp: timestamp
            )
            self.onContent?(event)
        }
        request.recognitionLevel = .fast          // low memory, fast enough for keyword gist
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    /// Turn recognized text lines into a de-duplicated keyword list: split into words,
    /// lowercase, drop very short tokens and common stop-words.
    static func extractKeywords(from observations: [VNRecognizedTextObservation],
                                minConfidence: Float,
                                limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for obs in observations {
            guard let candidate = obs.topCandidates(1).first,
                  candidate.confidence >= minConfidence else { continue }
            let words = candidate.string
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)

            for word in words {
                guard word.count >= 3, !Self.stopWords.contains(word) else { continue }
                if seen.insert(word).inserted {
                    result.append(word)
                    if result.count >= limit { return result }
                }
            }
        }
        return result
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "you", "your", "with", "this", "that", "are",
        "was", "were", "from", "have", "has", "had", "but", "not", "all",
        "can", "will", "just", "out", "get", "got", "now", "new", "see"
    ]
}
#endif
