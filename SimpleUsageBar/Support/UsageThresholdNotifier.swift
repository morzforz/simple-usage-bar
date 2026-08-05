// UsageThresholdNotifier.swift
// Posts macOS user notifications for usage thresholds (permission-safe).

import Foundation
import UserNotifications

/// Thin seam so AppModel can post alerts without hard-coupling tests to UNUserNotificationCenter.
public protocol UsageThresholdNotifying: Sendable {
    /// Request authorization if needed; never throws fatally on deny.
    func prepareAuthorization() async
    /// Post a user-visible notification for a single threshold crossing.
    func notify(level: Int, usedPercent: Double) async
}

/// Production notifier using UserNotifications.
public struct UserNotificationsThresholdNotifier: UsageThresholdNotifying {
    public init() {}

    public func prepareAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        case .denied, .authorized, .provisional:
            break
        @unknown default:
            break
        }
    }

    public func notify(level: Int, usedPercent: Double) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // macOS: authorized / provisional can show notifications; denied / notDetermined skip.
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = UsageThresholdAlert.notificationTitle(for: level)
        content.body = UsageThresholdAlert.notificationBody(for: level, usedPercent: usedPercent)
        content.sound = .default

        let id = "usage-threshold-\(level)-\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await center.add(request)
    }
}

/// Test double: records calls without touching Notification Center.
public final class RecordingThresholdNotifier: UsageThresholdNotifying, @unchecked Sendable {
    public private(set) var prepareCount = 0
    public private(set) var notifications: [(level: Int, usedPercent: Double)] = []
    private let lock = NSLock()

    public init() {}

    public func prepareAuthorization() async {
        lock.lock(); prepareCount += 1; lock.unlock()
    }

    public func notify(level: Int, usedPercent: Double) async {
        lock.lock()
        notifications.append((level, usedPercent))
        lock.unlock()
    }
}
