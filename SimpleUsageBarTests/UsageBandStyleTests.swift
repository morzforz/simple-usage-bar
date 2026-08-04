// UsageBandStyleTests.swift
// Drives shipped UsageDisplayFormatter.usageBand + UsageBand style metadata.

import XCTest
@testable import SimpleUsageBar

final class UsageBandStyleTests: XCTestCase {
    func testThresholdsMatchDesign() {
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 0), .normal)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 69.9), .normal)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 70), .elevated)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 89.9), .elevated)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 90), .high)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: 100), .high)
    }

    func testSeverityOrdering() {
        XCTAssertLessThan(UsageBand.normal.severity, UsageBand.elevated.severity)
        XCTAssertLessThan(UsageBand.elevated.severity, UsageBand.high.severity)
    }

    func testStyleNamesStable() {
        XCTAssertEqual(UsageBand.normal.styleName, "normal")
        XCTAssertEqual(UsageBand.elevated.styleName, "elevated")
        XCTAssertEqual(UsageBand.high.styleName, "high")
    }

    func testBandFromSnapshot() {
        let low = UsageSnapshot.mock(usedPercent: 10)
        let mid = UsageSnapshot.mock(usedPercent: 75)
        let high = UsageSnapshot.mock(usedPercent: 95)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: low), .normal)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: mid), .elevated)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: high), .high)
        XCTAssertEqual(UsageDisplayFormatter.usageBand(for: nil as UsageSnapshot?), .normal)
    }
}
