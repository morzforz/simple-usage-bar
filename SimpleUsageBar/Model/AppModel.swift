// AppModel.swift
// Observable app state. P0 loads a mock snapshot only.

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: UsageSnapshot

    init(snapshot: UsageSnapshot = .mock()) {
        self.snapshot = snapshot
    }

    var statusItemTitle: String {
        UsageDisplayFormatter.statusItemTitle(for: snapshot)
    }

    var usedPercentText: String {
        UsageDisplayFormatter.formatUsedPercent(snapshot.usedPercent)
    }

    var resetAbsoluteText: String {
        UsageDisplayFormatter.formatResetAbsolute(snapshot.resetsAt)
    }

    var resetRelativeText: String {
        UsageDisplayFormatter.formatResetRelative(snapshot.resetsAt)
    }

    var tooltipText: String {
        UsageDisplayFormatter.tooltip(for: snapshot)
    }

    var windowLabelText: String {
        snapshot.windowLabel.displayName
    }

    /// Replace mock data (used by previews/tests). No network in P0.
    func applyMockSnapshot(_ snapshot: UsageSnapshot = .mock()) {
        self.snapshot = snapshot
    }
}
