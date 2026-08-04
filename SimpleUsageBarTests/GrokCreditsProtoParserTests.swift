// GrokCreditsProtoParserTests.swift
// Drives real GrokCreditsProtoParser against checked-in binary fixture.

import XCTest
@testable import SimpleUsageBar

final class GrokCreditsProtoParserTests: XCTestCase {
    /// Fixture values embedded when generating `get_grok_credits_config_sample.bin`.
    private let expectedPercent: Double = 43
    private let expectedStart = Date(timeIntervalSince1970: 1_785_114_061)
    private let expectedEnd = Date(timeIntervalSince1970: 1_785_718_861)

    func testParseCheckedInSampleFixture() throws {
        let data = try loadFixture("get_grok_credits_config_sample")
        let result = try GrokCreditsProtoParser.parseGRPCWebResponse(data)

        XCTAssertEqual(result.usedPercent, expectedPercent, accuracy: 0.01)
        XCTAssertEqual(result.periodStart?.timeIntervalSince1970 ?? -1, expectedStart.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(result.resetsAt?.timeIntervalSince1970 ?? -1, expectedEnd.timeIntervalSince1970, accuracy: 0.001)

        let label = GrokCreditsProtoParser.windowLabel(
            periodStart: result.periodStart,
            resetsAt: result.resetsAt
        )
        XCTAssertEqual(label, .weekly)
    }

    func testGrpcErrorStatusThrows() {
        // flags=0x80 trailer only with grpc-status:16
        let trailer = Data("grpc-status:16\r\ngrpc-message:unauthenticated\r\n".utf8)
        var body = Data([0x80])
        let len = UInt32(trailer.count).bigEndian
        withUnsafeBytes(of: len) { body.append(contentsOf: $0) }
        body.append(trailer)

        XCTAssertThrowsError(try GrokCreditsProtoParser.parseGRPCWebResponse(body)) { error in
            guard case let GrokCreditsParseError.grpcStatus(code, _) = error else {
                return XCTFail("expected grpcStatus, got \(error)")
            }
            XCTAssertEqual(code, 16)
        }
    }

    func testEmptyResponseThrows() {
        XCTAssertThrowsError(try GrokCreditsProtoParser.parseGRPCWebResponse(Data())) { error in
            XCTAssertEqual(error as? GrokCreditsParseError, .emptyResponse)
        }
    }

    func testWindowLabelMonthly() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(30 * 86_400)
        XCTAssertEqual(
            GrokCreditsProtoParser.windowLabel(periodStart: start, resetsAt: end),
            .monthly
        )
    }

    private func loadFixture(_ name: String) throws -> Data {
        let url = Bundle(for: GrokCreditsProtoParserTests.self)
            .url(forResource: name, withExtension: "bin", subdirectory: "Fixtures")
            ?? Bundle(for: GrokCreditsProtoParserTests.self)
            .url(forResource: name, withExtension: "bin")
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).bin")

        return try Data(contentsOf: url)
    }
}
