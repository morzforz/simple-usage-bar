// UsageThresholdAlert.swift
// Pure evaluation of 80% / 100% usage threshold alerts with de-dupe and re-arm.

import Foundation

/// Roadmap alert levels (distinct from color bands 70 / 90).
public enum UsageThresholdAlert {
    /// Thresholds that can produce a user notification.
    public static let levels: [Int] = [80, 100]

    /// Decide which thresholds should fire for `currentPercent`, given which
    /// levels already fired while usage remained at or above them.
    ///
    /// - Fires when usage is ≥ a level that is not yet in `previouslyFiredWhileAbove`.
    /// - Does **not** re-fire while usage stays ≥ that level.
    /// - Re-arms a level when usage drops **below** it (so a later re-cross can fire again).
    public static func evaluate(
        currentPercent: Double,
        previouslyFiredWhileAbove: Set<Int>
    ) -> (toFire: [Int], firedWhileAbove: Set<Int>) {
        var fired = previouslyFiredWhileAbove
        var toFire: [Int] = []

        for level in levels {
            let threshold = Double(level)
            if currentPercent >= threshold {
                if !fired.contains(level) {
                    toFire.append(level)
                    fired.insert(level)
                }
            } else {
                fired.remove(level)
            }
        }

        return (toFire, fired)
    }

    public static func notificationTitle(for level: Int) -> String {
        "Grok usage"
    }

    public static func notificationBody(for level: Int, usedPercent: Double) -> String {
        let shown = UsageDisplayFormatter.formatUsedPercent(usedPercent)
        if level >= 100 {
            return "Usage reached \(shown) (100% threshold)."
        }
        return "Usage reached \(shown) (\(level)% threshold)."
    }
}
