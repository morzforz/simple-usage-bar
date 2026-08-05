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
        // Warm yellow-orange, faintly over the track so used fill stays primary.
        Color(
            red: headroomColorSRGB.red,
            green: headroomColorSRGB.green,
            blue: headroomColorSRGB.blue
        )
        .opacity(headroomOpacity)
    }

    /// Unfilled track behind the segments.
    public static var trackColor: Color {
        Color.secondary.opacity(0.22)
    }

    /// Opacity applied to headroom fill (fainter than solid used segment).
    public static let headroomOpacity: Double = 0.58

    /// sRGB components of `headroomColor` for unit tests (no Color equality reliance).
    /// Dimmer base + opacity so the used fill still reads as primary.
    public static let headroomColorSRGB: (red: Double, green: Double, blue: Double) = (0.82, 0.48, 0.12)

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

    /// Mouseover help for the popover usage bar.
    ///
    /// - When headroom is missing or not strictly greater than used: usage-only copy.
    /// - When headroom segment is shown: explains used fill + yellow-orange headroom with both percents.
    public static func tooltipText(
        usedPercent: Double,
        headroomPercent: Double?
    ) -> String {
        let usedLabel = UsageDisplayFormatter.formatUsedPercent(usedPercent)
        let usedLine = "Used (colored fill): \(usedLabel) of your period pool."

        guard showsHeadroomSegment(usedPercent: usedPercent, headroomPercent: headroomPercent),
              let headroomPercent else {
            return usedLine
        }

        let headroomLabel = UsageDisplayFormatter.formatUsedPercent(headroomPercent)
        let headroomLine =
            "Headroom (yellow-orange): ~\(headroomLabel) projected unused at reset if average burn continues."
        return "\(usedLine)\n\(headroomLine)"
    }
}
