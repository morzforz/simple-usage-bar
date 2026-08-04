// GrokCreditsProtoParser.swift
// Unwrap gRPC-web frames and walk reverse-engineered CreditsConfig protobuf.
// Field map is best-effort / unofficial — see docs/grok-provider.md.

import Foundation

public struct GrokCreditsParseResult: Sendable, Equatable {
    public var usedPercent: Double
    public var periodStart: Date?
    public var resetsAt: Date?
}

public enum GrokCreditsParseError: Error, Equatable, LocalizedError {
    case emptyResponse
    case invalidFrame
    case grpcStatus(Int, String)
    case missingConfig
    case parseFailed

    public var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Grok billing returned an empty response."
        case .invalidFrame:
            return "Grok billing returned an invalid gRPC-web frame."
        case let .grpcStatus(code, message):
            return "Grok billing RPC failed (\(code)): \(message)"
        case .missingConfig:
            return "Grok billing response had no credits config."
        case .parseFailed:
            return "Could not parse Grok billing usage."
        }
    }
}

public enum GrokCreditsProtoParser {
    /// Parse a full HTTP body from `GetGrokCreditsConfig`.
    public static func parseGRPCWebResponse(_ data: Data) throws -> GrokCreditsParseResult {
        guard !data.isEmpty else { throw GrokCreditsParseError.emptyResponse }

        var payload: Data?
        var trailerText = ""

        var index = 0
        while index + 5 <= data.count {
            let flags = data[index]
            let length = Int(data[index + 1]) << 24
                | Int(data[index + 2]) << 16
                | Int(data[index + 3]) << 8
                | Int(data[index + 4])
            index += 5
            guard index + length <= data.count else {
                throw GrokCreditsParseError.invalidFrame
            }
            let frame = data.subdata(in: index..<(index + length))
            index += length

            if flags & 0x80 != 0 {
                trailerText += String(data: frame, encoding: .utf8) ?? ""
            } else if payload == nil {
                payload = frame
            }
        }

        // Some responses may be raw protobuf without framing.
        if payload == nil, data.count >= 2, data[0] != 0x00, data[0] & 0x80 == 0 {
            payload = data
        }

        if !trailerText.isEmpty {
            let status = grpcStatus(from: trailerText) ?? 0
            if status != 0 {
                let message = grpcMessage(from: trailerText) ?? ""
                throw GrokCreditsParseError.grpcStatus(status, message)
            }
        }

        guard let message = payload else {
            throw GrokCreditsParseError.invalidFrame
        }

        return try parseCreditsMessage(message)
    }

    /// Parse protobuf message body (outer response or config itself).
    public static func parseCreditsMessage(_ data: Data) throws -> GrokCreditsParseResult {
        let outer = try ProtoWalker.fields(in: data)

        // Prefer outer field 1 (CreditsConfig). If the message already looks like config, use it.
        let configData: Data
        if let nested = outer.first(where: { $0.number == 1 && $0.kind == .lengthDelimited })?.bytes,
           !nested.isEmpty {
            configData = nested
        } else if outer.contains(where: { $0.number == 1 && ($0.kind == .fixed32 || $0.kind == .lengthDelimited) })
            || outer.contains(where: { $0.number == 5 }) {
            configData = data
        } else {
            throw GrokCreditsParseError.missingConfig
        }

        let fields = try ProtoWalker.fields(in: configData)

        var usedPercent: Double?
        var periodStart: Date?
        var resetsAt: Date?

        for field in fields {
            switch field.number {
            case 1:
                if let value = field.float32 {
                    usedPercent = Double(value)
                } else if let bytes = field.bytes, bytes.count == 4 {
                    usedPercent = Double(bytes.withUnsafeBytes { $0.load(as: Float.self) })
                }
            case 4:
                if let bytes = field.bytes, let date = try? parseTimestamp(bytes) {
                    periodStart = date
                }
            case 5:
                if let bytes = field.bytes, let date = try? parseTimestamp(bytes) {
                    resetsAt = date
                }
            default:
                break
            }
        }

        // Omitted percent with a valid period → 0% usage (proto3 default).
        let percent = usedPercent ?? 0
        if usedPercent == nil, periodStart == nil, resetsAt == nil {
            throw GrokCreditsParseError.parseFailed
        }

        return GrokCreditsParseResult(
            usedPercent: percent,
            periodStart: periodStart,
            resetsAt: resetsAt
        )
    }

