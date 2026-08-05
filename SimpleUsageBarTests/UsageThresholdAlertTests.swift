// UsageThresholdAlertTests.swift
// Drives real UsageThresholdAlert.evaluate for 80% / 100% de-dupe and re-arm.

import XCTest
@testable import SimpleUsageBar

final class UsageThresholdAlertTests: XCTestCase {
    func testLevelsAreEightyAndHundred() {
        XCTAssertEqual(UsageThresholdAlert.levels, [80, 100])
    }

    func testCrosses80FromBelow() {
        let r = UsageThresholdAlert.evaluate(
            currentPercent: 85,
            previouslyFiredWhileAbove: []
        )
        XCTAssertEqual(r.toFire, [80])
        XCTAssertEqual(r.firedWhileAbove, [80])
    }

    func testDoesNotRefire80WhileStillAbove() {
        let r = UsageThresholdAlert.evaluate(
            currentPercent: 90,
            previouslyFiredWhileAbove: [80]
        )
        XCTAssertEqual(r.toFire, [])
        XCTAssertEqual(r.firedWhileAbove, [80])
    }

    func testCrosses100FromBelow() {
        let r = UsageThresholdAlert.evaluate(
            currentPercent: 100,
            previouslyFiredWhileAbove: [80]
        )
        XCTAssertEqual(r.toFire, [100])
        XCTAssertEqual(r.firedWhileAbove, [80, 100])
    }

    func testJumpPastBothFiresBoth() {
        let r = UsageThresholdAlert.evaluate(
            currentPercent: 100,
            previouslyFiredWhileAbove: []
        )
        XCTAssertEqual(r.toFire, [80, 100])
        XCTAssertEqual(r.firedWhileAbove, [80, 100])
    }

    func testExact80Fires() {
        let r = UsageThresholdAlert.evaluate(
            currentPercent: 80,
            previouslyFiredWhileAbove: []
        )
        XCTAssertEqual(r.toFire, [80])
    }

    func testBelow80DoesNotFire() {
        let r = UsageThresholdAlert.evaluate(
            currentPercent: 79.9,
            previouslyFiredWhileAbove: []
        )
        XCTAssertEqual(r.toFire, [])
        XCTAssertTrue(r.firedWhileAbove.isEmpty)
    }

    func testDropBelowRearmsThenRecrossFiresAgain() {
        let above = UsageThresholdAlert.evaluate(
            currentPercent: 85,
            previouslyFiredWhileAbove: []
        )
        XCTAssertEqual(above.toFire, [80])

        let below = UsageThresholdAlert.evaluate(
            currentPercent: 70,
            previouslyFiredWhileAbove: above.firedWhileAbove
        )
        XCTAssertEqual(below.toFire, [])
        XCTAssertTrue(below.firedWhileAbove.isEmpty)

        let again = UsageThresholdAlert.evaluate(
            currentPercent: 82,
            previouslyFiredWhileAbove: below.firedWhileAbove
        )
        XCTAssertEqual(again.toFire, [80])
    }

    func testDropBelow100Rearms100Only() {
        let at100 = UsageThresholdAlert.evaluate(
            currentPercent: 100,
            previouslyFiredWhileAbove: []
        )
        XCTAssertEqual(at100.firedWhileAbove, [80, 100])

        let mid = UsageThresholdAlert.evaluate(
            currentPercent: 90,
            previouslyFiredWhileAbove: at100.firedWhileAbove
        )
        XCTAssertEqual(mid.toFire, [])
        XCTAssertEqual(mid.firedWhileAbove, [80])

        let back = UsageThresholdAlert.evaluate(
            currentPercent: 100,
            previouslyFiredWhileAbove: mid.firedWhileAbove
        )
        XCTAssertEqual(back.toFire, [100])
        XCTAssertEqual(back.firedWhileAbove, [80, 100])
    }

    func testNotificationCopyUsesFormatter() {
        let body = UsageThresholdAlert.notificationBody(for: 80, usedPercent: 83.4)
        XCTAssertTrue(body.contains("83%"))
        XCTAssertTrue(body.contains("80%"))
        XCTAssertEqual(UsageThresholdAlert.notificationTitle(for: 80), "Grok usage")
    }
}
