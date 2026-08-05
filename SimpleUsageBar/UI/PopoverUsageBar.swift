// PopoverUsageBar.swift
// Multi-segment usage bar for the popover: used fill + optional yellow-orange headroom + track.
//
// Hover explanation: SwiftUI `.help` does not reliably show inside MenuBarExtra `.window`
// popovers (especially on a thin GeometryReader). We therefore:
// 1) present an in-popover hover callout with the pure tooltip string (primary, visible), and
// 2) bridge AppKit `toolTip` as a secondary channel where the system allows it.

import SwiftUI

/// Linear usage bar with optional headroom intermediate (same geometry rules as menubar meter).
struct PopoverUsageBar: View {
    var usedPercent: Double
    var headroomPercent: Double?
    var usedFillColor: Color

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            barTrack
                // Taller hit target than the 10pt visual so hover is easy to engage.
                .frame(height: 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isHovering = hovering
                    }
                }
                // Secondary: AppKit tooltip when the hosting window supports it.
                .background {
                    AppKitToolTipBridge(text: tooltipText)
                }

            if isHovering {
                Text(tooltipText)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("usageProgressTooltip")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("usageProgress")
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(tooltipText)
        .accessibilityValue(isHovering ? tooltipText : "")
    }

    /// Visual multi-segment track.
    private var barTrack: some View {
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

                if bands.showsIntermediate, bands.intermediateWidth > 0.5 {
                    Capsule()
                        .fill(PopoverUsageBarStyle.headroomColor)
                        .frame(width: min(trackW, bands.fillWidth + bands.intermediateWidth))
                        .accessibilityIdentifier("usageProgressHeadroom")
                }

                if bands.fillWidth > 0.5 {
                    Capsule()
                        .fill(usedFillColor)
                        .frame(width: min(trackW, bands.fillWidth))
                        .accessibilityIdentifier("usageProgressUsed")
                }
            }
            .frame(width: trackW, height: geo.size.height, alignment: .leading)
        }
    }

    /// Shipped pure builder — used by hover callout + AppKit toolTip.
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
