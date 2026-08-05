// UsageDisplayFormatterTests.swift
// Exercises real production formatters + mock snapshot factory.

import XCTest
@testable import SimpleUsageBar

final class UsageDisplayFormatterTests: XCTestCase {
    func testMockSnapshotIncludesUsedPercentAndReset() throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let snapshot = UsageSnapshot.mock(usedPercent: 43, now: now, resetOffset: 6 * 3600)

        XCTAssertEqual(snapshot.usedPercent, 43)
        XCTAssertEqual(snapshot.source, .mock)
        XCTAssertEqual(snapshot.displayName, "Grok")
        XCTAssertEqual(snapshot.providerId, "grok")
        XCTAssertEqual(snapshot.windowLabel, .weekly)
        let resetsAt = try XCTUnwrap(snapshot.resetsAt)
        XCTAssertEqual(resetsAt.timeIntervalSince(now), 6 * 3600, accuracy: 0.001)
        XCTAssertEqual(snapshot.fetchedAt, now)
    }

    func testStatusItemTitleUsesMockPercentOnly() {
        let snapshot = UsageSnapshot.mock(usedPercent: 43)
        let title = UsageDisplayFormatter.statusItemTitle(for: snapshot)
        XCTAssertEqual(title, "43%")
        XCTAssertFalse(title.contains("G"), "brand mark is logo image, not letter G")
    }

    func testStatusItemTitleRoundsPercent() {
        let snapshot = UsageSnapshot.mock(usedPercent: 43.6)
        XCTAssertEqual(UsageDisplayFormatter.statusItemTitle(for: snapshot), "44%")
    }

    func testFormatUsedPercentClampsNegativeToZero() {
        XCTAssertEqual(UsageDisplayFormatter.formatUsedPercent(-5), "0%")
    }

    func testBarFillFractionClampsAndScales() {
        XCTAssertEqual(UsageDisplayFormatter.barFillFraction(usedPercent: 43), 0.43, accuracy: 0.0001)
        XCTAssertEqual(UsageDisplayFormatter.barFillFraction(usedPercent: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(UsageDisplayFormatter.barFillFraction(usedPercent: 100), 1, accuracy: 0.0001)
        XCTAssertEqual(UsageDisplayFormatter.barFillFraction(usedPercent: 150), 1, accuracy: 0.0001)
        XCTAssertEqual(UsageDisplayFormatter.barFillFraction(usedPercent: -10), 0, accuracy: 0.0001)
    }

    func testStatusPlaceholders() {
        XCTAssertEqual(UsageDisplayFormatter.statusPlaceholder(for: true), "…")
        XCTAssertEqual(UsageDisplayFormatter.statusPlaceholder(for: false), "—")
    }

    func testFormatResetRelativeHoursAndMinutes() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let reset = now.addingTimeInterval(5 * 3600 + 12 * 60)
        let text = UsageDisplayFormatter.formatResetRelative(reset, now: now)
        XCTAssertEqual(text, "in 5h 12m")
    }

    func testFormatResetRelativeDays() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let reset = now.addingTimeInterval(2 * 24 * 3600)
        XCTAssertEqual(UsageDisplayFormatter.formatResetRelative(reset, now: now), "in 2d")
    }

    func testFormatResetRelativePastIsNow() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let past = now.addingTimeInterval(-60)
        XCTAssertEqual(UsageDisplayFormatter.formatResetRelative(past, now: now), "now")
    }

    func testFormatResetAbsoluteMissing() {
        XCTAssertEqual(UsageDisplayFormatter.formatResetAbsolute(nil), "Unknown")
    }

    func testFormatResetAbsolutePresent() {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let text = UsageDisplayFormatter.formatResetAbsolute(
            date,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, "Unknown")
        // Fixed instant must render a deterministic POSIX/GMT string containing year 2026.
        XCTAssertTrue(text.contains("2026"), "expected year in absolute string, got: \(text)")
    }

    func testTooltipIncludesPercentAndRelativeReset() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let snapshot = UsageSnapshot.mock(usedPercent: 43, now: now, resetOffset: 6 * 3600)
        let tip = UsageDisplayFormatter.tooltip(for: snapshot, now: now)
        XCTAssertTrue(tip.contains("Grok"))
        XCTAssertTrue(tip.contains("43%"))
        XCTAssertTrue(tip.contains("in 6h"))
    }

    func testUsageBandThresholds() {
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 0), .normal)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 69.9), .normal)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 70), .elevated)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 89.9), .elevated)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 90), .high)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 150), .high)
    }

    func testWindowLabelDisplayNames() {
        XCTAssertEqual(WindowLabel.weekly.displayName, "Weekly")
        XCTAssertEqual(WindowLabel.monthly.displayName, "Monthly")
        XCTAssertEqual(WindowLabel.credits.displayName, "Credits")
        XCTAssertEqual(WindowLabel.unknown.displayName, "Usage")
    }
}
