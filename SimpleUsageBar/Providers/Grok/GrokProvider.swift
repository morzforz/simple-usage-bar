// GrokProvider.swift
// Combines CLI auth + billing client into a UsageSnapshot.

import Foundation

public protocol UsageProviding: Sendable {
    var id: String { get }
    var displayName: String { get }
    func fetchUsage(now: Date) async throws -> UsageSnapshot
}

public struct GrokProvider: UsageProviding {
    public let id = "grok"
    public let displayName = "Grok"

    public var authStore: GrokAuthStore
    public var billingClient: GrokBillingClient

    public init(
        authStore: GrokAuthStore = GrokAuthStore(),
        billingClient: GrokBillingClient = GrokBillingClient()
    ) {
        self.authStore = authStore
        self.billingClient = billingClient
    }

    public func fetchUsage(now: Date) async throws -> UsageSnapshot {
        let credentials = try authStore.loadCredentials(now: now)
        let credits = try await billingClient.fetchCredits(credentials: credentials, now: now)
        let label = GrokCreditsProtoParser.windowLabel(
            periodStart: credits.periodStart,
            resetsAt: credits.resetsAt
        )
        return UsageSnapshot(
            providerId: id,
            displayName: displayName,
            usedPercent: credits.usedPercent,
            resetsAt: credits.resetsAt,
            periodStart: credits.periodStart,
            windowLabel: label,
            accountEmail: credentials.email,
            principalType: credentials.principalType,
            fetchedAt: now,
            source: .billingApi
        )
    }
}
