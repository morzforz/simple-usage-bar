// AppModelPaceTests.swift
// Successful refresh records pace samples and updates paceOutcome.

import XCTest
@testable import SimpleUsageBar

private final class FixedSnapshotProvider: UsageProviding, @unchecked Sendable {
    let id = "grok"
    let displayName = "Grok"
    var snapshot: UsageSnapshot

    init(snapshot: UsageSnapshot) {
        self.snapshot = snapshot
    }

    func fetchUsage(now: Date) async throws -> UsageSnapshot {
        snapshot
    }
}

@MainActor
final class AppModelPaceTests: XCTestCase {
    func testSuccessfulRefreshSetsPaceFromEvaluator() async {
        // Period spans real wall-clock "now" so AppModel's Date()-based evaluate is meaningful.
        let now = Date()
        let periodStart = now.addingTimeInterval(-0.5 * 7 * 24 * 3600)
        let periodEnd = periodStart.addingTimeInterval(7 * 24 * 3600)
        // Mid-window, 70% used → ahead of even burn.
        let snapshot = UsageSnapshot(
            providerId: "grok",
            displayName: "Grok",
            usedPercent: 70,
            resetsAt: periodEnd,
            periodStart: periodStart,
            windowLabel: .weekly,
            fetchedAt: now,
            source: .billingApi
        )
        let provider = FixedSnapshotProvider(snapshot: snapshot)
        let paceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pace-model-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: paceURL) }
        let store = UsagePaceStore(fileURL: paceURL)

        let model = AppModel(
            provider: provider,
            thresholdNotifier: RecordingThresholdNotifier(),
            paceStore: store,
            refreshInterval: 3600,
            minimumRefreshInterval: 0,
            autoStart: false
        )
        defer { model.stop() }

        await model.refresh(force: true)

        XCTAssertFalse(store.allSamples().isEmpty, "refresh must record a pace sample")
        let samples = store.allSamples()
        guard let lastUsed = samples.last?.usedPercent else {
            return XCTFail("expected recorded sample after refresh")
        }
        XCTAssertEqual(lastUsed, 70, accuracy: 0.01)

        // Model must set pace via the real evaluator path after refresh.
        XCTAssertEqual(model.paceOutcome, .aheadOfPace)
        XCTAssertFalse(model.paceDisplayLine.isEmpty)
        XCTAssertTrue(model.paceDisplayLine.hasPrefix("Pace:"))
        XCTAssertTrue(model.paceDisplayLine.lowercased().contains("ahead"))
    }

    func testInsufficientWhenNoPeriodBounds() async {
        let snapshot = UsageSnapshot(
            providerId: "grok",
            displayName: "Grok",
            usedPercent: 50,
            resetsAt: nil,
            periodStart: nil,
            windowLabel: .unknown,
            source: .billingApi
        )
        let provider = FixedSnapshotProvider(snapshot: snapshot)
        let paceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pace-model2-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: paceURL) }

        let model = AppModel(
            provider: provider,
            thresholdNotifier: RecordingThresholdNotifier(),
            paceStore: UsagePaceStore(fileURL: paceURL),
            refreshInterval: 3600,
            minimumRefreshInterval: 0,
            autoStart: false
        )
        defer { model.stop() }

        await model.refresh(force: true)
        XCTAssertEqual(model.paceOutcome, .insufficientData)
        XCTAssertTrue(model.paceDisplayLine.lowercased().contains("not enough"))
    }
}
