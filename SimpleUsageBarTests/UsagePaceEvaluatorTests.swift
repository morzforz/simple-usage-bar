// UsagePaceEvaluatorTests.swift
// Drives real UsagePaceEvaluator for insufficient vs directional outcomes.

import XCTest
@testable import SimpleUsageBar

final class UsagePaceEvaluatorTests: XCTestCase {
    private let periodStart = Date(timeIntervalSince1970: 1_700_000_000)
    private var periodEnd: Date {
        periodStart.addingTimeInterval(7 * 24 * 3600) // 7-day window
    }

    func testMissingPeriodBoundsIsInsufficient() {
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 50,
            periodStart: nil,
            resetsAt: periodEnd,
            now: periodStart.addingTimeInterval(3 * 24 * 3600)
        )
        XCTAssertEqual(estimate.outcome, .insufficientData)
        XCTAssertNil(estimate.headroomPercent, "insufficient must not invent headroom")
        XCTAssertNil(estimate.headroomDisplayLine)
        XCTAssertTrue(estimate.displayLine.lowercased().contains("not enough"))
    }

    func testEarlyWindowIsInsufficient() {
        // 1% of week elapsed, even with high used % — gate on elapsed fraction.
        let now = periodStart.addingTimeInterval(0.01 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [UsagePaceSample(usedPercent: 10, recordedAt: now, periodStart: periodStart, resetsAt: periodEnd)],
            currentUsedPercent: 10,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(estimate.outcome, .insufficientData)
        XCTAssertNil(estimate.headroomPercent)
    }

    func testLowUsedPercentIsInsufficient() {
        // Mid-window but only 1% used.
        let now = periodStart.addingTimeInterval(0.5 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 1,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(estimate.outcome, .insufficientData)
        XCTAssertNil(estimate.headroomPercent)
    }

    func testOnPaceWhenNearEvenBurn() {
        // Halfway through week, ~50% used → on pace (within 5pt band).
        let now = periodStart.addingTimeInterval(0.5 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [
                UsagePaceSample(usedPercent: 48, recordedAt: now, periodStart: periodStart, resetsAt: periodEnd),
            ],
            currentUsedPercent: 50,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(estimate.outcome, .onPace)
        XCTAssertTrue(estimate.displayLine.lowercased().contains("on track"))
        // Even burn → project to ~100% used → headroom ~0.
        XCTAssertNotNil(estimate.headroomPercent)
        XCTAssertEqual(estimate.headroomPercent!, 0, accuracy: 0.5)
    }

    func testAheadOfPaceWhenBurningFasterThanEven() {
        // Halfway through week but 70% used → ahead; projects past 100% → headroom 0.
        let now = periodStart.addingTimeInterval(0.5 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 70,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(estimate.outcome, .aheadOfPace)
        XCTAssertTrue(estimate.displayLine.lowercased().contains("ahead"))
        XCTAssertNotNil(estimate.headroomPercent)
        XCTAssertEqual(estimate.headroomPercent!, 0, accuracy: 0.01)
        XCTAssertNotNil(estimate.headroomDisplayLine)
        XCTAssertTrue(estimate.headroomDisplayLine!.lowercased().contains("headroom"))
    }

    func testBehindPaceWhenBurningSlowerThanEven() {
        // Halfway through week but only 20% used → behind even burn.
        // Projected used at reset = 20 * (1/0.5) = 40 → headroom 60.
        let now = periodStart.addingTimeInterval(0.5 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 20,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(estimate.outcome, .behindPace)
        XCTAssertTrue(estimate.displayLine.lowercased().contains("under"))
        guard let headroom = estimate.headroomPercent else {
            return XCTFail("behind-pace estimate must include headroom")
        }
        XCTAssertEqual(headroom, 60, accuracy: 0.5)
        XCTAssertEqual(estimate.headroomDisplayLine, "Headroom: ~60% unused at reset")
    }

    func testHeadroomClampsWhenProjectionExceedsPool() {
        // Mid-window, 80% used → projected 160% → headroom 0 (not negative).
        let now = periodStart.addingTimeInterval(0.5 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 80,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(estimate.outcome, .aheadOfPace)
        XCTAssertEqual(estimate.headroomPercent!, 0, accuracy: 0.01)
    }

    func testInvalidWindowIsInsufficient() {
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 50,
            periodStart: periodEnd,
            resetsAt: periodStart,
            now: periodStart.addingTimeInterval(1000)
        )
        XCTAssertEqual(estimate.outcome, .insufficientData)
        XCTAssertNil(estimate.headroomPercent)
    }

    func testEvaluateMatchesEstimateOutcome() {
        let now = periodStart.addingTimeInterval(0.5 * 7 * 24 * 3600)
        let estimate = UsagePaceEvaluator.estimate(
            samples: [],
            currentUsedPercent: 20,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        let outcome = UsagePaceEvaluator.evaluate(
            samples: [],
            currentUsedPercent: 20,
            periodStart: periodStart,
            resetsAt: periodEnd,
            now: now
        )
        XCTAssertEqual(outcome, estimate.outcome)
    }

    func testStoreRecordsAndPrunesOtherPeriods() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pace-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = UsagePaceStore(fileURL: url)
        let snap1 = UsageSnapshot(
            providerId: "grok",
            displayName: "Grok",
            usedPercent: 10,
            resetsAt: periodEnd,
            periodStart: periodStart,
            windowLabel: .weekly,
            source: .billingApi
        )
        store.record(from: snap1, at: periodStart.addingTimeInterval(86400))
        XCTAssertEqual(store.allSamples().count, 1)

        let otherStart = periodStart.addingTimeInterval(7 * 24 * 3600)
        let otherEnd = otherStart.addingTimeInterval(7 * 24 * 3600)
        let snap2 = UsageSnapshot(
            providerId: "grok",
            displayName: "Grok",
            usedPercent: 5,
            resetsAt: otherEnd,
            periodStart: otherStart,
            windowLabel: .weekly,
            source: .billingApi
        )
        store.record(from: snap2, at: otherStart.addingTimeInterval(3600))
        // New period should drop old samples.
        XCTAssertEqual(store.allSamples().count, 1)
        XCTAssertEqual(store.allSamples().first?.usedPercent, 5)
    }
}