    public static func windowLabel(periodStart: Date?, resetsAt: Date?) -> WindowLabel {
        guard let start = periodStart, let end = resetsAt else { return .unknown }
        let days = end.timeIntervalSince(start) / 86_400
        if days >= 6 && days <= 8 { return .weekly }
        if days >= 28 && days <= 32 { return .monthly }
        return .credits
    }

    // MARK: - Private

    private static func parseTimestamp(_ data: Data) throws -> Date {
        let fields = try ProtoWalker.fields(in: data)
        guard let seconds = fields.first(where: { $0.number == 1 && $0.kind == .varint })?.varint else {
            throw GrokCreditsParseError.parseFailed
        }
        // nanos optional
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private static func grpcStatus(from trailer: String) -> Int? {
        for line in trailer.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2, parts[0].lowercased() == "grpc-status", let code = Int(parts[1]) {
                return code
            }
        }
        return nil
    }

    private static func grpcMessage(from trailer: String) -> String? {
        for line in trailer.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2, parts[0].lowercased() == "grpc-message" {
                return parts[1]
            }
        }
        return nil
    }
}

// MARK: - Minimal protobuf walker

struct ProtoField {
    enum Kind {
        case varint
        case fixed64
        case lengthDelimited
        case fixed32
    }

    var number: Int
    var kind: Kind
    var varint: UInt64?
    var bytes: Data?
    var float32: Float?
}

enum ProtoWalker {
    static func fields(in data: Data) throws -> [ProtoField] {
        var result: [ProtoField] = []
        var i = 0
        let bytes = [UInt8](data)

        while i < bytes.count {
            let (key, keyLen) = try readVarint(bytes, at: i)
            i += keyLen
            let field = Int(key >> 3)
            let wire = Int(key & 0x7)

            switch wire {
            case 0:
                let (value, len) = try readVarint(bytes, at: i)
                i += len
                result.append(ProtoField(number: field, kind: .varint, varint: value, bytes: nil, float32: nil))
            case 1:
                guard i + 8 <= bytes.count else { throw GrokCreditsParseError.parseFailed }
                i += 8
                result.append(ProtoField(number: field, kind: .fixed64, varint: nil, bytes: nil, float32: nil))
            case 2:
                let (length, lenLen) = try readVarint(bytes, at: i)
                i += lenLen
                let end = i + Int(length)
                guard end <= bytes.count else { throw GrokCreditsParseError.parseFailed }
                let slice = Data(bytes[i..<end])
                i = end
                result.append(ProtoField(number: field, kind: .lengthDelimited, varint: nil, bytes: slice, float32: nil))
            case 5:
                guard i + 4 <= bytes.count else { throw GrokCreditsParseError.parseFailed }
                let slice = Data(bytes[i..<(i + 4)])
                let float = slice.withUnsafeBytes { $0.load(as: Float.self) }
                i += 4
                result.append(ProtoField(number: field, kind: .fixed32, varint: nil, bytes: slice, float32: float))
            default:
                throw GrokCreditsParseError.parseFailed
            }
        }
        return result
    }

    private static func readVarint(_ bytes: [UInt8], at start: Int) throws -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var i = start
        while i < bytes.count {
            let b = bytes[i]
            i += 1
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 {
                return (result, i - start)
            }
            shift += 7
            if shift > 63 {
                throw GrokCreditsParseError.parseFailed
            }
        }
        throw GrokCreditsParseError.parseFailed
    }
}
