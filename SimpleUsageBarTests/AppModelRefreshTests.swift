// AppModelRefreshTests.swift
// Proves force refresh during an in-flight fetch is not dropped (auth-watch path).

import XCTest
@testable import SimpleUsageBar

/// Controllable provider: first fetch hangs until `releaseFirst()`; tracks call count.
private final class GateProvider: UsageProviding, @unchecked Sendable {
    let id = "grok"
    let displayName = "Grok"

    private let lock = NSLock()
    private var callCount = 0
    private var firstEntered = false
    private var firstContinue: CheckedContinuation<Void, Never>?
    private var snapshots: [UsageSnapshot]

    init(snapshots: [UsageSnapshot]) {
        self.snapshots = snapshots
    }

    var fetchCount: Int {
        lock.lock(); defer { lock.unlock() }
        return callCount
    }

    func waitUntilFirstFetchStarted(timeout: TimeInterval = 2) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            lock.lock()
            let started = firstEntered
            lock.unlock()
            if started { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }

    func releaseFirst() {
        lock.lock()
        let cont = firstContinue
        firstContinue = nil
        lock.unlock()
        cont?.resume()
    }

    func fetchUsage(now: Date) async throws -> UsageSnapshot {
        lock.lock()
        callCount += 1
        let index = callCount - 1
        let isFirst = callCount == 1
        if isFirst {
            firstEntered = true
        }
        lock.unlock()

        if isFirst {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                lock.lock()
                firstContinue = cont
                lock.unlock()
            }
        }

        lock.lock()
        let snap = snapshots[min(index, snapshots.count - 1)]
        lock.unlock()
        return snap
    }
}

@MainActor
final class AppModelRefreshTests: XCTestCase {
    func testForceRefreshDuringInFlightFetchRunsAgain() async throws {
        let first = UsageSnapshot.mock(usedPercent: 10, now: Date(timeIntervalSince1970: 1_000))
        let second = UsageSnapshot.mock(usedPercent: 77, now: Date(timeIntervalSince1970: 2_000))
        let provider = GateProvider(snapshots: [first, second])

        let model = AppModel(
            provider: provider,
            refreshInterval: 60 * 60,
            minimumRefreshInterval: 0,
            autoStart: false
        )
        defer { model.stop() }

        // Start a non-force refresh that hangs inside the first fetch.
        let firstRefresh = Task { await model.refresh(force: false) }

        let started = await provider.waitUntilFirstFetchStarted()
        XCTAssertTrue(started, "first fetch should have entered provider")
        XCTAssertEqual(provider.fetchCount, 1)

        // Simulate AuthFileWatcher: force refresh while first is still in flight.
        let forceRefresh = Task { await model.refresh(force: true) }

        // Allow the coalesced waiter to attach before releasing the first fetch.
        try await Task.sleep(nanoseconds: 50_000_000)

        provider.releaseFirst()

        await firstRefresh.value
        await forceRefresh.value

        // Shipped path must perform a second fetch after the force arrived mid-flight.
        XCTAssertEqual(provider.fetchCount, 2, "force refresh during in-flight must re-fetch")
        XCTAssertEqual(model.usedPercentText, "77%")
        if case let .ready(snapshot) = model.state {
            XCTAssertEqual(snapshot.usedPercent, 77, accuracy: 0.01)
        } else {
            XCTFail("expected ready state with second snapshot, got \(model.state)")
        }
    }

    func testNonForceDuringInFlightDoesNotRequireSecondFetch() async throws {
        let only = UsageSnapshot.mock(usedPercent: 33, now: Date(timeIntervalSince1970: 1_000))
        let provider = GateProvider(snapshots: [only])

        let model = AppModel(
            provider: provider,
            refreshInterval: 60 * 60,
            minimumRefreshInterval: 0,
            autoStart: false
        )
        defer { model.stop() }

        let firstRefresh = Task { await model.refresh(force: false) }
        let startedNonForce = await provider.waitUntilFirstFetchStarted()
        XCTAssertTrue(startedNonForce, "first fetch should have entered provider")

        let second = Task { await model.refresh(force: false) }
        try await Task.sleep(nanoseconds: 50_000_000)
        provider.releaseFirst()
        await firstRefresh.value
        await second.value

        XCTAssertEqual(provider.fetchCount, 1, "non-force waiters should share one fetch")
        XCTAssertEqual(model.usedPercentText, "33%")
    }
}
