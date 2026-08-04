// AuthWatchPathsTests.swift
// Real AuthWatchPaths + DebounceGate production helpers.

import XCTest
@testable import SimpleUsageBar

final class AuthWatchPathsTests: XCTestCase {
    func testDirectoryToWatchUsesParentWhenPresent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let grok = root.appendingPathComponent(".grok", isDirectory: true)
        try FileManager.default.createDirectory(at: grok, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let auth = grok.appendingPathComponent("auth.json")
        let watched = AuthWatchPaths.directoryToWatch(authFileURL: auth)
        XCTAssertEqual(watched.standardizedFileURL, grok.standardizedFileURL)
    }

    func testDirectoryToWatchFallsBackWhenParentMissing() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let auth = home
            .appendingPathComponent(".grok", isDirectory: true)
            .appendingPathComponent("auth.json")
        // Parent `.grok` does not exist on a synthetic path without creating it.
        let watched = AuthWatchPaths.directoryToWatch(
            authFileURL: auth,
            fileManager: FileManager.default
        )
        // If .grok is missing, helper returns grandparent (home).
        XCTAssertEqual(watched.path, home.path)
    }

    func testRelevantEventNames() {
        XCTAssertTrue(AuthWatchPaths.isRelevantEventName(nil))
        XCTAssertTrue(AuthWatchPaths.isRelevantEventName("auth.json"))
        XCTAssertTrue(AuthWatchPaths.isRelevantEventName("auth.json.lock"))
        XCTAssertTrue(AuthWatchPaths.isRelevantEventName(".grok"))
        XCTAssertFalse(AuthWatchPaths.isRelevantEventName("config.toml"))
        XCTAssertFalse(AuthWatchPaths.isRelevantEventName("sessions"))
    }

    func testDebounceGateAcceptsThenBlocksWithinInterval() {
        var gate = DebounceGate(interval: 1.0)
        let t0 = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(gate.accept(now: t0))
        XCTAssertFalse(gate.accept(now: t0.addingTimeInterval(0.5)))
        XCTAssertTrue(gate.accept(now: t0.addingTimeInterval(1.0)))
    }

    func testDefaultDebounceIntervalMatchesDesign() {
        XCTAssertEqual(AuthWatchPaths.defaultDebounceInterval, 0.5, accuracy: 0.001)
    }

    func testAuthFileURLRespectsGrokHomeForWatchTarget() {
        let store = GrokAuthStore(
            homeDirectory: URL(fileURLWithPath: "/Users/u", isDirectory: true),
            environment: ["GROK_HOME": "/opt/grok"]
        )
        let auth = store.authFileURL()
        XCTAssertEqual(auth.path, "/opt/grok/auth.json")
        // Parent may not exist; directoryToWatch falls back to grandparent.
        let dir = AuthWatchPaths.directoryToWatch(authFileURL: auth)
        XCTAssertTrue(dir.path == "/opt/grok" || dir.path == "/opt")
    }
}
