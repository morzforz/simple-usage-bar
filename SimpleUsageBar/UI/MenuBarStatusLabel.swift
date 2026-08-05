// MenuBarStatusLabel.swift
// MenuBarExtra label: single composited NSImage (logo + percent + bar under percent).
//
// Open-source practice (e.g. CodexBar): draw the status chrome into an 18pt-tall
// NSImage and display that image — multi-line SwiftUI labels are clipped by the
// system menu bar height (~22pt working area).

import AppKit
import SwiftUI

struct MenuBarStatusLabel: View {
    @Bindable var model: AppModel

    var body: some View {
        Image(nsImage: model.statusMeterImage)
            .interpolation(.none)
            .antialiased(false)
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
