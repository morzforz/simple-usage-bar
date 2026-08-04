// UsageBandStyle.swift
// Shared presentation metadata for usage color bands (tests + SwiftUI).

import Foundation
import SwiftUI

public extension UsageBand {
    /// Relative severity for tests and accessibility (0 = normal … 2 = high).
    var severity: Int {
        switch self {
        case .normal: return 0
        case .elevated: return 1
        case .high: return 2
        }
    }

    /// Stable name used by UI and tests (not a Color literal in pure logic).
    var styleName: String {
        rawValue
    }

    /// SwiftUI color for menubar / progress tint.
    var color: Color {
        switch self {
        case .normal:
            return .green
        case .elevated:
            return .yellow
        case .high:
            return .red
        }
    }
}

public extension UsageDisplayFormatter {
    /// Band for a snapshot, or `.normal` when no usage data is shown.
    static func usageBand(for snapshot: UsageSnapshot?) -> UsageBand {
        guard let snapshot else { return .normal }
        return usageBand(for: snapshot.usedPercent)
    }
}
