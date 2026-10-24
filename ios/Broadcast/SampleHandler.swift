//  SampleHandler.swift
//  ReplayKit Broadcast Upload Extension entry point.
//
//  When the user starts a system screen broadcast (via the broadcast picker in the app),
//  iOS launches THIS extension in its own process and delivers screen frames here as
//  CMSampleBuffers. We forward video frames to PulseKit's `ScreenKeywordCapture`, which
//  runs Vision OCR and emits `ContentEvent`s. Each event is appended to the shared App
//  Group queue (`SharedContentLog`), which the main app drains into the CorrelationEngine.
//
//  Constraints this file respects (broadcast extensions have a hard ~50MB memory limit):
//    • ScreenKeywordCapture throttles OCR to ~1 frame/sec and runs the fast recognizer.
//    • We only touch video sample buffers; audio buffers are ignored.
//
//  There is NO silent capture: the user explicitly starts the broadcast and iOS shows a
//  persistent red recording indicator the whole time.

import ReplayKit
import PulseCore
import PulseKit

class SampleHandler: RPBroadcastSampleHandler {

    private let capture = ScreenKeywordCapture(minFrameInterval: 1.0)

    override init() {
        super.init()
        // Each recognized set of on-screen keywords becomes a ContentEvent in the shared
        // queue; the app picks it up and correlates it with heart-rate spikes.
        capture.onContent = { event in
            SharedContentLog.append(event)
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // No setup needed. The app name isn't reliably available to a broadcast extension,
        // so we leave `capture.currentAppName` nil and let keywords speak for themselves.
    }

    override func broadcastPaused() {}
    override func broadcastResumed() {}
    override func broadcastFinished() {}

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            capture.process(sampleBuffer: sampleBuffer)
        case .audioApp, .audioMic:
            break   // not used
        @unknown default:
            break
        }
    }
}
