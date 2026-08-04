// SimpleUsageBarApp.swift
// Menu-bar accessory app entry. P1: live Grok usage via CLI auth.

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
                .help(model.tooltipText)
        }
        .menuBarExtraStyle(.window)
    }
}
