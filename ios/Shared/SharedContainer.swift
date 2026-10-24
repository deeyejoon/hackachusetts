//  SharedContainer.swift
//  App Group paths shared between the Sage app and the ReplayKit broadcast extension.
//
//  The broadcast extension runs in a SEPARATE process from the app, so they cannot share
//  in-memory state. They communicate through files inside a shared App Group container:
//
//    • spike-log.json      — WeeklyReportStore's persisted spikes (written on device)
//    • content-queue.json  — keyword ContentEvents the OCR extension detects, drained
//                            by the app into the CorrelationEngine.
//
//  IMPORTANT (one-time Xcode setup): both the "Sage" app target and the broadcast
//  extension target must have the **App Groups** capability enabled with the SAME group
//  id below, under Signing & Capabilities. If the ids don't match, `containerURL` returns
//  nil and the shared files silently don't appear. See docs/DEVICE_INSTALL.md.

import Foundation

enum SharedContainer {

    /// The App Group identifier. Must match the entitlement on BOTH targets.
    /// If you change this, update ios/Sage.entitlements and ios/Broadcast/Broadcast.entitlements.
    static let appGroupID = "group.com.hackachusetts.sage"

    /// Root of the shared container, or nil if the App Group entitlement is missing/mismatched.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Shared spike log used by `WeeklyReportStore` so the app and extension agree on history.
    static var spikeLogURL: URL? {
        containerURL?.appendingPathComponent("spike-log.json")
    }

    /// Shared queue of OCR-detected content events (extension writes, app drains).
    static var contentQueueURL: URL? {
        containerURL?.appendingPathComponent("content-queue.json")
    }
}
