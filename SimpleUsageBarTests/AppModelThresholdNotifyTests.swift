// AppModelThresholdNotifyTests.swift
// Proves successful refresh evaluates thresholds and calls the real notifier path.

import XCTest
@testable import SimpleUsageBar

private final class ClassSequenceProvider: UsageProviding, @unchecked Sendable {
    let id = "grok"
    let displayName = "Grok"
    private let percents: [Double]
    private var index = 0
    private let lock = NSLock()

    init(percents: [Double]) {
        self.percents = percents
    }

    func fetchUsage(now: Date) async throws -> UsageSnapshot {
        lock.lock()
        let i = min(index, percents.count - 1)
        index += 1
        let p = percents[i]
        lock.unlock()
        return UsageSnapshot.mock(usedPercent: p, now: now)
    }
}

@MainActor
final class AppModelThresholdNotifyTests: XCTestCase {
    func testSuccessfulRefreshNotifiesOn80ThenNotAgainUntilRearm() async {
        let provider = ClassSequenceProvider(percents: [70, 85, 90, 50, 82])
        let recorder = RecordingThresholdNotifier()
        let model = AppModel(
            provider: provider,
            thresholdNotifier: recorder,
            refreshInterval: 3600,
            minimumRefreshInterval: 0,
            autoStart: false
        )
        defer { model.stop() }

        await model.refresh(force: true) // 70 — no fire
        XCTAssertEqual(recorder.notifications.count, 0)

        await model.refresh(force: true) // 85 — fire 80
        XCTAssertEqual(recorder.notifications.map(\.level), [80])
        XCTAssertEqual(recorder.prepareCount, 1)

        await model.refresh(force: true) // 90 — no re-fire
        XCTAssertEqual(recorder.notifications.map(\.level), [80])

        await model.refresh(force: true) // 50 — re-arm
        XCTAssertEqual(recorder.notifications.map(\.level), [80])

        await model.refresh(force: true) // 82 — fire 80 again
        XCTAssertEqual(recorder.notifications.map(\.level), [80, 80])
    }

    func testSuccessfulRefreshNotifies100() async {
        let provider = ClassSequenceProvider(percents: [95, 100])
        let recorder = RecordingThresholdNotifier()
        let model = AppModel(
            provider: provider,
            thresholdNotifier: recorder,
            refreshInterval: 3600,
            minimumRefreshInterval: 0,
            autoStart: false
        )
        defer { model.stop() }

        await model.refresh(force: true) // 95 → 80 only
        XCTAssertEqual(recorder.notifications.map(\.level), [80])

        await model.refresh(force: true) // 100 → 100
        XCTAssertEqual(recorder.notifications.map(\.level), [80, 100])
    }
}
