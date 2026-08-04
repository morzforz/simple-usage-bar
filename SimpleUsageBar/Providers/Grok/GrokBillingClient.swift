// GrokBillingClient.swift
// CLI-bearer fetch of GetGrokCreditsConfig (no browser cookies).

import Foundation

public enum GrokBillingError: Error, Equatable, LocalizedError {
    case httpStatus(Int, String)
    case authRejected
    case teamUsageUnsupported
    case network(String)
    case parse(GrokCreditsParseError)

    public var errorDescription: String? {
        switch self {
        case let .httpStatus(code, body):
            return "Grok billing request failed (HTTP \(code)): \(body)"
        case .authRejected:
            return "Grok billing rejected credentials. Run `grok login` to refresh."
        case .teamUsageUnsupported:
            return "Team usage is not available from this billing surface yet."
        case let .network(message):
            return "Could not reach Grok billing: \(message)"
        case let .parse(error):
            return error.errorDescription
        }
    }
}

/// Minimal HTTP surface so tests can inject responses.
public protocol HTTPTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransporting {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

public struct GrokBillingClient: Sendable {
    public static let defaultEndpoint = URL(
        string: "https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig"
    )!

    public var endpoint: URL
    public var transport: any HTTPTransporting
    public var userAgent: String

    public init(
        endpoint: URL = GrokBillingClient.defaultEndpoint,
        transport: any HTTPTransporting = URLSessionHTTPTransport(),
        userAgent: String = "SimpleUsageBar/0.1.0"
    ) {
        self.endpoint = endpoint
        self.transport = transport
        self.userAgent = userAgent
    }

    public func fetchCredits(
        credentials: GrokCredentials,
        now: Date = Date()
    ) async throws -> GrokCreditsParseResult {
        if credentials.isExpired(at: now) {
            throw GrokBillingError.authRejected
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        // Empty protobuf framed as gRPC-web data frame.
        request.httpBody = Data([0x00, 0x00, 0x00, 0x00, 0x00])
        request.setValue("application/grpc-web+proto", forHTTPHeaderField: "Content-Type")
        request.setValue("application/grpc-web+proto", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "x-grpc-web")
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("https://grok.com", forHTTPHeaderField: "Origin")
        request.setValue("https://grok.com/?_s=usage", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw GrokBillingError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GrokBillingError.network("Invalid response type")
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw GrokBillingError.authRejected
        }
        guard http.statusCode == 200 else {
            let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw GrokBillingError.httpStatus(http.statusCode, body)
        }

        do {
            return try GrokCreditsProtoParser.parseGRPCWebResponse(data)
        } catch let error as GrokCreditsParseError {
            if case let .grpcStatus(code, message) = error {
                if code == 16 {
                    throw GrokBillingError.authRejected
                }
                if code == 7 {
                    let lower = message.lowercased()
                    if lower.contains("unauthenticated")
                        || lower.contains("bad-credentials")
                        || lower.contains("expired")
                        || lower.contains("could not be validated") {
                        throw GrokBillingError.authRejected
                    }
                    if credentials.principalType?.caseInsensitiveCompare("Team") == .orderedSame {
                        throw GrokBillingError.teamUsageUnsupported
                    }
                }
            }
            throw GrokBillingError.parse(error)
        }
    }
}
