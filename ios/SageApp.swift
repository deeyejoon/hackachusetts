//  SageApp.swift
//  App entry point.

import SwiftUI

@main
struct SageApp: App {
    /// Registers the notification-center delegate so live-reaction alerts appear even
    /// while the app is in the foreground (see AppDelegate).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Single source of truth for physiological signals, shared across screens.
    /// Injected into the environment so Insights and Chat read the same data.
    /// See docs/INTEGRATION.md, Contract 2.
    @StateObject private var signalStore = SignalStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(signalStore)
        }
    }
}
