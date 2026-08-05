// MenuBarStatusLabel.swift
// Compact MenuBarExtra label: Grok logo + smaller percent + mini usage bar.
//
// MenuBarExtra status items often clip multi-line VStacks. We reserve space
// with bottom padding and pin the meter with an overlay under the percent,
// using fixed frames only (no GeometryReader — it collapses to zero height).

import SwiftUI

struct MenuBarStatusLabel: View {
    @Bindable var model: AppModel

    private let percentFontSize: CGFloat = 10
    private let logoSide: CGFloat = 14
    private let barWidth: CGFloat = 30
    private let barHeight: CGFloat = 4
    /// Extra room under the percent so the bar is not clipped by the status item.
    private let barClearance: CGFloat = 5

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Image("GrokLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSide, height: logoSide)
                .accessibilityLabel("Grok")

            Text(model.statusItemTitle)
                .font(.system(size: percentFontSize, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.bottom, model.showsStatusUsageBar ? barClearance : 0)
                .overlay(alignment: .bottom) {
                    if model.showsStatusUsageBar {
                        MenuBarUsageBar(
                            fillFraction: model.statusBarFillFraction,
                            width: barWidth,
                            height: barHeight,
                            tint: model.usesBandTint ? model.usageBand.color : Color.primary
                        )
                        // Sit in the reserved clearance under the baseline.
                        .padding(.bottom, 0)
                    }
                }
        }
        .fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(model.usesBandTint ? model.usageBand.color : Color.primary)
        .opacity(model.isStale ? 0.75 : 1.0)
        .help(model.tooltipText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if model.showsStatusUsageBar {
            let pct = Int((model.statusBarFillFraction * 100).rounded())
            return "Grok \(model.statusItemTitle) used, bar \(pct) percent full"
        }
        return "Grok \(model.statusItemTitle)"
    }
}

/// Thin horizontal fill bar for the menu bar.
/// Explicit sizes only — no GeometryReader.
struct MenuBarUsageBar: View {
    /// 0…1 fill fraction (from `UsageDisplayFormatter.barFillFraction`).
    var fillFraction: Double
    var width: CGFloat
    var height: CGFloat
    var tint: Color

    var fillWidth: CGFloat {
        let usedPercent = fillFraction * 100
        return CGFloat(
            UsageDisplayFormatter.barFillWidth(
                usedPercent: usedPercent,
                totalWidth: Double(width)
            )
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.32))
                .frame(width: width, height: height)

            Capsule(style: .continuous)
                .fill(tint.opacity(0.95))
                .frame(width: max(0, fillWidth), height: height)
        }
        .frame(width: width, height: height, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityHidden(true)
    }
}
