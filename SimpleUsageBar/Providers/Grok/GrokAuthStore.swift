// GrokAuthStore.swift
// Read-only access to Grok Build CLI credentials (~/.grok/auth.json).
// Never logs tokens; never writes the auth file.

import Foundation

public struct GrokCredentials: Sendable, Equatable {
    public var accessToken: String
    public var expiresAt: Date
    public var email: String?
    public var userId: String?
    public var teamId: String?
    public var principalType: String?
    public var authMode: String?
    public var entryKey: String

    public var isExpired: Bool {
        isExpired(at: Date())
    }

    public func isExpired(at date: Date) -> Bool {
        expiresAt <= date
    }
}

public enum GrokAuthError: Error, Equatable, LocalizedError {
    case missingFile(URL)
    case unreadable(URL)
    case invalidJSON
    case noEntries
    case expiredCredentials
    case missingToken

    public var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Grok CLI is not signed in. Run `grok login`, then Refresh."
        case .unreadable:
            return "Could not read Grok CLI credentials."
        case .invalidJSON:
            return "Grok CLI credentials file is invalid."
        case .noEntries:
            return "Grok CLI credentials are empty. Run `grok login`."
        case .expiredCredentials:
            return "CLI credentials expired. Run `grok` or `grok login` to refresh, then Refresh."
        case .missingToken:
            return "Grok CLI credentials are missing a token. Run `grok login`."
        }
    }
}

/// Resolves and parses `auth.json` produced by `grok login`.
public struct GrokAuthStore: Sendable {
    public var homeDirectory: URL
    public var environment: [String: String]
    public var fileManager: FileManager

    public init(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
        self.fileManager = fileManager
    }

    /// `$GROK_HOME/auth.json` when set, else `~/.grok/auth.json`.
    public func authFileURL() -> URL {
        if let grokHome = environment["GROK_HOME"], !grokHome.isEmpty {
            return URL(fileURLWithPath: grokHome, isDirectory: true)
                .appendingPathComponent("auth.json")
        }
        return homeDirectory
            .appendingPathComponent(".grok", isDirectory: true)
            .appendingPathComponent("auth.json")
    }

    public func loadCredentials(now: Date = Date()) throws -> GrokCredentials {
        let url = authFileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            throw GrokAuthError.missingFile(url)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GrokAuthError.unreadable(url)
        }
        return try Self.parseCredentials(data: data, now: now)
    }

    /// Pure parser for unit tests (no filesystem).
    public static func parseCredentials(data: Data, now: Date = Date()) throws -> GrokCredentials {
        let object: [String: Any]
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GrokAuthError.invalidJSON
            }
            object = json
        } catch is GrokAuthError {
            throw GrokAuthError.invalidJSON
        } catch {
            throw GrokAuthError.invalidJSON
        }

        struct Candidate {
            var preferred: Bool
            var expiresAt: Date
            var credentials: GrokCredentials
        }

        var candidates: [Candidate] = []
        var sawExpired = false

        for (entryKey, value) in object {
            guard let dict = value as? [String: Any] else { continue }
            guard let token = dict["key"] as? String, !token.isEmpty else { continue }

            let expiresAt: Date
            if let expString = dict["expires_at"] as? String,
               let parsed = Self.parseISO8601(expString) {
                expiresAt = parsed
            } else {
                // Missing/invalid expiry → treat as unusable for live fetch.
                continue
            }

            let creds = GrokCredentials(
                accessToken: token,
                expiresAt: expiresAt,
                email: dict["email"] as? String,
                userId: dict["user_id"] as? String,
                teamId: dict["team_id"] as? String,
                principalType: dict["principal_type"] as? String,
                authMode: dict["auth_mode"] as? String,
                entryKey: entryKey
            )

            if creds.isExpired(at: now) {
                sawExpired = true
                continue
            }

            let preferred = entryKey.hasPrefix("https://auth.x.ai::")
            candidates.append(Candidate(preferred: preferred, expiresAt: expiresAt, credentials: creds))
        }

        guard !candidates.isEmpty else {
            if sawExpired {
                throw GrokAuthError.expiredCredentials
            }
            if object.isEmpty {
                throw GrokAuthError.noEntries
            }
            throw GrokAuthError.missingToken
        }

        candidates.sort { lhs, rhs in
            if lhs.preferred != rhs.preferred { return lhs.preferred && !rhs.preferred }
            return lhs.expiresAt > rhs.expiresAt
        }
        return candidates[0].credentials
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: string)
    }
}
