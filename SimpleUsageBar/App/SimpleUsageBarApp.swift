// SimpleUsageBarApp.swift
// Menu-bar accessory: Grok logo + compact percent + mini usage bar.

import SwiftUI

@main
struct SimpleUsageBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(model: model)
        } label: {
            MenuBarStatusLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
