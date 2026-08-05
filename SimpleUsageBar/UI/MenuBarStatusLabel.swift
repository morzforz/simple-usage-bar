// MenuBarStatusLabel.swift
// Compact MenuBarExtra label: Grok logo + smaller percent + mini usage bar.

import SwiftUI

struct MenuBarStatusLabel: View {
    @Bindable var model: AppModel

    /// Slightly smaller than default menubar body (~13pt) for denser chrome.
    private let percentFontSize: CGFloat = 11
    private let logoSide: CGFloat = 13
    private let barWidth: CGFloat = 28
    private let barHeight: CGFloat = 3

    var body: some View {
        HStack(spacing: 4) {
            Image("GrokLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: logoSide, height: logoSide)
                .accessibilityLabel("Grok")

            VStack(alignment: .leading, spacing: 1) {
                Text(model.statusItemTitle)
                    .font(.system(size: percentFontSize, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)

                if model.showsStatusUsageBar {
                    MenuBarUsageBar(
                        fraction: model.statusBarFillFraction,
                        width: barWidth,
                        height: barHeight,
                        tint: model.usesBandTint ? model.usageBand.color : Color.primary
                    )
                }
            }
        }
        .foregroundStyle(model.usesBandTint ? model.usageBand.color : Color.primary)
        .opacity(model.isStale ? 0.75 : 1.0)
        .help(model.tooltipText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if model.showsStatusUsageBar {
            return "Grok \(model.statusItemTitle) used"
        }
        return "Grok \(model.statusItemTitle)"
    }
}

/// Thin horizontal fill bar for the menu bar (0…1 fraction).
struct MenuBarUsageBar: View {
    var fraction: Double
    var width: CGFloat
    var height: CGFloat
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}
