//  BroadcastButton.swift
//  SwiftUI wrapper around ReplayKit's RPSystemBroadcastPickerView.
//
//  Tapping it shows the system screen-broadcast picker, preselected to Sage's broadcast
//  extension. Starting the broadcast is what enables real on-screen keyword detection:
//  while it runs (persistent red indicator), the extension OCRs the screen and feeds
//  keywords back to the app. There is no way to start screen capture without this explicit,
//  user-initiated step — by iOS design.

import SwiftUI

#if canImport(ReplayKit) && !targetEnvironment(simulator)
import ReplayKit

struct BroadcastButton: UIViewRepresentable {
    /// Bundle id of the broadcast upload extension (app bundle id + ".Broadcast").
    let extensionBundleID: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: 52, height: 52)
        )
        picker.preferredExtension = extensionBundleID
        // Only offer OUR extension, and hide the microphone toggle (we don't use audio).
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

#else

/// On the Simulator (where ReplayKit broadcast isn't available) show a disabled stand-in
/// so the Pulse screen still builds and renders.
struct BroadcastButton: View {
    let extensionBundleID: String
    var body: some View {
        Image(systemName: "record.circle")
            .font(.system(size: 28))
            .foregroundColor(.sageMuted)
    }
}

#endif
