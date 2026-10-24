//  AppDelegate.swift
//  Minimal app delegate whose only job is to present local notifications while the
//  app is in the FOREGROUND.
//
//  By default iOS silently withholds a notification if the target app is already
//  frontmost — which is exactly the situation during a live demo. Implementing
//  `userNotificationCenter(_:willPresent:)` and returning `.banner`/`.sound` tells the
//  system to show it anyway, so a simulated or real spike produces a visible alert even
//  while the user is looking at the app.

import Foundation
import UserNotifications
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Present banners (and play sound) even when the app is frontmost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
