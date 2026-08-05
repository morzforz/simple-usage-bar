// PopoverContentView.swift
// Popover: usage bands, status messages, Launch at Login, Refresh, Quit.

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
                    .foregroundStyle(statusMessageColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("statusMessage")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.usedPercentText)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.usesBandTint ? model.usageBand.color : Color.primary)
                    .accessibilityIdentifier("usedPercentLabel")
                Text("used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: model.progressValue, total: 100)
                .progressViewStyle(.linear)
                .tint(model.usesBandTint ? model.usageBand.color : Color.accentColor)
                .accessibilityIdentifier("usageProgress")

            VStack(alignment: .leading, spacing: 4) {
                Text("Resets \(model.resetRelativeText)")
                    .font(.subheadline)
                Text(model.resetAbsoluteText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("resetAbsoluteLabel")
            }

            Text(model.paceDisplayLine)
                .font(.subheadline)
                .foregroundStyle(paceLineColor)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paceLabel")

            if let headroomLine = model.paceHeadroomDisplayLine {
                Text(headroomLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paceHeadroomLabel")
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

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                )
            )
            .accessibilityIdentifier("launchAtLoginToggle")

            if let loginMessage = model.launchAtLoginMessage {
                Text(loginMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

    private var statusMessageColor: Color {
        switch model.state {
        case .stale:
            return .orange
        case .unauthenticated, .error, .teamUnsupported:
            return .orange
        default:
            return .secondary
        }
    }

    private var paceLineColor: Color {
        switch model.paceOutcome {
        case .insufficientData:
            return .secondary
        case .onPace, .behindPace:
            return .secondary
        case .aheadOfPace:
            return .orange
        }
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
