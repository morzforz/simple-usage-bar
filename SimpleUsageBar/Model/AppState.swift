// AppState.swift
// UI-facing load state for menubar + popover.

import Foundation

public enum AppState: Sendable, Equatable {
    case loading
    case ready(UsageSnapshot)
    case unauthenticated(String)
    case error(String)
    case stale(UsageSnapshot, String)
    case teamUnsupported

    public var snapshot: UsageSnapshot? {
        switch self {
        case let .ready(s), let .stale(s, _):
            return s
        default:
            return nil
        }
    }

    public var statusMessage: String? {
        switch self {
        case .loading:
            return nil
        case .ready:
            return nil
        case let .unauthenticated(message):
            return message
        case let .error(message):
            return message
        case let .stale(_, message):
            return message
        case .teamUnsupported:
            return "Team usage is not available from this billing surface yet."
        }
    }
}
