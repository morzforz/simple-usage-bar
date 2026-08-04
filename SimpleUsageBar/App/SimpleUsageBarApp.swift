// SimpleUsageBarApp.swift
// Menu-bar accessory: live Grok usage with band tint (P2).

import SwiftUI

@main
struct SimpleUsageBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(model: model)
        } label: {
            Text(model.statusItemTitle)
                .monospacedDigit()
                .foregroundStyle(model.usesBandTint ? model.usageBand.color : Color.primary)
                .opacity(model.isStale ? 0.75 : 1.0)
                .help(model.tooltipText)
        }
        .menuBarExtraStyle(.window)
    }
}
