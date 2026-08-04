// PopoverContentView.swift
// Popover body hosted by MenuBarExtra: mock usage + Quit.

import SwiftUI

struct PopoverContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.snapshot.displayName)
                    .font(.headline)
                Spacer()
                Text(model.windowLabelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.usedPercentText)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(max(model.snapshot.usedPercent, 0), 100), total: 100)
                .progressViewStyle(.linear)

            VStack(alignment: .leading, spacing: 4) {
                Text("Resets \(model.resetRelativeText)")
                    .font(.subheadline)
                Text(model.resetAbsoluteText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("resetAbsoluteLabel")
            }

            if let email = model.snapshot.accountEmail {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Source: \(model.snapshot.source.rawValue) · P0 mock")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()

            Button("Quit Simple Usage Bar") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(16)
        .frame(width: 280)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usagePopover")
    }
}

#Preview {
    PopoverContentView(model: AppModel())
}
