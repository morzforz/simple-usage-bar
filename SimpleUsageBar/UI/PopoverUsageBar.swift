// PopoverUsageBar.swift
// Multi-segment usage bar for the popover: used fill + optional yellow-orange headroom + track.

import SwiftUI

/// Linear usage bar with optional headroom intermediate (same geometry rules as menubar meter).
struct PopoverUsageBar: View {
    var usedPercent: Double
    var headroomPercent: Double?
    var usedFillColor: Color

    var body: some View {
        GeometryReader { geo in
            let trackW = max(geo.size.width, 1)
            let bands = PopoverUsageBarStyle.bands(
                usedPercent: usedPercent,
                headroomPercent: headroomPercent,
                trackWidth: trackW
            )
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PopoverUsageBarStyle.trackColor)

                // Headroom intermediate (yellow-orange), drawn under used so used stays on top at the seam.
                if bands.showsIntermediate, bands.intermediateWidth > 0.5 {
                    Capsule()
                        .fill(PopoverUsageBarStyle.headroomColor)
                        .frame(width: min(trackW, bands.fillWidth + bands.intermediateWidth))
                        .accessibilityIdentifier("usageProgressHeadroom")
                }

                // Used fill (band tint / accent).
                if bands.fillWidth > 0.5 {
                    Capsule()
                        .fill(usedFillColor)
                        .frame(width: min(trackW, bands.fillWidth))
                        .accessibilityIdentifier("usageProgressUsed")
                }
            }
            .frame(width: trackW, height: geo.size.height, alignment: .leading)
        }
        .frame(height: 8)
        .contentShape(Capsule())
        .help(tooltipText)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("usageProgress")
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(tooltipText)
    }

    /// Shipped pure builder — same string as mouseover `.help`.
    private var tooltipText: String {
        PopoverUsageBarStyle.tooltipText(
            usedPercent: usedPercent,
            headroomPercent: headroomPercent
        )
    }

    private var accessibilitySummary: String {
        var parts = ["Usage \(Int(usedPercent.rounded())) percent"]
        if PopoverUsageBarStyle.showsHeadroomSegment(
            usedPercent: usedPercent,
            headroomPercent: headroomPercent
        ), let headroomPercent {
            parts.append("headroom \(Int(headroomPercent.rounded())) percent")
        }
        return parts.joined(separator: ", ")
    }
}
