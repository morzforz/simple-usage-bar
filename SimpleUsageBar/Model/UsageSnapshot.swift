// UsageSnapshot.swift
// Canonical usage display model for Simple Usage Bar.
// P0 uses a mock snapshot only; live providers plug in later.

import Foundation

/// How the snapshot was produced.
public enum UsageSource: String, Sendable, Equatable {
    case mock
    case billingApi
    case agentRpc
}

/// Billing window label inferred from period length (or mock).
public enum WindowLabel: String, Sendable, Equatable {
    case weekly
    case monthly
    case credits
    case unknown

    public var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .credits: return "Credits"
        case .unknown: return "Usage"
        }
    }
}

/// UI-facing usage snapshot (provider-agnostic).
public struct UsageSnapshot: Sendable, Equatable {
    public var providerId: String
    public var displayName: String
    public var usedPercent: Double
    public var resetsAt: Date?
    public var periodStart: Date?
    public var windowLabel: WindowLabel
    public var accountEmail: String?
    public var principalType: String?
    public var fetchedAt: Date
    public var source: UsageSource

    public init(
        providerId: String,
        displayName: String,
        usedPercent: Double,
        resetsAt: Date? = nil,
        periodStart: Date? = nil,
        windowLabel: WindowLabel = .unknown,
        accountEmail: String? = nil,
        principalType: String? = nil,
        fetchedAt: Date = Date(),
        source: UsageSource = .mock
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.periodStart = periodStart
        self.windowLabel = windowLabel
        self.accountEmail = accountEmail
        self.principalType = principalType
        self.fetchedAt = fetchedAt
        self.source = source
    }

    /// Fixed mock data for P0 shell (no network).
    public static func mock(
        usedPercent: Double = 43,
        now: Date = Date(),
        resetOffset: TimeInterval = 6 * 60 * 60
    ) -> UsageSnapshot {
        let periodStart = now.addingTimeInterval(-24 * 60 * 60 * 6)
        let resetsAt = now.addingTimeInterval(resetOffset)
        return UsageSnapshot(
            providerId: "grok",
            displayName: "Grok",
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            periodStart: periodStart,
            windowLabel: .weekly,
            accountEmail: "mock@example.com",
            principalType: "User",
            fetchedAt: now,
            source: .mock
        )
    }
}
