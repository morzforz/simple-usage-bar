// MenuBarStatusLabel.swift
// MenuBarExtra label: single composited template NSImage (logo + percent + bar).
//
// Image is monochrome template so the system renders black or white against the
// menu bar. Band colors apply in the popover only, not the status item.

import AppKit
import SwiftUI

struct MenuBarStatusLabel: View {
    @Bindable var model: AppModel

    var body: some View {
        Image(nsImage: model.statusMeterImage)
            .renderingMode(.template)
            .interpolation(.none)
            .antialiased(false)
            .opacity(model.isStale ? 0.75 : 1.0)
            .help(model.tooltipText)
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
