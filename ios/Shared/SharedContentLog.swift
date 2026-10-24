//  SharedContentLog.swift
//  A tiny append/drain queue of ContentEvents in the App Group container.
//
//  The broadcast extension (a separate process) can't call the app's CorrelationEngine
//  directly, so it `append`s each OCR-detected ContentEvent here. The app periodically
//  `drain`s the queue and feeds the events into the engine via the engine's
//  `ingest(content:)`. File access is coordinated with NSFileCoordinator because two
//  processes touch the same file.
//
//  This type is compiled into BOTH targets. It depends only on Foundation + PulseCore's
//  ContentEvent (Codable), so it builds for the extension too.

import Foundation

#if canImport(PulseCore)
import PulseCore

enum SharedContentLog {

    private static let coordinatorQueue = DispatchQueue(label: "sage.sharedcontentlog")

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Append one detected content event. Called from the broadcast extension.
    /// Keeps only the most recent `maxEvents` so the file can't grow unbounded if the
    /// app isn't draining (e.g. not running).
    static func append(_ event: ContentEvent, maxEvents: Int = 200) {
        guard let url = SharedContainer.contentQueueURL else { return }
        coordinatorQueue.sync {
            var events = readUnsafe(url)
            events.append(event)
            if events.count > maxEvents {
                events = Array(events.suffix(maxEvents))
            }
            writeUnsafe(events, to: url)
        }
    }

    /// Read and clear all queued events. Called by the app to feed the engine.
    static func drain() -> [ContentEvent] {
        guard let url = SharedContainer.contentQueueURL else { return [] }
        return coordinatorQueue.sync {
            let events = readUnsafe(url)
            if !events.isEmpty {
                writeUnsafe([], to: url)
            }
            return events
        }
    }

    // MARK: - Private (coordinated file IO)

    private static func readUnsafe(_ url: URL) -> [ContentEvent] {
        var result: [ContentEvent] = []
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            guard let data = try? Data(contentsOf: readURL),
                  let decoded = try? decoder.decode([ContentEvent].self, from: data) else { return }
            result = decoded
        }
        return result
    }

    private static func writeUnsafe(_ events: [ContentEvent], to url: URL) {
        guard let data = try? encoder.encode(events) else { return }
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            try? data.write(to: writeURL, options: .atomic)
        }
    }
}
#endif
