// GrokBillingClientTests.swift
// Real GrokBillingClient against injectable transport + fixture body.

import XCTest
@testable import SimpleUsageBar

private struct StubTransport: HTTPTransporting {
    var statusCode: Int
    var body: Data
    var lastRequest: URLRequest?

    init(statusCode: Int = 200, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Note: tests run single-threaded; capture via local mutation through class wrapper
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/grpc-web+proto"]
        )!
        return (body, response)
    }
}

private final class RecordingTransport: HTTPTransporting, @unchecked Sendable {
    let statusCode: Int
    let body: Data
    private(set) var lastAuthorization: String?
    private(set) var lastURL: URL?

    init(statusCode: Int = 200, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
        lastURL = request.url
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/grpc-web+proto"]
        )!
        return (body, response)
    }
}

final class GrokBillingClientTests: XCTestCase {
    func testFetchCreditsParsesFixtureAndSendsBearer() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/get_grok_credits_config_sample.bin")
        let body = try Data(contentsOf: fixtureURL)
        let transport = RecordingTransport(body: body)
        let client = GrokBillingClient(transport: transport)

        let creds = GrokCredentials(
            accessToken: "test-token",
            expiresAt: Date().addingTimeInterval(3600),
            email: "user@example.com",
            userId: nil,
            teamId: nil,
            principalType: "User",
            authMode: "oidc",
            entryKey: "https://auth.x.ai::test"
        )

        let result = try await client.fetchCredits(credentials: creds)
        XCTAssertEqual(result.usedPercent, 43, accuracy: 0.01)
        XCTAssertNotNil(result.resetsAt)
        XCTAssertEqual(transport.lastAuthorization, "Bearer test-token")
        XCTAssertEqual(
            transport.lastURL?.absoluteString,
            GrokBillingClient.defaultEndpoint.absoluteString
        )
    }

    func testHTTP401MapsToAuthRejected() async {
        let transport = RecordingTransport(statusCode: 401, body: Data())
        let client = GrokBillingClient(transport: transport)
        let creds = GrokCredentials(
            accessToken: "x",
            expiresAt: Date().addingTimeInterval(3600),
            email: nil,
            userId: nil,
            teamId: nil,
            principalType: nil,
            authMode: nil,
            entryKey: "k"
        )

        do {
            _ = try await client.fetchCredits(credentials: creds)
            XCTFail("expected throw")
        } catch let error as GrokBillingError {
            XCTAssertEqual(error, .authRejected)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
