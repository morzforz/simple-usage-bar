// PopoverUsageBarStyle.swift
// Colors and pure presentation tokens for the popover multi-segment usage bar.
// Headroom intermediate uses yellow-orange (not monochrome); used fill keeps band tint.

import Foundation
import SwiftUI

/// Presentation tokens for the popover usage bar (used + optional headroom + track).
public enum PopoverUsageBarStyle {
    /// Stable identifier for tests and accessibility (headroom segment).
    public static let headroomStyleName = "yellowOrange"

    /// Yellow-orange fill for the headroom intermediate segment (popover only).
    public static var headroomColor: Color {
        // Warm yellow-orange, distinct from usage-band yellow and green/red fills.
        Color(red: 1.0, green: 0.55, blue: 0.12)
    }

    /// Unfilled track behind the segments.
    public static var trackColor: Color {
        Color.secondary.opacity(0.22)
    }

    /// sRGB components of `headroomColor` for unit tests (no Color equality reliance).
    public static let headroomColorSRGB: (red: Double, green: Double, blue: Double) = (1.0, 0.55, 0.12)

    /// Whether the popover should draw the yellow-orange intermediate (same rule as menubar).
    public static func showsHeadroomSegment(
        usedPercent: Double,
        headroomPercent: Double?
    ) -> Bool {
        StatusMeterLayout.showsHeadroomIntermediate(
            usedPercent: usedPercent,
            headroomPercent: headroomPercent
        )
    }

    /// Band geometry for a popover track of the given width (reuses menubar pure helpers).
    public static func bands(
        usedPercent: Double,
        headroomPercent: Double?,
        trackWidth: CGFloat
    ) -> StatusMeterBarBands {
        StatusMeterLayout.barBands(
            usedPercent: usedPercent,
            headroomPercent: headroomPercent,
            trackWidth: trackWidth
        )
    }
}
