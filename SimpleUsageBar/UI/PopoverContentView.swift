// PopoverContentView.swift
// Popover: live/mock usage, status messages, Refresh, Quit.

import SwiftUI

struct PopoverContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.displayName)
                    .font(.headline)
                Spacer()
                Text(model.windowLabelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = model.state.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("statusMessage")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.usedPercentText)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("usedPercentLabel")
                Text("used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: model.progressValue, total: 100)
                .progressViewStyle(.linear)

            VStack(alignment: .leading, spacing: 4) {
                Text("Resets \(model.resetRelativeText)")
                    .font(.subheadline)
                Text(model.resetAbsoluteText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("resetAbsoluteLabel")
            }

            if let email = model.accountEmail {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Source: \(model.sourceLabel)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()

            HStack {
                Button {
                    Task { await model.refresh(force: true) }
                } label: {
                    if model.isRefreshing {
                        Text("Refreshing…")
                    } else {
                        Text("Refresh")
                    }
                }
                .disabled(model.isRefreshing)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityIdentifier("refreshButton")

                Spacer()

                Button("Quit Simple Usage Bar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 300)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usagePopover")
    }
}

#Preview("Ready") {
    PopoverContentView(model: AppModel(provider: PreviewProvider(snapshot: .mock()), autoStart: false))
}

private struct PreviewProvider: UsageProviding {
    let id = "grok"
    let displayName = "Grok"
    let snapshot: UsageSnapshot
    func fetchUsage(now: Date) async throws -> UsageSnapshot { snapshot }
}
