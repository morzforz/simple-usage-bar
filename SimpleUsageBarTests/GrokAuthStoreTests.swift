// GrokAuthStoreTests.swift
// Exercises real GrokAuthStore.parseCredentials / authFileURL.

import XCTest
@testable import SimpleUsageBar

final class GrokAuthStoreTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-08-03T12:00:00Z")!

    func testAuthFileURLUsesGrokHomeWhenSet() {
        let home = URL(fileURLWithPath: "/tmp/fake-home", isDirectory: true)
        let store = GrokAuthStore(
            homeDirectory: home,
            environment: ["GROK_HOME": "/custom/grok-home"]
        )
        XCTAssertEqual(
            store.authFileURL().path,
            "/custom/grok-home/auth.json"
        )
    }

    func testAuthFileURLDefaultsToDotGrok() {
        let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
        let store = GrokAuthStore(homeDirectory: home, environment: [:])
        XCTAssertEqual(store.authFileURL().path, "/Users/test/.grok/auth.json")
    }

    func testMissingFileThrows() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = GrokAuthStore(
            homeDirectory: dir,
            environment: [:]
        )
        XCTAssertThrowsError(try store.loadCredentials(now: now)) { error in
            guard case GrokAuthError.missingFile = error else {
                return XCTFail("expected missingFile, got \(error)")
            }
        }
    }

    func testValidPreferredOIDCEntrySelected() throws {
        let json = """
        {
          "https://accounts.x.ai/sign-in": {
            "key": "legacy-token",
            "expires_at": "2026-08-04T00:00:00Z",
            "email": "legacy@example.com"
          },
          "https://auth.x.ai::client-id": {
            "key": "preferred-token",
            "expires_at": "2026-08-05T00:00:00Z",
            "email": "user@example.com",
            "principal_type": "User",
            "auth_mode": "oidc"
          }
        }
        """.data(using: .utf8)!

        let creds = try GrokAuthStore.parseCredentials(data: json, now: now)
        XCTAssertEqual(creds.accessToken, "preferred-token")
        XCTAssertEqual(creds.email, "user@example.com")
        XCTAssertEqual(creds.principalType, "User")
        XCTAssertTrue(creds.entryKey.hasPrefix("https://auth.x.ai::"))
        XCTAssertFalse(creds.isExpired(at: now))
    }

    func testExpiredTokenThrowsExpiredCredentials() {
        let json = """
        {
          "https://auth.x.ai::client-id": {
            "key": "old-token",
            "expires_at": "2026-08-01T00:00:00Z",
            "email": "user@example.com"
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try GrokAuthStore.parseCredentials(data: json, now: now)) { error in
            XCTAssertEqual(error as? GrokAuthError, .expiredCredentials)
        }
    }

    func testInvalidJSONThrows() {
        let data = Data("not-json".utf8)
        XCTAssertThrowsError(try GrokAuthStore.parseCredentials(data: data, now: now)) { error in
            XCTAssertEqual(error as? GrokAuthError, .invalidJSON)
        }
    }

    func testEmptyObjectThrowsNoEntries() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(try GrokAuthStore.parseCredentials(data: data, now: now)) { error in
            XCTAssertEqual(error as? GrokAuthError, .noEntries)
        }
    }

    func testLoadCredentialsFromTempFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let grokDir = dir.appendingPathComponent(".grok", isDirectory: true)
        try FileManager.default.createDirectory(at: grokDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let json = """
        {
          "https://auth.x.ai::abc": {
            "key": "file-token",
            "expires_at": "2026-12-01T00:00:00Z",
            "email": "file@example.com",
            "principal_type": "User"
          }
        }
        """
        try json.write(to: grokDir.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        let store = GrokAuthStore(homeDirectory: dir, environment: [:])
        let creds = try store.loadCredentials(now: now)
        XCTAssertEqual(creds.accessToken, "file-token")
        XCTAssertEqual(creds.email, "file@example.com")
    }
}
