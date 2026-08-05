// UsageDisplayFormatter.swift
// Pure formatting helpers for menubar title and popover copy.
// Unit-tested without AppKit/SwiftUI.

import Foundation

public enum UsageDisplayFormatter {
    /// Menubar percent label only (brand mark is a logo image, not the letter G).
    public static func statusItemTitle(for snapshot: UsageSnapshot) -> String {
        formatUsedPercent(snapshot.usedPercent)
    }

    /// Whole-number used percent with a trailing % sign.
    public static func formatUsedPercent(_ value: Double) -> String {
        let clamped = max(0, value)
        let rounded = Int(clamped.rounded())
        return "\(rounded)%"
    }

    /// Fill fraction for a horizontal usage bar, clamped to 0…1.
    public static func barFillFraction(usedPercent: Double) -> Double {
        min(1, max(0, usedPercent / 100))
    }

    /// Placeholder percent text for non-ready menubar states.
    public static func statusPlaceholder(for loading: Bool) -> String {
        loading ? "…" : "—"
    }

    /// Absolute local date/time for reset, or a placeholder when missing.
    public static func formatResetAbsolute(
        _ date: Date?,
        now: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        guard let date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Relative countdown to reset, e.g. "in 5h 12m" / "in 3d" / "now".
    public static func formatResetRelative(
        _ date: Date?,
        now: Date = Date()
    ) -> String {
        guard let date else { return "unknown" }
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 {
            return "now"
        }
        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            if hours > 0 {
                return "in \(days)d \(hours)h"
            }
            return "in \(days)d"
        }
        if hours > 0 {
            if minutes > 0 {
                return "in \(hours)h \(minutes)m"
            }
            return "in \(hours)h"
        }
        if minutes > 0 {
            return "in \(minutes)m"
        }
        return "in <1m"
    }

    /// Tooltip-style summary line.
    public static func tooltip(for snapshot: UsageSnapshot, now: Date = Date()) -> String {
        let percent = formatUsedPercent(snapshot.usedPercent)
        let relative = formatResetRelative(snapshot.resetsAt, now: now)
        return "\(snapshot.displayName) · \(percent) used · resets \(relative)"
    }

    /// Color band for used percent (thresholds from design doc).
    public static func usageBand(for usedPercent: Double) -> UsageBand {
        if usedPercent >= 90 { return .high }
        if usedPercent >= 70 { return .elevated }
        return .normal
    }
}

public enum UsageBand: String, Sendable, Equatable {
    case normal
    case elevated
    case high
}
