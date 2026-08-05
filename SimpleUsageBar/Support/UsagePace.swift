// UsagePace.swift
// Pure directional pace estimate from billing % samples + period bounds.
// Insufficient data is an explicit outcome — never invent a forecast.

import Foundation

/// One billing snapshot observation for pace history.
public struct UsagePaceSample: Sendable, Equatable, Codable {
    public var usedPercent: Double
    public var recordedAt: Date
    public var periodStart: Date?
    public var resetsAt: Date?

    public init(
        usedPercent: Double,
        recordedAt: Date,
        periodStart: Date? = nil,
        resetsAt: Date? = nil
    ) {
        self.usedPercent = usedPercent
        self.recordedAt = recordedAt
        self.periodStart = periodStart
        self.resetsAt = resetsAt
    }
}

/// Coarse directional outcome for the current billing window.
public enum UsagePaceOutcome: Sendable, Equatable {
    /// Not enough history / window elapsed / signal to estimate.
    case insufficientData
    /// Usage tracks even burn across the period.
    case onPace
    /// Burning faster than even pace; may exhaust before reset.
    case aheadOfPace
    /// Burning slower than even pace; likely lasts until reset.
    case behindPace

    public var displayLine: String {
        switch self {
        case .insufficientData:
            return "Pace: not enough data yet"
        case .onPace:
            return "Pace: on track until reset"
        case .aheadOfPace:
            return "Pace: ahead of even burn · may run out early"
        case .behindPace:
            return "Pace: under even burn · likely lasts until reset"
        }
    }
}

/// Pure evaluator: billing-percent time series + period timing → directional pace.
public enum UsagePaceEvaluator {
    /// Minimum fraction of the billing window that must have elapsed (CodexBar-style ~3%).
    public static let minimumElapsedFraction: Double = 0.03
    /// Minimum absolute used % before we trust a pace signal.
    public static let minimumUsedPercent: Double = 3
    /// |actual − expected| below this → “on pace” (percentage points).
    public static let onPaceBandPoints: Double = 5
    /// Prefer at least this many samples; a single current snapshot still works if gates pass.
    public static let preferredMinimumSamples: Int = 1

    /// Evaluate pace from retained samples and the latest snapshot fields.
    ///
    /// Uses **even-burn** comparison: expected used% = 100 × (elapsed / window length).
    /// Actual used% from the latest observation is compared to that expectation.
    public static func evaluate(
        samples: [UsagePaceSample],
        currentUsedPercent: Double,
        periodStart: Date?,
        resetsAt: Date?,
        now: Date = Date()
    ) -> UsagePaceOutcome {
        guard let periodStart, let resetsAt else {
            return .insufficientData
        }
        let window = resetsAt.timeIntervalSince(periodStart)
        guard window > 0 else { return .insufficientData }

        let elapsed = now.timeIntervalSince(periodStart)
        guard elapsed > 0 else { return .insufficientData }

        let elapsedFraction = elapsed / window
        if elapsedFraction < minimumElapsedFraction {
            return .insufficientData
        }
        if currentUsedPercent < minimumUsedPercent {
            return .insufficientData
        }

        // Prefer latest sample in the same period when present; otherwise use current fields.
        let periodSamples = samples.filter { sample in
            sample.periodStart == periodStart && sample.resetsAt == resetsAt
        }
        if periodSamples.isEmpty && preferredMinimumSamples > 0 {
            // Current alone is OK if gates passed — still one observation of actual used%.
        }

        let expectedUsed = 100.0 * min(1.0, max(0.0, elapsedFraction))
        let delta = currentUsedPercent - expectedUsed

        if abs(delta) < onPaceBandPoints {
            return .onPace
        }
        if delta >= onPaceBandPoints {
            return .aheadOfPace
        }
        return .behindPace
    }
}
