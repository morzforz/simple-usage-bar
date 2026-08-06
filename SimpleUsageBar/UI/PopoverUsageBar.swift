// PopoverUsageBar.swift
// Multi-segment usage bar for the popover: used fill + optional yellow-orange headroom + track.
//
// Hover tip presentation (MenuBarExtra `.window`):
// - SwiftUI `.help` is unreliable here.
// - Nested SwiftUI `.popover` over MenuBarExtra is deferred (focus/dismiss races; see
//   PopoverUsageBarStyle.nestedPopoverDeferralReason).
// - In-window callout: tip is a *child* of the same hover-tracked region as the bar so
//   pointer motion onto the tip does not flip hover off (classic flicker cause).
// - Debounced show/hide without layout animations avoids hang from rapid enter/exit.

import SwiftUI

/// Linear usage bar with optional headroom intermediate (same geometry rules as menubar meter).
struct PopoverUsageBar: View {
    var usedPercent: Double
    var headroomPercent: Double?
    var usedFillColor: Color

    @State private var isHovering = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        // Single contiguous hover region: bar + tip card (when shown).
        VStack(alignment: .leading, spacing: 8) {
            barTrack
                .frame(height: PopoverUsageBarStyle.barVisualHeight)
                .frame(maxWidth: .infinity)

            if isHovering {
                tipCallout
            }
        }
        // Comfortable padding expands the hit target without competing NSView hit-tests.
        .padding(.vertical, PopoverUsageBarStyle.barHoverVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering in
            scheduleHover(hovering)
        }
        .onDisappear {
            hoverTask?.cancel()
            hoverTask = nil
            isHovering = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("usageProgress")
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(tooltipText)
        .accessibilityValue(isHovering ? tooltipText : "")
    }

    /// Debounced hover updates — cancels prior work so rapid enter/exit does not thrash layout.
    private func scheduleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        let delay = hovering
            ? PopoverUsageBarStyle.hoverShowDelayNanoseconds
            : PopoverUsageBarStyle.hoverHideDelayNanoseconds
        hoverTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            // No withAnimation: animated insert/remove of multi-line text caused hangs.
            isHovering = hovering
        }
    }

    private var tipCallout: some View {
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .accessibilityIdentifier(PopoverUsageBarStyle.hoverCalloutAccessibilityID)
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

    /// Shipped pure builder — callout content only (no separate wording path).
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
