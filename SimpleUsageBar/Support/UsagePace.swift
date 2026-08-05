// UsagePace.swift
// Pure directional pace estimate + optional headroom from billing % samples + period bounds.
// Insufficient data is an explicit outcome — never invent a forecast or headroom.

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

/// Combined directional pace + optional projected headroom (unused % at reset).
public struct UsagePaceEstimate: Sendable, Equatable {
    public var outcome: UsagePaceOutcome
    /// Projected unused pool percent at reset if average burn continues; nil when insufficient.
    /// Clamped to 0…100.
    public var headroomPercent: Double?

    public init(outcome: UsagePaceOutcome, headroomPercent: Double? = nil) {
        self.outcome = outcome
        self.headroomPercent = headroomPercent
    }

    public var displayLine: String {
        outcome.displayLine
    }

    /// Secondary line for popover when headroom is available; nil when insufficient.
    public var headroomDisplayLine: String? {
        guard let headroomPercent else { return nil }
        let rounded = Int(headroomPercent.rounded())
        return "Headroom: ~\(rounded)% unused at reset"
    }
}

/// Pure evaluator: billing-percent time series + period timing → directional pace (+ headroom).
public enum UsagePaceEvaluator {
    /// Minimum fraction of the billing window that must have elapsed (CodexBar-style ~3%).
    public static let minimumElapsedFraction: Double = 0.03
    /// Minimum absolute used % before we trust a pace signal.
    public static let minimumUsedPercent: Double = 3
    /// |actual − expected| below this → “on pace” (percentage points).
    public static let onPaceBandPoints: Double = 5
    /// Prefer at least this many samples; a single current snapshot still works if gates pass.
    public static let preferredMinimumSamples: Int = 1

    /// Full estimate: directional outcome + optional headroom when data is sufficient.
    ///
    /// Headroom = projected unused % at reset if current average burn (used% / elapsed)
    /// continues: `max(0, 100 − min(100, used × window/elapsed))`.
    public static func estimate(
        samples: [UsagePaceSample],
        currentUsedPercent: Double,
        periodStart: Date?,
        resetsAt: Date?,
        now: Date = Date()
    ) -> UsagePaceEstimate {
        guard let periodStart, let resetsAt else {
            return UsagePaceEstimate(outcome: .insufficientData)
        }
        let window = resetsAt.timeIntervalSince(periodStart)
        guard window > 0 else {
            return UsagePaceEstimate(outcome: .insufficientData)
        }

        let elapsed = now.timeIntervalSince(periodStart)
        guard elapsed > 0 else {
            return UsagePaceEstimate(outcome: .insufficientData)
        }

        let elapsedFraction = elapsed / window
        if elapsedFraction < minimumElapsedFraction {
            return UsagePaceEstimate(outcome: .insufficientData)
        }
        if currentUsedPercent < minimumUsedPercent {
            return UsagePaceEstimate(outcome: .insufficientData)
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

        let outcome: UsagePaceOutcome
        if abs(delta) < onPaceBandPoints {
            outcome = .onPace
        } else if delta >= onPaceBandPoints {
            outcome = .aheadOfPace
        } else {
            outcome = .behindPace
        }

        let projectedUsedAtReset = currentUsedPercent * (window / elapsed)
        let clampedProjected = min(100.0, max(0.0, projectedUsedAtReset))
        let headroom = max(0.0, 100.0 - clampedProjected)

        return UsagePaceEstimate(outcome: outcome, headroomPercent: headroom)
    }

    /// Directional outcome only (same gates as `estimate`).
    public static func evaluate(
        samples: [UsagePaceSample],
        currentUsedPercent: Double,
        periodStart: Date?,
        resetsAt: Date?,
        now: Date = Date()
    ) -> UsagePaceOutcome {
        estimate(
            samples: samples,
            currentUsedPercent: currentUsedPercent,
            periodStart: periodStart,
            resetsAt: resetsAt,
            now: now
        ).outcome
    }
}
