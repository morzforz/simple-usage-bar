// SimpleUsageBarApp.swift
// Menu-bar accessory app entry. P0 shows mock usage only.

import SwiftUI

@main
struct SimpleUsageBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(model: model)
        } label: {
            // Visible menubar label is derived from the mock snapshot.
            Text(model.statusItemTitle)
                .monospacedDigit()
                .help(model.tooltipText)
        }
        .menuBarExtraStyle(.window)
    }
}
